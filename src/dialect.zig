//! Defines CSV dialect configuration options.

const LineEnding = @import("line_ending.zig").LineEnding;

/// Configuration options that define how CSV data is formatted.
///
/// A dialect controls the characters and conventions used when parsing
/// or writing CSV data, including fields separators, quoting, and line
/// endings.
pub const Dialect = struct {
    /// Field separator character.
    ///
    /// Defaults to a comma (`,`).
    separator: u8 = ',',

    /// Quote character used to delimit fields containing special characters.
    ///
    /// Defaults to a double quote (`"`).
    quote: u8 = '"',

    /// Line ending convention used by the CSV data.
    ///
    /// Defaults to line feed (`.lf`).
    line_ending: LineEnding = .lf,

    /// Returns wheter `c` is the configured field separator.
    pub fn isSeparator(self: *Dialect, c: u8) bool {
        return c == self.separator;
    }

    /// Returns wheter `c` is the configured quote character.
    pub fn isQuote(self: *Dialect, c: u8) bool {
        return c == self.quote;
    }

    /// Returns wheter a line ending starts at `pos` in `input`.
    ///
    /// The check depends on the configured `line_ending` convention.
    /// For multi-character line endings (e.g. `.crlf`) all their bytes
    /// must be present.
    pub fn isLineEnding(self: *Dialect, input: []const u8, pos: usize) bool {
        return switch (self.line_ending) {
            .lf => input[pos] == '\n',
            .cr => input[pos] == '\r',
            .crlf => pos + 1 < input.len and
                input[pos] == '\r' and input[pos + 1] == '\n',
        };
    }
};
