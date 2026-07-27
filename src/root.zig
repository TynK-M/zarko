//! Zarko is a CSV parsing library for Zig.
//!
//! Provides types for parsing CSV input, representing records, and
//! configuring CSV dialect options such as separators, quotes, and
//! line_endings.

pub const Record = @import("record.zig").Record;

pub const LineEnding = @import("line_ending.zig").LineEnding;
pub const Dialect = @import("dialect.zig").Dialect;
pub const dialects = @import("dialects.zig");

pub const Parser = @import("parser.zig").Parser;

const std = @import("std");
const testing = std.testing;

test {
    _ = .{
        @import("record.zig"),

        @import("line_ending.zig"),
        @import("dialect.zig"),
        @import("dialects.zig"),

        @import("parser.zig"),
    };
}
