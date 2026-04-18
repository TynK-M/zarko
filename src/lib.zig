const std = @import("std");

pub fn printAnotherMessage(
    list: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
) !void {
    try list.appendSlice(allocator, "Hello, World!\n");
}

test "Hello, World!" {
    const allocator = std.testing.allocator;

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    try printAnotherMessage(&buf, allocator);

    try std.testing.expectEqualStrings(
        "Hello, World!\n",
        buf.items,
    );
}