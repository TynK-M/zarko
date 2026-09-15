const std = @import("std");
const zarko = @import("zarko");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();

    const csv_path = "examples/file_writer.csv.test";

    var writer = try zarko.FileWriter.init(
        io,
        csv_path,
        .{},
    );
    defer writer.deinit();

    try writer.writeRecord(&.{ "article", "cost" });
    try writer.writeRecord(&.{ "goleador", "0.10€" });

    try writer.flush();
    std.debug.print("File created successfully and can be found at path: '{s}'\n", .{csv_path});
}
