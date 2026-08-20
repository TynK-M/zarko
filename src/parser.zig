//! Provides a streaming CSV parser.

const std = @import("std");
const Record = @import("record.zig").Record;
const Dialect = @import("dialect.zig").Dialect;

/// Errors that can occur while parsing CSV input.
pub const Error = error{
    /// The input does not conform to the configured CSV dialect.
    InvalidCsv,

    /// A quoted field was not terminated before the end of the input.
    UnterminatedQuote,
};

/// Parses CSV data into records.
///
/// A `Parser` reads from an input buffer and produces one `Record` at a
/// time.
/// Parsed records borrow fields slices from the input whenever possible.
/// Fields requiring quote unescaping are newly allocated.
pub const Parser = struct {
    /// The CSV input being parsed.
    input: []const u8,

    /// Current position within the input.
    pos: usize,

    /// The CSV dialect used while parsing.
    dialect: Dialect,

    /// Allocator used for record storage and unescaped fields.
    allocator: std.mem.Allocator,

    /// Creates a parser for the given CSV input.
    pub fn init(
        allocator: std.mem.Allocator,
        input: []const u8,
        dialect: Dialect,
    ) Parser {
        return .{
            .input = input,
            .pos = 0,
            .dialect = dialect,
            .allocator = allocator,
        };
    }

    // Wrappers for Dialect functions for the Parser
    // This helps us avoid passing around state everywhere
    pub fn atLineEnding(self: *const Parser) bool {
        if (self.pos >= self.input.len) return false;
        return self.dialect.isLineEnding(self.input, self.pos);
    }

    pub fn atSeparator(self: *const Parser) bool {
        if (self.pos >= self.input.len) return false;
        return self.dialect.isSeparator(self.input[self.pos]);
    }

    pub fn atQuote(self: *const Parser) bool {
        if (self.pos >= self.input.len) return false;
        return self.dialect.isQuote(self.input[self.pos]);
    }
    pub fn atQuoteOffset(self: *const Parser, offset: usize) bool {
        if ((self.pos + offset >= self.input.len)) {
            return false;
        }

        return self.dialect.isQuote(self.input[self.pos + offset]);
    }

    pub fn inBounds(self: *const Parser, offset: usize) bool {
        return self.pos + offset < self.input.len;
    }

    /// Parses and returns the next record.
    ///
    /// Returns `null` once the end of the input has been reached.
    ///
    /// The returned record owns its field slice. Individual field values
    /// borrow from the input unless they contained escaped quotes, in which
    /// case they are newly allocated.
    pub fn next(self: *Parser) !?Record {
        if (self.pos >= self.input.len) return null;

        var fields: std.ArrayList([]const u8) = .empty;
        errdefer fields.deinit(self.allocator);

        while (true) {
            const field = try self.parseField();
            try fields.append(self.allocator, field);

            if (!self.inBounds(0)) break;

            if (self.atSeparator()) {
                // skip over the sep
                self.pos += 1;
                continue;
            }

            if (self.atLineEnding()) {
                // skip over the lineending (adjust for 1 or 2 byte ones)
                const advance: usize = if (self.dialect.line_ending == .crlf) 2 else 1;
                self.pos += advance;

                // End row at line break
                break;
            }

            return Error.InvalidCsv;
        }

        return .{
            .fields = try fields.toOwnedSlice(self.allocator),
        };
    }

    /// Parses a single field from the current input position.
    ///
    /// Handles both quoted and unquoted fields.
    fn parseField(self: *Parser) ![]const u8 {
        if (!self.inBounds(0)) return "";

        if (self.atQuote()) {
            return self.parseQuotedField();
        }

        const start = self.pos;

        while (self.inBounds(0)) {
            if (self.atSeparator() or self.atLineEnding()) {
                break;
            } else {
                self.pos += 1;
            }
        }

        return self.input[start..self.pos];
    }

    /// Parses a quoted field.
    ///
    /// Escaped quote sequences are unescaped automatically. If no escaped
    /// quotes are present, the returned slice borrows directly from the
    /// input.
    ///
    /// Returns `Error.UnterminatedQuote` if the closing quote is missing.
    fn parseQuotedField(self: *Parser) ![]const u8 {
        // skip over the leading quote (because [a..d] = [a, b, c])
        self.pos += 1;
        const start = self.pos;

        var escaped = false;

        while (self.pos < self.input.len) {
            if (self.atQuote()) {

                // at double quote
                if (self.atQuoteOffset(1)) {
                    escaped = true;
                    self.pos += 2;
                    continue;
                }

                // if not at double quote, you've hit end
                const end = self.pos;
                self.pos += 1;

                const raw = self.input[start..end];
                if (!escaped) return raw;

                return try unescape(self, raw);
            } else {
                self.pos += 1;
            }
        }

        // function begins with skipping quote, so must find second
        return Error.UnterminatedQuote;
    }

    /// Replaces escaped quote sequences with a single quote character.
    ///
    /// Returns a newly allocated slice containing the unescaped field.
    fn unescape(self: *Parser, input: []const u8) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(self.allocator);

        var i: usize = 0;
        while (i < input.len) {
            const isDoubleQuote = self.dialect.isQuote(input[i]) and
                i + 1 < input.len and
                self.dialect.isQuote(input[i + 1]);

            if (isDoubleQuote) {
                try out.append(self.allocator, self.dialect.quote);
                i += 2;
            } else {
                try out.append(self.allocator, input[i]);
                i += 1;
            }
        }

        return try out.toOwnedSlice(self.allocator);
    }
};

