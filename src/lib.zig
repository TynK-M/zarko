/// Public API exports.
///
/// Reader          :   byte-oriented file input.
/// Parser          :   zero-allocation CSV parsing.
/// Writer          :   byte-oriented file output.
/// Dialect         :   parser dialect.
/// DialectPresets  :   common dialect presets.
/// Row             :   parsed record view.
pub const Reader = @import("reader.zig").Reader;
pub const Parser = @import("parser.zig").Parser;
pub const Writer = @import("writer.zig").Writer;

const dialect = @import("dialect.zig");
pub const Dialect = dialect.Dialect;
pub const DialectPresets = dialect.DialectPresets;
pub const Row = @import("row.zig").Row;

test {
    _ = @import("reader.zig");
    _ = @import("parser.zig");
    _ = @import("writer.zig");

    _ = @import("dialect.zig");
    _ = @import("row.zig");
}
