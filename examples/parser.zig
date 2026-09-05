const std = @import("std");
const zarko = @import("zarko");

pub fn main() !void {
    const csv =
        \\name,age,city
        \\Matteo,22,Rome
        \\Linus,56,Helsinki
        \\Ada,"36",London
        \\QuoteTest,"312","Hello, ""World!"""
    ;

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();

    var parser = zarko.Parser.init(arena.allocator(), csv, .{});

    while (try parser.next()) |record| {
        for (record.fields) |field| {
            std.debug.print("{s} ", .{field});
        }
        std.debug.print("\n", .{});
    }
}