// ------------- //
// TESTING BLOCK //
// ------------- //

const dialects = @import("dialects.zig");
const testing = std.testing;

// Asserts that the next record has exactly the `expected` field values.
fn expectRecord(parser: *Parser, expected: []const []const u8) !void {
    const record = (try parser.next()) orelse return error.UnexpectedEndOfInput;

    try testing.expectEqual(expected.len, record.len());

    for (expected, 0..) |want, i| {
        try testing.expectEqualStrings(want, record.at(i));
    }
}

// Asserts that the parser has consumed all of its input.
fn expectDone(parser: *Parser) !void {
    try testing.expect(try parser.next() == null);
}

// Returns whether `field` points into `input` rather than into memory the
// parser allocated. Only meaningful for non-empty fields, since an empty
// field may be a static empty string with no relation to the input.
fn borrowsFromInput(input: []const u8, field: []const u8) bool {
    const start = @intFromPtr(input.ptr);
    const ptr = @intFromPtr(field.ptr);

    return ptr >= start and ptr < start + input.len;
}

test "empty input yields no records" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "", .{});

    try expectDone(&parser);
}

test "single row without a trailing line ending" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a,b,c", .{});

    try expectRecord(&parser, &.{ "a", "b", "c" });
    try expectDone(&parser);
}

test "trailing line ending does not produce an extra record" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a,b\n", .{});

    try expectRecord(&parser, &.{ "a", "b" });
    try expectDone(&parser);
}

test "multiple rows" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a,b\nc,d\ne,f", .{});

    try expectRecord(&parser, &.{ "a", "b" });
    try expectRecord(&parser, &.{ "c", "d" });
    try expectRecord(&parser, &.{ "e", "f" });
    try expectDone(&parser);
}

test "single field row" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "only", .{});

    try expectRecord(&parser, &.{"only"});
    try expectDone(&parser);
}

test "interior empty field" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a,,b", .{});

    try expectRecord(&parser, &.{ "a", "", "b" });
    try expectDone(&parser);
}

test "trailing separator produces a trailing empty field" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a,", .{});

    try expectRecord(&parser, &.{ "a", "" });
    try expectDone(&parser);
}

test "quoted field containing the separator" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a,\"b,c\",d", .{});

    try expectRecord(&parser, &.{ "a", "b,c", "d" });
    try expectDone(&parser);
}

test "quoted field containing a line ending" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "\"one\ntwo\",x", .{});

    try expectRecord(&parser, &.{ "one\ntwo", "x" });
    try expectDone(&parser);
}

test "empty quoted field" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a,\"\",b", .{});

    try expectRecord(&parser, &.{ "a", "", "b" });
    try expectDone(&parser);
}

