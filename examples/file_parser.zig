const std = @import("std");
const zarko = @import("zarko");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();

    var parser = try zarko.FileParser.init(
        io,
        arena.allocator(),
        "examples/example.csv",
        .{},
    );
    defer parser.deinit();

    while (try parser.next()) |record| {
        for (record.fields) |field| {
            std.debug.print("{s} ", .{field});
        }
        std.debug.print("\n", .{});
    }
}
