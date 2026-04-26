/// Public API exports.
///
/// Reader  :   byte-oriented file input.
/// Parser  :   zero-allocation CSV parsing.
/// Dialect :   parser dialect.
/// Row     :   parsed record view.
pub const Reader = @import("reader.zig").Reader;
pub const Parser = @import("parser.zig").Parser;

const dialect = @import("dialect.zig");
pub const Dialect = dialect.Dialect;
pub const DialectPresets = dialect.DialectPresets;
pub const Row = @import("row.zig").Row;

test {
    _ = @import("reader.zig");
    _ = @import("parser.zig");

    _ = @import("dialect.zig");
    _ = @import("row.zig");
}
