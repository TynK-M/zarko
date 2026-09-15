//! Provides a CSV file writer.

const std = @import("std");
const Dialect = @import("Dialect.zig").Dialect;
const Writer = @import("Writer.zig").Writer;

/// Writes CSV data to the given file.
pub const FileWriter = struct {
    /// Desired `Io` instance.
    io: std.Io,

    /// The CSV file.
    file: std.Io.File,

    /// The file writer of the CSV file.
    file_writer: std.Io.File.Writer,

    /// The CSV dialect to use while writing.
    dialect: Dialect,

    /// Creates a file writer for the given CSV file.
    pub fn init(
        io: std.Io,
        path: []const u8,
        dialect: Dialect,
    ) !FileWriter {
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});

        return .{
            .io = io,
            .file = file,
            .file_writer = file.writer(io, &.{}),
            .dialect = dialect,
        };
    }

    /// Releases all memory used by the file.
    pub fn deinit(
        self: *FileWriter,
    ) void {
        self.file.close(self.io);
    }

    /// Writes one CSV record in the file.
    ///
    /// Fields are quoted when necessary. Quotes inside quoted fields are
    /// escaped by doubling them, as required by CSV.
    pub fn writeRecord(
        self: *FileWriter,
        fields: []const []const u8,
    ) !void {
        var writer = Writer.init(
            &self.file_writer.interface,
            self.dialect,
        );

        try writer.writeRecord(fields);
    }

    /// Writes one CSV field in the file.
    ///
    /// A field is written without quotes when it does not contain any
    /// character that requires CSV quoting. Otherwise, the field is
    /// surrounded by the dialect's quote character.
    ///
    /// When a quoted field contains the quote character itself, each
    /// occurrence is escaped by writing the quote character twice.
    pub fn writeField(
        self: *FileWriter,
        field: []const u8,
    ) !void {
        var writer = Writer.init(
            &self.file_writer.interface,
            self.dialect,
        );

        try writer.writeField(field);
    }

    /// Flush the file writer.
    pub fn flush(self: *FileWriter) !void {
        // Don't Forget to Flush ~ Andrew Kelley
        try self.file_writer.interface.flush();
    }
};
