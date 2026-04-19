pub const Config = @import("config.zig").Config;
pub const Row = @import("row.zig").Row;
pub const Parser = @import("parser.zig").Parser;

test {
    _ = @import("parser.zig");
    _ = @import("config.zig");
    _ = @import("row.zig");
}
