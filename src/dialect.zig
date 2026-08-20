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

    // ------------------------------------ //
    // INFO:                                //
    // These functions take `Dialect` in    //
    // place of `*Dialect` because we want  //
    // to be able to use these functions on //
    // immutable values, which we cannot do //
    // when passing references. We could    //
    // use `*const Dialect`, but the struct //
    // is small (3bytes?) and the functions //
    // are not mutating the struct.         //
    // ------------------------------------ //

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
};

// ------------- //
// TESTING BLOCK //
// ------------- //

const std = @import("std");
const testing = std.testing;

test "default dialect values" {
    const dialect = Dialect{};

    try testing.expectEqual(@as(u8, ','), dialect.separator);
    try testing.expectEqual(@as(u8, '"'), dialect.quote);
    try testing.expectEqual(LineEnding.lf, dialect.line_ending);
}

test "predicates work on default const dialect" {
    const dialect = Dialect{};

    try testing.expect(dialect.isSeparator(','));
    try testing.expect(!(dialect.isSeparator('|')));

    try testing.expect(dialect.isQuote('"'));
    try testing.expect(!(dialect.isQuote('.')));

    try testing.expect(dialect.isLineEnding("hello, world!\n", 13));
    try testing.expect(!(dialect.isLineEnding("hello, world!\n", 2)));
}

test "predicates work on custom dialect" {
    // TODO: Should we limit what can be entered here?
    const dialect = Dialect{
        .line_ending = LineEnding.crlf,
        .quote = '9',
        .separator = 'j',
    };

    try testing.expect(dialect.isSeparator('j'));
    try testing.expect(!(dialect.isSeparator(',')));

    try testing.expect(dialect.isQuote('9'));
    try testing.expect(!(dialect.isQuote('"')));

    try testing.expect(dialect.isLineEnding("hello, world!\r\n", 13));
    try testing.expect(!(dialect.isLineEnding("hello, world!\r\n", 2)));
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
