const std = @import("std");

/// Runtime dialect for CSV parsing and writing.
pub const Dialect = struct {
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

/// Commonly used CSV/TSV dialects.
///
/// The available dialects include:
/// - `excel`       → standard CSV behavior
/// - `excel_tab`   → TSV (tab-separated values)
/// - `unix`        → stricter newline and parsing rules
/// - `strict`      → minimal flexibility, safer parsing
/// - `whitespace`  → excel with trim whitespace around unquoted fields
pub const DialectPresets = struct {
    /// Standard CSV behavior, compatible with Microsoft Excel.
    pub const excel = Dialect{
        .delimiter = ',',
        .record_delimiter = '\n',
        .quote = '"',
        .trim_whitespace = false,
        .has_header = false,
        .allow_multiline = true,
    };

    /// Tab-separated values, commonly used for TSV files.
    pub const excel_tab = Dialect{
        .delimiter = '\t',
        .record_delimiter = '\n',
        .quote = '"',
        .trim_whitespace = false,
        .has_header = false,
        .allow_multiline = true,
    };

    /// Stricter parsing rules, with no multiline fields allowed.
    pub const unix = Dialect{
        .delimiter = ':',
        .record_delimiter = '\n',
        .quote = '"',
        .trim_whitespace = false,
        .has_header = false,
        .allow_multiline = false,
    };

    /// Minimal flexibility, with no multiline fields and no whitespace trimming.
    pub const strict = Dialect{
        .delimiter = ',',
        .record_delimiter = '\n',
        .quote = '"',
        .trim_whitespace = false,
        .has_header = false,
        .allow_multiline = false,
    };

    /// Excel-like behavior with whitespace trimming around unquoted fields.
    pub const whitespace = Dialect{
        .delimiter = ',',
        .record_delimiter = '\n',
        .quote = '"',
        .trim_whitespace = true,
        .has_header = false,
        .allow_multiline = true,
    };
};

// Tests

// Test default dialect.
test "Dialect defaults" {
    const cfg = Dialect{};
    try std.testing.expectEqual(@as(u8, ','), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
    try std.testing.expectEqual(false, cfg.trim_whitespace);
    try std.testing.expectEqual(false, cfg.has_header);
    try std.testing.expectEqual(true, cfg.allow_multiline);
}

// Test excel dialect.
test "Excel dialect" {
    const cfg = DialectPresets.excel;
    try std.testing.expectEqual(@as(u8, ','), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
    try std.testing.expectEqual(false, cfg.trim_whitespace);
    try std.testing.expectEqual(false, cfg.has_header);
    try std.testing.expectEqual(true, cfg.allow_multiline);
}

// Test excel_tab dialect.
test "ExcelTab dialect" {
    const cfg = DialectPresets.excel_tab;
    try std.testing.expectEqual(@as(u8, '\t'), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
    try std.testing.expectEqual(false, cfg.trim_whitespace);
    try std.testing.expectEqual(false, cfg.has_header);
    try std.testing.expectEqual(true, cfg.allow_multiline);
}

// Test unix dialect.
test "Unix dialect" {
    const cfg = DialectPresets.unix;
    try std.testing.expectEqual(@as(u8, ':'), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
    try std.testing.expectEqual(false, cfg.trim_whitespace);
    try std.testing.expectEqual(false, cfg.has_header);
    try std.testing.expectEqual(false, cfg.allow_multiline);
}

// Test strict dialect.
test "Strict dialect" {
    const cfg = DialectPresets.strict;
    try std.testing.expectEqual(@as(u8, ','), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
    try std.testing.expectEqual(false, cfg.trim_whitespace);
    try std.testing.expectEqual(false, cfg.has_header);
    try std.testing.expectEqual(false, cfg.allow_multiline);
}

// Test whitespace dialect.
test "Whitespace dialect" {
    const cfg = DialectPresets.whitespace;
    try std.testing.expectEqual(@as(u8, ','), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
    try std.testing.expectEqual(true, cfg.trim_whitespace);
    try std.testing.expectEqual(false, cfg.has_header);
    try std.testing.expectEqual(true, cfg.allow_multiline);
}
