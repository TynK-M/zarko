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
        input: []const u8,
        allocator: std.mem.Allocator,
        dialect: Dialect,
    ) Parser {
        return .{
            .input = input,
            .pos = 0,
            .dialect = dialect,
            .allocator = allocator,
        };
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

            if (self.pos >= self.input.len) break;

            const c = self.input[self.pos];

            if (self.dialect.isSeparator(c)) {
                self.pos += 1;
                continue;
            }

            switch (self.dialect.line_ending) {
                .lf => {
                    if (c == '\n') {
                        self.pos += 1;
                        break;
                    }
                },
                .crlf => {
                    if (c == '\r') {
                        self.pos += 1;

                        if (self.pos < self.input.len and self.input[self.pos] == '\n') {
                            self.pos += 1;
                        }

                        break;
                    }
                },
                .cr => {
                    if (c == '\r') {
                        self.pos += 1;
                        break;
                    }
                },
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
        if (self.pos >= self.input.len) return "";

        if (self.dialect.isQuote(self.input[self.pos])) {
            return self.parseQuotedField();
        }

        const start = self.pos;

        while (self.pos < self.input.len) {
            if (self.dialect.isSeparator(self.input[self.pos]) or
                self.dialect.isLineEnding(self.input, self.pos))
            {
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
        self.pos += 1;
        const start = self.pos;
        var escaped = false;

        while (self.pos < self.input.len) {
            if (self.dialect.isQuote(self.input[self.pos])) {
                if (self.pos + 1 < self.input.len and
                    self.dialect.isQuote(self.input[self.pos + 1]))
                {
                    escaped = true;
                    self.pos += 2;
                    continue;
                }

                const end = self.pos;
                self.pos += 1;

                const raw = self.input[start..end];
                if (!escaped) return raw;

                return try self.unescape(raw);
            } else {
                self.pos += 1;
            }
        }

        return Error.UnterminatedQuote;
    }

    /// Replaces escaped quote sequences with a single quote character.
    ///
    /// Returns a newly allocated slice containing the unescaped field.
    fn unescape(self: *Parser, input: []const u8) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        var i: usize = 0;

        while (i < input.len) {
            if (self.dialect.isQuote(input[i]) and
                i + 1 < input.len and
                input[i + 1] == self.dialect.quote)
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
