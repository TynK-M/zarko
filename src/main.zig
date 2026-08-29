const std = @import("std");
const zarko = @import("zarko");

fn debugPrintExampleName(name: []const u8) void {
    std.debug.print("================================\n", .{});
    std.debug.print("Zarko example: {s}.\n", .{name});
    std.debug.print("================================\n", .{});
}

pub fn parserExample() !void {
    debugPrintExampleName("Parser");

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

pub fn fileParserExample(io: std.Io) !void {
    // TODO: look if it is possible to create a tmp file and open it in the
    // example instead of having to commit an "example.csv".
    // In the meanwhile, this example want to by used, create the file and
    // populate it, feel free to use the data from `parserExample()`.

    debugPrintExampleName("FileParser");

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();

    var parser = try zarko.FileParser.init(
        io,
        arena.allocator(),
        "example.csv",
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

pub fn main(init: std.process.Init) !void {
    _ = init;

    try parserExample();
    // try fileParserExample(init.io);
}
