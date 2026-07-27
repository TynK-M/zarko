//! Common CSV dialect presets.

const Dialect = @import("dialect.zig").Dialect;
const LineEnding = @import("line_ending.zig").LineEnding;

/// Excel-compatible CSV dialect.
///
/// Uses commas for field separation, double quotes for quoting, and CRLF
/// line endings.
pub const excel = Dialect{
    .separator = ',',
    .quote = '"',
    .line_ending = .crlf,
};

/// Tab-separated values dialect.
///
/// Uses tabs for field separation, double quotes for quoting, and LF line
/// endings.
pub const tsv = Dialect{
    .separator = '\t',
    .quote = '"',
    .line_ending = .lf,
};

/// Semicolon-separated CSV dialect.
///
/// Uses semicolons for field separation, double quotes for quoting and LF
/// line endings.
pub const semicolon = Dialect{
    .separator = ';',
    .quote = '"',
    .line_ending = .lf,
};

const std = @import("std");
const testing = std.testing;

test "dialect presets" {
    const cases = .{
        .{
            .name = "excel",
            .actual = excel,
            .expected = Dialect{
                .separator = ',',
                .quote = '"',
                .line_ending = .crlf,
            },
        },
        .{
            .name = "tsv",
            .actual = tsv,
            .expected = Dialect{
                .separator = '\t',
                .quote = '"',
                .line_ending = .lf,
            },
        },
        .{
            .name = "semicolon",
            .actual = semicolon,
            .expected = Dialect{
                .separator = ';',
                .quote = '"',
                .line_ending = .lf,
            },
        },
    };

    inline for (cases) |case| {
        testing.expectEqual(case.expected, case.actual) catch |err| {
            std.debug.print("Dialect preset '{s}' failed:\n", .{case.name});
            return err;
        };
    }
}
