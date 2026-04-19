const std = @import("std");

/// Runtime configuration for CSV parsing and writing.
pub const Config = struct {

    /// Field separator character.
    delimiter: u8 = ',',

    /// Record separator character.
    record_delimiter: u8 = '\n',

    /// Quote character used for escaped fields.
    quote: u8 = '"',

    /// Trim spaces and tabs around unquoted fields.
    trim_whitespace: bool = false,

    /// Specify if a header is expected.
    has_header: bool = false,

    /// Allow quoted fields to span multiple lines.
    allow_multiline: bool = true,
};

// Tests

// Test default configuration.
test "Config defaults" {
    const cfg = Config{};
    try std.testing.expectEqual(@as(u8, ','), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
    try std.testing.expectEqual(false, cfg.trim_whitespace);
    try std.testing.expectEqual(false, cfg.has_header);
    try std.testing.expectEqual(true, cfg.allow_multiline);
}
