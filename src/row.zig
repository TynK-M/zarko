const std = @import("std");

/// Represents one parsed CSV row.
///
/// Field slices are borrowed from the parser buffer and remain valid until
/// the next `next()` call or `deinit()`.
pub const Row = struct {
    fields: [][]const u8,

    /// Returns the field at `index`, or null if out of range.
    pub fn get(self: Row, index: usize) ?[]const u8 {
        if (index >= self.fields.len) return null;
        return self.fields[index];
    }

    /// Number of fields in the row.
    pub fn len(self: Row) usize {
        return self.fields.len;
    }
};

// Tests

// Test Row get and len to see if they work as intended.
test "Row get and len" {
    var fields = [_][]const u8{ "a", "b", "c" };
    const row = Row{ .fields = fields[0..] };

    try std.testing.expectEqual(@as(usize, 3), row.len());
    try std.testing.expectEqualStrings("b", row.get(1).?);
    try std.testing.expect(row.get(99) == null);
}
