//! Provides a representation of a parsed CSV row.

const std = @import("std");

/// Represents a row of a parsed CSV.
///
/// A `Record` stores the fields contained in a single row. Field values may
/// either borrow from the parser input or refer to memory owned by the record.
///
/// The `fields` slice is owned by the record. Any field data stored in `owned`
/// is also owned by the record and is released by `deinit`.
pub const Record = struct {
    /// The fields contained in this record.
    ///
    /// Individual fields may borrow from the parser input or refer to memory
    /// owned by this record.
    fields: []const []const u8,

    /// Fields data allocated while parsing this record.
    ///
    /// This is used for fields that require transformations such as quote
    /// unescaping. The record owns these allocations and releases them when
    /// `deinit` is called.
    owned: []const []const u8 = &.{},

    /// Releases all memory owned by the record.
    ///
    /// This frees the field data stored in `owned` and the `fields` array.
    /// Fields data borrowed from the parser input is not freed.
    pub fn deinit(self: *Record, allocator: std.mem.Allocator) void {
        for (self.owned) |field| {
            allocator.free(field);
        }

        allocator.free(self.owned);
        allocator.free(self.fields);
    }

    /// Returns the number of fields in the record.
    pub fn len(self: Record) usize {
        return self.fields.len;
    }

    /// Returns whether the record contains no fields.
    pub fn isEmpty(self: Record) bool {
        return self.fields.len == 0;
    }

    /// Returns the field at `index`, or `null` if the `index` is
    /// out of bound.
    pub fn get(self: Record, index: usize) ?[]const u8 {
        if (index >= self.fields.len) return null;
        return self.fields[index];
    }

    /// Returns the field at `index`.
    ///
    /// Panics if `index` is outside the record bounds.
    pub fn at(self: Record, index: usize) []const u8 {
        return self.fields[index];
    }

    /// Creates an iterator over the record fields.
    ///
    /// The iterator borrows the record's field storage.
    pub fn iterator(self: Record) Iterator {
        return .{
            .fields = self.fields,
            .index = 0,
        };
    }

    /// Iterates over the fields of a record.
    pub const Iterator = struct {
        /// The fields being iterated over.
        fields: []const []const u8,

        /// Current position in the fields slice.
        index: usize,

        /// Returns the next field, or `null` when iteration is complete.
        pub fn next(it: *Iterator) ?[]const u8 {
            if (it.index >= it.fields.len) return null;

            defer it.index += 1;
            return it.fields[it.index];
        }
    };
};

const testing = std.testing;

test "len returns number of fields" {
    const fields = [_][]const u8{
        "Hi",
        "From",
        "Zarko",
    };

    const record = Record{
        .fields = &fields,
    };

    try testing.expectEqual(@as(usize, 3), record.len());
    try testing.expect(!record.isEmpty());
}

test "empty record" {
    const fields = [_][]const u8{};
    const record = Record{
        .fields = &fields,
    };

    try testing.expectEqual(@as(usize, 0), record.len());
    try testing.expect(record.isEmpty());
}

test "get returns field at index" {
    const fields = [_][]const u8{
        "Hi",
        "From",
        "Zarko",
    };

    const record = Record{
        .fields = &fields,
    };

    try testing.expectEqualStrings("Hi", record.get(0).?);
    try testing.expectEqualStrings("From", record.get(1).?);
    try testing.expectEqualStrings("Zarko", record.get(2).?);
}

test "get returns null for out of bounds" {
    const fields = [_][]const u8{
        "Hi",
    };

    const record = Record{
        .fields = &fields,
    };

    try testing.expect(record.get(1) == null);
    try testing.expect(record.get(69) == null);
}

test "at returns field at valid index" {
    const fields = [_][]const u8{
        "Hi",
        "From",
        "Zarko",
    };

    const record = Record{ .fields = &fields };

    try testing.expectEqualStrings("Hi", record.at(0));
    try testing.expectEqualStrings("From", record.at(1));
    try testing.expectEqualStrings("Zarko", record.at(2));
}

test "at returns empty field correctly" {
    const fields = [_][]const u8{
        "",
    };

    const record = Record{ .fields = &fields };

    try testing.expectEqualStrings("", record.at(0));
}

test "at can be used with len iteration" {
    const fields = [_][]const u8{
        "Hi",
        "From",
        "Zarko",
    };

    const record = Record{ .fields = &fields };

    var i: usize = 0;
    while (i < record.len()) : (i += 1) {
        try testing.expectEqualStrings(fields[i], record.at(i));
    }
}

test "iterator visits every field in order" {
    const fields = [_][]const u8{
        "Hi",
        "From",
        "Zarko",
    };

    const record = Record{
        .fields = &fields,
    };

    var it = record.iterator();

    try testing.expectEqualStrings("Hi", it.next().?);
    try testing.expectEqualStrings("From", it.next().?);
    try testing.expectEqualStrings("Zarko", it.next().?);
    try testing.expect(it.next() == null);
}

test "iterator on empty record" {
    const fields = [_][]const u8{};
    const record = Record{
        .fields = &fields,
    };

    var it = record.iterator();

    try testing.expect(it.next() == null);
}
