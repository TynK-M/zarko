const std = @import("std");

pub const Dialect = @import("dialect.zig").Dialect;
pub const Row = @import("row.zig").Row;

/// CSV file writer.
///
/// Wraps `std.Io.File` and exposes a small convenience API for writing
/// rows to a file in CSV format.
pub const Writer = struct {
    /// I/O context used for all file operations.
    io: std.Io,

    /// Open file handle.
    file: std.Io.File,

    /// Internal Zig writer interface.
    writer: std.Io.File.Writer,

    /// CSV dialect configuration.
    dialect: Dialect,

    /// Opens a file for writing (or creates if it doesn't exist).
    ///
    /// Parameters:
    /// - `io`: active Zig I/O context.
    /// - `dir`: optional directory to open the file in. If not provided, the current working directory will be used.
    /// - `path`: relative or absolute path to the file.
    /// - `dialect`: CSV dialect configuration to use when writing rows.
    /// - `buffer`: buffer to use for internal writer operations.
    ///
    /// Returns an initialized `Writer`.
    ///
    /// The returned writer must be closed with `close()`.
    pub fn open(io: std.Io, dir: ?std.Io.Dir, path: []const u8, dialect: Dialect, buffer: []u8) !Writer {
        const file_dir = dir orelse std.Io.Dir.cwd();

        const file = try file_dir.createFile(
            io,
            path,
            .{},
        );

        return .{
            .io = io,
            .file = file,
            .writer = file.writer(io, buffer),
            .dialect = dialect,
        };
    }

    /// Flushes any buffered data to the underlying file.
    pub fn flush(self: *Writer) !void {
        try self.writer.flush();
    }

    /// Closes the underlying file handle.
    ///
    /// After calling this function, the writer must not be used again.
    pub fn close(self: *Writer) void {
        self.writer.flush() catch {};
        self.file.close(self.io);
    }

    /// Writes a single row to the file.
    ///
    /// Parameters:
    /// - `row`: the row to write.
    ///
    /// The row's fields will be written in order, separated by the dialect's delimiter.
    /// A record delimiter will be written at the end of the row.
    pub fn writeRow(self: *Writer, row: Row) !void {
        if (row.fields.len == 0) {
            try self.writer.interface.writeByte(self.dialect.record_delimiter);
            return;
        }
        for (row.fields, 0..) |field, index| {
            _ = try self.writer.interface.write(field);
            if (index != row.fields.len - 1) {
                try self.writer.interface.writeByte(self.dialect.delimiter);
            }
        }
        try self.writer.interface.writeByte(self.dialect.record_delimiter);
    }
};

// Tests

const testing = std.testing;

// Test for `Writer.writeRow` with a single row of three fields.
test "Test writeRow with one row" {
    const io = testing.io;
    var buffer: [4096]u8 = undefined;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = "test.csv";

    var writer = try Writer.open(
        io,
        tmp.dir,
        path,
        .{ .delimiter = ',', .record_delimiter = '\n' },
        buffer[0..],
    );
    defer writer.close();

    var fields: [3][]const u8 = .{ "a", "b", "c" };
    const row = Row{
        .fields = fields[0..],
    };

    try writer.writeRow(row);
    try writer.flush();

    const file = try tmp.dir.openFile(io, path, .{});
    defer file.close(io);

    var buf: [64]u8 = undefined;
    var reader = file.reader(io, &buf);
    const n = try reader.interface.readSliceShort(&buf);
    const content = buf[0..n];
    try std.testing.expectEqualStrings("a,b,c\n", content);
}
