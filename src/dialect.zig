const std = @import("std");

/// Runtime dialect for CSV parsing and writing.
pub const Dialect = struct {
    /// Field separator character.
    delimiter: u8 = ',',

    /// Record separator character.
    record_delimiter: u8 = '\n',

    /// Quote character used for escaped fields.
    quote: u8 = '"',
};

/// Commonly used CSV/TSV dialects.
///
/// The available dialects include:
/// - `excel`       → standard CSV behavior
/// - `excel_tab`   → TSV (tab-separated values)
/// - `unix`        → unix delimiter (colon-separated values)
pub const DialectPresets = struct {
    /// Standard CSV behavior, compatible with Microsoft Excel.
    pub const excel = Dialect{
        .delimiter = ',',
        .record_delimiter = '\n',
        .quote = '"',
    };

    /// Tab-separated values, commonly used for TSV files.
    pub const excel_tab = Dialect{
        .delimiter = '\t',
        .record_delimiter = '\n',
        .quote = '"',
    };

    /// Stricter parsing rules.
    pub const unix = Dialect{
        .delimiter = ':',
        .record_delimiter = '\n',
        .quote = '"',
    };
};

// Tests

// Test default dialect.
test "Dialect defaults" {
    const cfg = Dialect{};
    try std.testing.expectEqual(@as(u8, ','), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
}

// Test excel dialect.
test "Excel dialect" {
    const cfg = DialectPresets.excel;
    try std.testing.expectEqual(@as(u8, ','), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
}

// Test excel_tab dialect.
test "ExcelTab dialect" {
    const cfg = DialectPresets.excel_tab;
    try std.testing.expectEqual(@as(u8, '\t'), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
}

// Test unix dialect.
test "Unix dialect" {
    const cfg = DialectPresets.unix;
    try std.testing.expectEqual(@as(u8, ':'), cfg.delimiter);
    try std.testing.expectEqual(@as(u8, '\n'), cfg.record_delimiter);
    try std.testing.expectEqual(@as(u8, '"'), cfg.quote);
}
