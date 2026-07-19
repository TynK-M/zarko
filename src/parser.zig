const std = @import("std");
const Record = @import("record.zig").Record;

pub const Error = error{
    InvalidCsv,
    UnterminatedQuote,
};

pub const Parser = struct {
    input: []const u8,
    pos: usize,

    allocator: std.mem.Allocator,

    pub fn init(
        input: []const u8,
        allocator: std.mem.Allocator,
    ) Parser {
        return .{
            .input = input,
            .pos = 0,
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

            switch (self.input[self.pos]) {
                ',' => {
                    self.pos += 1;
                },

                '\n' => {
                    self.pos += 1;
                    break;
                },

                '\r' => {
                    self.pos += 1;

                    if (self.pos < self.input.len and self.input[self.pos] == '\n') {
                        self.pos += 1;
                    }

                    break;
                },

                else => return Error.InvalidCsv,
            }
        }

        return .{
            .fields = try fields.toOwnedSlice(self.allocator),
        };
    }

    fn parseField(self: *Parser) ![]const u8 {
        if (self.pos >= self.input.len) return "";

        if (self.input[self.pos] == '"') {
            return self.parseQuotedField();
        }

        const start = self.pos;

        while (self.pos < self.input.len) {
            switch (self.input[self.pos]) {
                ',', '\n', '\r' => break,
                else => self.pos += 1,
            }
        }

        return self.input[start..self.pos];
    }

    fn parseQuotedField(self: *Parser) ![]const u8 {
        self.pos += 1;
        const start = self.pos;
        var escaped = false;

        while (self.pos < self.input.len) {
            switch (self.input[self.pos]) {
                '"' => {
                    if (self.pos + 1 < self.input.len and
                        self.input[self.pos + 1] == '"')
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
                },

                else => {
                    self.pos += 1;
                },
            }
        }

        return Error.UnterminatedQuote;
    }

    fn unescape(self: *Parser, input: []const u8) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        var i: usize = 0;

        while (i < input.len) {
            if (input[i] == '"' and
                i + 1 < input.len and
                input[i + 1] == '"')
            {
                try out.append(self.allocator, '"');
                i += 2;
            } else {
                try out.append(self.allocator, input[i]);
                i += 1;
            }
        }

        return try out.toOwnedSlice(self.allocator);
    }
};
