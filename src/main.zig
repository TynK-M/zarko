const std = @import("std");
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    std.debug.print("Zarko test.\n", .{});

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

    var parser = Parser.init(csv, arena.allocator());

    while (try parser.next()) |record| {
        for (record.fields) |field| {
            std.debug.print("{s} ", .{field});
        }
        std.debug.print("\n", .{});
    }
}
