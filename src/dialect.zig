const LineEnding = @import("line_ending.zig").LineEnding;

pub const Dialect = struct {
    separator: u8 = ',',
    quote: u8 = '"',
    line_ending: LineEnding = .lf,

    pub fn isSeparator(self: *Dialect, c: u8) bool {
        return c == self.separator;
    }

    pub fn isQuote(self: *Dialect, c: u8) bool {
        return c == self.quote;
    }

    pub fn isLineEnding(self: *Dialect, input: []const u8, pos: usize) bool {
        return switch (self.line_ending) {
            .lf => input[pos] == '\n',
            .cr => input[pos] == '\r',
            .crlf => pos + 1 < input.len and
                input[pos] == '\r' and input[pos + 1] == '\n',
        };
    }
};