test "escaped quote inside a quoted field" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "\"say \"\"hi\"\"\"", .{});

    try expectRecord(&parser, &.{"say \"hi\""});
    try expectDone(&parser);
}

test "field that is only an escaped quote" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "\"\"\"\"", .{});

    try expectRecord(&parser, &.{"\""});
    try expectDone(&parser);
}

test "escaped quote at the end of a quoted field" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "\"a\"\"\"", .{});

    try expectRecord(&parser, &.{"a\""});
    try expectDone(&parser);
}

test "quote is literal data in an unquoted field" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a\"b,c", .{});

    try expectRecord(&parser, &.{ "a\"b", "c" });
    try expectDone(&parser);
}

test "a quote only opens a field when it is the first byte" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a, \"b,c\"", .{});

    try expectRecord(&parser, &.{ "a", " \"b", "c\"" });
    try expectDone(&parser);
}

test "unquoted fields borrow from the input" {
    const input = "abc,def";

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), input, .{});
    const record = (try parser.next()).?;

    try testing.expect(borrowsFromInput(input, record.at(0)));
    try testing.expect(borrowsFromInput(input, record.at(1)));
}

test "quoted fields without escapes borrow from the input" {
    const input = "\"b,c\"";

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), input, .{});
    const record = (try parser.next()).?;

    try testing.expect(borrowsFromInput(input, record.at(0)));
}

test "a row can mix allocated and borrowed fields" {
    const input = "\"x\"\"y\",plain";

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), input, .{});
    const record = (try parser.next()).?;

    try testing.expectEqualStrings("x\"y", record.at(0));
    try testing.expectEqualStrings("plain", record.at(1));

    try testing.expect(!borrowsFromInput(input, record.at(0)));
    try testing.expect(borrowsFromInput(input, record.at(1)));
}

test "unterminated quoted field" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "\"abc", .{});

    try testing.expectError(Error.UnterminatedQuote, parser.next());
}

test "trailing escaped quote leaves the field unterminated" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "\"a\"\"", .{});

    try testing.expectError(Error.UnterminatedQuote, parser.next());
}

test "stray byte after a closing quote is rejected" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "\"ab\"x,c", .{});

    try testing.expectError(Error.InvalidCsv, parser.next());
}

test "blank line yields a record with one empty field" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a\n\nb", .{});

    try expectRecord(&parser, &.{"a"});
    try expectRecord(&parser, &.{""});
    try expectRecord(&parser, &.{"b"});
    try expectDone(&parser);
}

test "tsv dialect" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a\tb\nc\td", dialects.tsv);

    try expectRecord(&parser, &.{ "a", "b" });
    try expectRecord(&parser, &.{ "c", "d" });
    try expectDone(&parser);
}

test "semicolon dialect" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a;b\nc;d", dialects.semicolon);

    try expectRecord(&parser, &.{ "a", "b" });
    try expectRecord(&parser, &.{ "c", "d" });
    try expectDone(&parser);
}

test "excel dialect uses crlf line endings" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = Parser.init(arena.allocator(), "a,b\r\nc,d", dialects.excel);

    try expectRecord(&parser, &.{ "a", "b" });
    try expectRecord(&parser, &.{ "c", "d" });
    try expectDone(&parser);
}

test "custom quote character" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const dialect = Dialect{ .quote = '\'' };
    var parser = Parser.init(arena.allocator(), "a,'b,c'", dialect);

    try expectRecord(&parser, &.{ "a", "b,c" });
    try expectDone(&parser);
}

test "readme example" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const csv =
        \\name,age,city
        \\Matteo,22,Rome
        \\QuoteTest,"312","Hello, ""World!"""
    ;

    var parser = Parser.init(arena.allocator(), csv, .{});

    try expectRecord(&parser, &.{ "name", "age", "city" });
    try expectRecord(&parser, &.{ "Matteo", "22", "Rome" });
    try expectRecord(&parser, &.{ "QuoteTest", "312", "Hello, \"World!\"" });
    try expectDone(&parser);
}
