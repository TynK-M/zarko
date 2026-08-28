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

    /// Checks if the current position in the buffer is a line ending.
    pub fn atLineEnding(self: *const Parser) bool {
        if (self.pos >= self.input.len) return false;
        return self.dialect.isLineEnding(self.input, self.pos);
    }

    /// Checks if the current position in the buffer is a line ending.
    pub fn atSeparator(self: *const Parser) bool {
        if (self.pos >= self.input.len) return false;
        return self.dialect.isSeparator(self.input[self.pos]);
    }

    /// Checks if the current position in the buffer is a quote.
    pub fn atQuote(self: *const Parser) bool {
        if (self.pos >= self.input.len) return false;
        return self.dialect.isQuote(self.input[self.pos]);
    }

    /// Checks if the current position plus a given offset is a quote.
    pub fn atQuoteOffset(self: *const Parser, offset: usize) bool {
        if ((self.pos + offset >= self.input.len)) {
            return false;
        }

        return self.dialect.isQuote(self.input[self.pos + offset]);
    }

    /// Checks if the current position plus a offset is in the bounds of the
    /// buffer.
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

        var owned: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (owned.items) |field| {
                self.allocator.free(field);
            }
            owned.deinit(self.allocator);
        }

        while (true) {
            const field = try self.parseField(&owned);
            try fields.append(self.allocator, field);

            if (!self.inBounds(0)) break;

            if (self.atSeparator()) {
                // Skip over the separator.
                self.pos += 1;
                continue;
            }

            if (self.atLineEnding()) {
                // Skip over the `LineEnding`, adjusting in base of the number
                // of characters.
                var advance: usize = 1;
                switch (self.dialect.line_ending) {
                    .lf, .cr => {
                        advance = 1;
                    },
                    .crlf => {
                        advance = 2;
                    },
                }
                self.pos += advance;

                // End row at `LineEnding`.
                break;
            }

            return Error.InvalidCsv;
        }

        return .{
            .fields = try fields.toOwnedSlice(self.allocator),
            .owned = try owned.toOwnedSlice(self.allocator),
        };
    }

    /// Parses a single field from the current input position.
    ///
    /// Handles both quoted and unquoted fields.
    fn parseField(self: *Parser, owned: *std.ArrayList([]const u8)) ![]const u8 {
        if (!self.inBounds(0)) return "";

        if (self.atQuote()) {
            return self.parseQuotedField(owned);
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
    fn parseQuotedField(self: *Parser, owned: *std.ArrayList([]const u8)) ![]const u8 {
        // Skip over the leading quote.
        self.pos += 1;
        const start = self.pos;

        var escaped = false;

        while (self.pos < self.input.len) {
            if (self.atQuote()) {

                // Check if at a double quote.
                if (self.atQuoteOffset(1)) {
                    escaped = true;
                    self.pos += 2;
                    continue;
                }

                // If it is not at a double quote, reached end.
                const end = self.pos;
                self.pos += 1;

                const raw = self.input[start..end];
                if (!escaped) return raw;

                const result = try unescape(self, raw);
                errdefer self.allocator.free(result);

                try owned.append(self.allocator, result);
                return result;
            } else {
                self.pos += 1;
            }
        }

        // Function begins with a quote, so an ending one must be
        // found, otherwise a `UnterminatedQuote` error is returned.
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
            if (self.dialect.isQuote(input[i]) and
                i + 1 < input.len and
                self.dialect.isQuote(input[i + 1]))
            {
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

const dialects = @import("dialects.zig");
const testing = std.testing;

/// Asserts that the next record has exactly the `expected` field values.
fn expectRecord(parser: *Parser, expected: []const []const u8) !void {
    var record = (try parser.next()) orelse return error.UnexpectedEndOfInput;
    defer record.deinit(parser.allocator);

    try testing.expectEqual(expected.len, record.len());

    for (expected, 0..) |want, i| {
        try testing.expectEqualStrings(want, record.at(i));
    }
}

/// Asserts that the parser has consumed all of its input.
fn expectDone(parser: *Parser) !void {
    try testing.expect(try parser.next() == null);
}

/// Returns whether `field` points into `input` rather than into memory the
/// parser allocated. Only meaningful for non-empty fields, since an empty
/// field may be a static empty string with no relation to the input.
fn borrowsFromInput(input: []const u8, field: []const u8) bool {
    const start = @intFromPtr(input.ptr);
    const ptr = @intFromPtr(field.ptr);

    return ptr >= start and ptr < start + input.len;
}

test "empty input yields no records" {
    var parser = Parser.init(std.testing.allocator, "", .{});

    try expectDone(&parser);
}

test "single row without a trailing line ending" {
    var parser = Parser.init(std.testing.allocator, "a,b,c", .{});

    try expectRecord(&parser, &.{ "a", "b", "c" });
    try expectDone(&parser);
}

test "trailing line ending does not produce an extra record" {
    var parser = Parser.init(std.testing.allocator, "a,b\n", .{});

    try expectRecord(&parser, &.{ "a", "b" });
    try expectDone(&parser);
}

test "multiple rows" {
    var parser = Parser.init(std.testing.allocator, "a,b\nc,d\ne,f", .{});

    try expectRecord(&parser, &.{ "a", "b" });
    try expectRecord(&parser, &.{ "c", "d" });
    try expectRecord(&parser, &.{ "e", "f" });
    try expectDone(&parser);
}

test "single field row" {
    var parser = Parser.init(std.testing.allocator, "only", .{});

    try expectRecord(&parser, &.{"only"});
    try expectDone(&parser);
}

test "interior empty field" {
    var parser = Parser.init(std.testing.allocator, "a,,b", .{});

    try expectRecord(&parser, &.{ "a", "", "b" });
    try expectDone(&parser);
}

test "trailing separator produces a trailing empty field" {
    var parser = Parser.init(std.testing.allocator, "a,", .{});

    try expectRecord(&parser, &.{ "a", "" });
    try expectDone(&parser);
}

test "quoted field containing the separator" {
    var parser = Parser.init(std.testing.allocator, "a,\"b,c\",d", .{});

    try expectRecord(&parser, &.{ "a", "b,c", "d" });
    try expectDone(&parser);
}

test "quoted field containing a line ending" {
    var parser = Parser.init(std.testing.allocator, "\"one\ntwo\",x", .{});

    try expectRecord(&parser, &.{ "one\ntwo", "x" });
    try expectDone(&parser);
}

test "empty quoted field" {
    var parser = Parser.init(std.testing.allocator, "a,\"\",b", .{});

    try expectRecord(&parser, &.{ "a", "", "b" });
    try expectDone(&parser);
}

test "escaped quote inside a quoted field" {
    var parser = Parser.init(std.testing.allocator, "\"say \"\"hi\"\"\"", .{});

    try expectRecord(&parser, &.{"say \"hi\""});
    try expectDone(&parser);
}

test "field that is only an escaped quote" {
    var parser = Parser.init(std.testing.allocator, "\"\"\"\"", .{});

    try expectRecord(&parser, &.{"\""});
    try expectDone(&parser);
}

test "escaped quote at the end of a quoted field" {
    var parser = Parser.init(std.testing.allocator, "\"a\"\"\"", .{});

    try expectRecord(&parser, &.{"a\""});
    try expectDone(&parser);
}

test "quote is literal data in an unquoted field" {
    var parser = Parser.init(std.testing.allocator, "a\"b,c", .{});

    try expectRecord(&parser, &.{ "a\"b", "c" });
    try expectDone(&parser);
}

test "a quote only opens a field when it is the first byte" {
    var parser = Parser.init(std.testing.allocator, "a, \"b,c\"", .{});

    try expectRecord(&parser, &.{ "a", " \"b", "c\"" });
    try expectDone(&parser);
}

test "unquoted fields borrow from the input" {
    const input = "abc,def";

    var parser = Parser.init(std.testing.allocator, input, .{});
    var record = (try parser.next()).?;
    defer record.deinit(parser.allocator);

    try testing.expect(borrowsFromInput(input, record.at(0)));
    try testing.expect(borrowsFromInput(input, record.at(1)));
}

test "quoted fields without escapes borrow from the input" {
    const input = "\"b,c\"";

    var parser = Parser.init(std.testing.allocator, input, .{});
    var record = (try parser.next()).?;
    defer record.deinit(parser.allocator);

    try testing.expect(borrowsFromInput(input, record.at(0)));
}

test "a row can mix allocated and borrowed fields" {
    const input = "\"x\"\"y\",plain";

    var parser = Parser.init(std.testing.allocator, input, .{});
    var record = (try parser.next()).?;
    defer record.deinit(parser.allocator);

    try testing.expectEqualStrings("x\"y", record.at(0));
    try testing.expectEqualStrings("plain", record.at(1));

    try testing.expect(!borrowsFromInput(input, record.at(0)));
    try testing.expect(borrowsFromInput(input, record.at(1)));
}

test "unterminated quoted field" {
    var parser = Parser.init(std.testing.allocator, "\"abc", .{});

    try testing.expectError(Error.UnterminatedQuote, parser.next());
}

test "trailing escaped quote leaves the field unterminated" {
    var parser = Parser.init(std.testing.allocator, "\"a\"\"", .{});

    try testing.expectError(Error.UnterminatedQuote, parser.next());
}

test "stray byte after a closing quote is rejected" {
    var parser = Parser.init(std.testing.allocator, "\"ab\"x,c", .{});

    try testing.expectError(Error.InvalidCsv, parser.next());
}

test "blank line yields a record with one empty field" {
    var parser = Parser.init(std.testing.allocator, "a\n\nb", .{});

    try expectRecord(&parser, &.{"a"});
    try expectRecord(&parser, &.{""});
    try expectRecord(&parser, &.{"b"});
    try expectDone(&parser);
}

test "tsv dialect" {
    var parser = Parser.init(std.testing.allocator, "a\tb\nc\td", dialects.tsv);

    try expectRecord(&parser, &.{ "a", "b" });
    try expectRecord(&parser, &.{ "c", "d" });
    try expectDone(&parser);
}

test "semicolon dialect" {
    var parser = Parser.init(std.testing.allocator, "a;b\nc;d", dialects.semicolon);

    try expectRecord(&parser, &.{ "a", "b" });
    try expectRecord(&parser, &.{ "c", "d" });
    try expectDone(&parser);
}

test "excel dialect uses crlf line endings" {
    var parser = Parser.init(std.testing.allocator, "a,b\r\nc,d", dialects.excel);

    try expectRecord(&parser, &.{ "a", "b" });
    try expectRecord(&parser, &.{ "c", "d" });
    try expectDone(&parser);
}

test "custom quote character" {
    const dialect = Dialect{ .quote = '\'' };
    var parser = Parser.init(std.testing.allocator, "a,'b,c'", dialect);

    try expectRecord(&parser, &.{ "a", "b,c" });
    try expectDone(&parser);
}

test "readme example" {
    const csv =
        \\name,age,city
        \\Matteo,22,Rome
        \\QuoteTest,"312","Hello, ""World!"""
    ;

    var parser = Parser.init(std.testing.allocator, csv, .{});

    try expectRecord(&parser, &.{ "name", "age", "city" });
    try expectRecord(&parser, &.{ "Matteo", "22", "Rome" });
    try expectRecord(&parser, &.{ "QuoteTest", "312", "Hello, \"World!\"" });
    try expectDone(&parser);
}
