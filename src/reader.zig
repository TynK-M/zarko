const std = @import("std");

/// Buffered byte reader for files.
///
/// Wraps `std.Io.File` and exposes a small convenience API for reading
/// bytes or slices from a file.
///
/// Uses an internal fixed-size buffer for efficient streaming reads.
///
/// End of input is reported as:
/// - `read(...) == 0`
/// - `takeByte() == null`
pub const Reader = struct {
    
    /// I/O context used for all file operations.
    io: std.Io,

    /// Open file handle.
    file: std.Io.File,

    /// Internal Zig reader interface.
    reader: std.Io.File.Reader,

    /// Internal read buffer.
    buffer: [4096]u8,

    /// Opens a file for reading and creates a buffered reader.
    ///
    /// Parameters:
    /// - `io`: active Zig I/O context.
    /// - `path`: relative or absolute path to the file.
    ///
    /// Returns an initialized `Reader`.
    ///
    /// The returned reader must be closed with `close()`.
    pub fn open(io: std.Io, path: []const u8) !Reader {
        const file = try std.Io.Dir.cwd().openFile(
            io,
            path,
            .{},
        );

        return .{
            .io = io,
            .file = file,
            .reader = file.reader(io, undefined),
            .buffer = undefined,
        };
    }

    /// Closes the underlying file handle.
    ///
    /// After calling this function, the reader must not be used again.
    pub fn close(self: *Reader) void {
        self.file.close(self.io);
    }

    /// Reads bytes into `buffer`.
    ///
    /// Returns:
    /// - number of bytes read
    /// - `0` on end of file
    ///
    /// May return fewer bytes than requested.
    pub fn read(
        self: *Reader,
        buffer: []u8,
    ) !usize {
        return self.reader.interface.readSliceShort(buffer);
    }

    /// Reads one byte from the stream.
    ///
    /// Returns:
    /// - `u8`: next byte
    /// - `null`: end of file
    pub fn takeByte(self: *Reader) !?u8 {
        var b: [1]u8 = undefined;

        const n = try self.reader.interface.readSliceShort(&b);
        if (n == 0) return null;

        return b[0];
    }
};

// Tests

// Create a reader and check that it can read bytes from a file
test "Create reader and check bytes read" {
    const io = std.testing.io;

    var reader = try Reader.open(io, "example/standard.csv");
    defer reader.close();

    const buf = try std.testing.allocator.alloc(u8, 1024);
    defer std.testing.allocator.free(buf);

    const res = try reader.read(buf);

    try std.testing.expect(res == 68);
}
