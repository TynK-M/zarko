//! Defines line ending types used by Zarko.

/// Represents the line ending used by a CSV.
pub const LineEnding = enum {
    /// Line Feed (`\n`).
    lf,

    /// Carriage Return + Line Feed (`\r\n`).
    crlf,

    /// Carriage Return (`\r`)
    cr,

    /// Returns the byte sequence used by this line ending.
    pub fn bytes(self: LineEnding) []const u8 {
        return switch (self) {
            .lf => "\n",
            .cr => "\r",
            .crlf => "\r\n",
        };
    }
};
