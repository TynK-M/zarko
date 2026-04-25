/// Public API exports.
///
/// Reader  :   byte-oriented file input.
/// Parser  :   zero-allocation CSV parsing.
/// Config  :   parser options.
/// Row     :   parsed record view.
pub const Reader = @import("reader.zig").Reader;
pub const Parser = @import("parser.zig").Parser;

pub const Config = @import("config.zig").Config;
pub const Row = @import("row.zig").Row;

test {
    _ = @import("reader.zig");
    _ = @import("parser.zig");

    _ = @import("config.zig");
    _ = @import("row.zig");
}
