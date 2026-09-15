//! Zarko is a CSV parsing library for Zig.
//!
//! Provides types for parsing CSV input, representing records, and
//! configuring CSV dialect options such as separators, quotes, and
//! line_endings.

pub const Record = @import("Record.zig").Record;

pub const LineEnding = @import("LineEnding.zig").LineEnding;
pub const Dialect = @import("Dialect.zig").Dialect;
pub const builtin_dialects = @import("builtin_dialects.zig");

pub const Parser = @import("Parser.zig").Parser;
pub const FileParser = @import("FileParser.zig").FileParser;

pub const Writer = @import("Writer.zig").Writer;
pub const FileWriter = @import("FileWriter.zig").FileWriter;

const std = @import("std");
const testing = std.testing;

test {
    _ = .{
        @import("Record.zig"),

        @import("LineEnding.zig"),
        @import("Dialect.zig"),
        @import("builtin_dialects.zig"),

        @import("Parser.zig"),
        @import("FileParser.zig"),

        @import("Writer.zig"),
        @import("FileWriter.zig"),
    };
}
