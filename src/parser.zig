const std = @import("std");
const Record = @import("record.zig").Record;
const Dialect = @import("dialect.zig").Dialect;

pub const Error = error{
    InvalidCsv,
    UnterminatedQuote,
};

pub const Parser = struct {
    input: []const u8,
    pos: usize,
    dialect: Dialect,

    allocator: std.mem.Allocator,

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
