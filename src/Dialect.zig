//! Defines CSV dialect configuration options.

const LineEnding = @import("LineEnding.zig").LineEnding;

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

    /// Returns whether `c: chararacter` is the configured field separator.
    pub fn isSeparator(self: Dialect, c: u8) bool {
        return c == self.separator;
    }

    /// Returns wheter `c: character` is the configured quote character.
    pub fn isQuote(self: Dialect, c: u8) bool {
        return c == self.quote;
    }

    /// Returns whether a line ending starts at `pos` in `input`.
    ///
    /// The check depends on the configured `line_ending` convention.
    /// For multi-character line endings (e.g. `.crlf`) all their bytes
    /// must be present.
    pub fn isLineEnding(self: Dialect, input: []const u8, pos: usize) bool {
        return switch (self.line_ending) {
            .lf => input[pos] == '\n',
            .cr => input[pos] == '\r',
            .crlf => pos + 1 < input.len and
                input[pos] == '\r' and input[pos + 1] == '\n',
        };
    }

    /// Returns whether `c` is part of the configured line ending.
    ///
    /// For `.crlf`, `\r` is considered the line-ending byte because it
    /// starts the configured `\r\n` sequence.
    pub fn isLineEndingByte(self: Dialect, c: u8) bool {
        return switch (self.line_ending) {
            .lf => c == '\n',
            .cr => c == '\r',
            .crlf => c == '\r',
        };
    }
};

const std = @import("std");
const testing = std.testing;

test "default dialect values" {
    const dialect = Dialect{};

    try testing.expectEqual(@as(u8, ','), dialect.separator);
    try testing.expectEqual(@as(u8, '"'), dialect.quote);
    try testing.expectEqual(LineEnding.lf, dialect.line_ending);
}

test "isLineEnding with lf" {
    const dialect = Dialect{ .line_ending = .lf };

    try testing.expect(dialect.isLineEnding("a\n", 1));
    try testing.expect(!dialect.isLineEnding("a\r", 1));
    try testing.expect(!dialect.isLineEnding("ab", 1));
}

test "isLineEnding with cr" {
    const dialect = Dialect{ .line_ending = .cr };

    try testing.expect(dialect.isLineEnding("a\r", 1));
    try testing.expect(!dialect.isLineEnding("a\n", 1));
    try testing.expect(!dialect.isLineEnding("ab", 1));
}

test "isLineEnding with crlf requires both bytes" {
    const dialect = Dialect{ .line_ending = .crlf };

    try testing.expect(dialect.isLineEnding("a\r\n", 1));
    try testing.expect(!dialect.isLineEnding("a\rb", 1));
    try testing.expect(!dialect.isLineEnding("a\n", 1));
}
