const std = @import("std");
const Record = @import("record.zig").Record;

pub const Error = error{
    InvalidCsv,
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

    pub fn next(self: *Parser) !? Record {
        if (self.pos >= self.input.len) return null;

        var fields: std.ArrayList([]const u8) = .empty;
        errdefer fields.deinit(self.allocator);

        while(true) {
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

                    if (self.pos < self.input.len 
                        and self.input[self.pos] == '\n') {
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
            // TODO: implement quote parsing
            return "";
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
};
