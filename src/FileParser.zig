//! Provides a streaming CSV parser.

const std = @import("std");
const Parser = @import("Parser.zig").Parser;
const Record = @import("Record.zig").Record;
const Dialect = @import("Dialect.zig").Dialect;

/// Parses CSV data from a file into records.
///
/// A `FileParser` reads from an input file and produces one `Record` at a
/// time.
/// Parsed records borrow fields slices from the input whenever possible.
/// Fields requiring quote unescaping are newly allocated.
pub const FileParser = struct {
    /// Desired `Io` instance.
    io: std.Io,

    /// Allocator used for record storage and unescaped fields.
    allocator: std.mem.Allocator,

    /// The CSV file path.
    filepath: []const u8,

    /// The content of the CSV file.
    input: []u8,

    /// Parser operating on `input`.
    parser: Parser,

    /// The CSV dialect used while parsing.
    dialect: Dialect,

    /// Creates a file parser for the given CSV file path.
    pub fn init(
        io: std.Io,
        allocator: std.mem.Allocator,
        filepath: []const u8,
        dialect: Dialect,
    ) !FileParser {
        const input = try std.Io.Dir.cwd().readFileAlloc(
            io,
            filepath,
            allocator,
            .unlimited,
        );
        errdefer allocator.free(input);

        return .{
            .allocator = allocator,
            .io = io,
            .filepath = filepath,
            .dialect = dialect,
            .input = input,
            .parser = Parser.init(allocator, input, dialect),
        };
    }

    /// Releases all memory owned by the file parser.
    pub fn deinit(self: *FileParser) void {
        self.allocator.free(self.input);
    }

    /// Returns the next record, or null at EOF.
    pub fn next(self: *FileParser) !?Record {
        return self.parser.next();
    }
};
