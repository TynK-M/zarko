const std = @import("std");

pub const Record = struct {
    fields: []const []const u8,

    pub fn len(self: Record) usize {
        return self.fields.len;
    }

    pub fn isEmpty(self: Record) bool {
        return self.fields.len == 0;
    }

    pub fn get(self: Record, index: usize) ?[]const u8 {
        if (index >= self.fields.len) return null;
        return self.fields[index];
    }

    pub fn at(self: Record, index: usize) []const u8 {
        return self.fields[index];
    }

    pub fn iterator(self: Record) Iterator {
        return .{
            .fields = self.fields,
            .index = 0,
        };
    }

    pub const Iterator = struct {
        fields: []const []const u8,
        index: usize,

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

    const record = Record{
        .fields = &fields
    };

    try testing.expectEqualStrings("Hi", record.at(0));
    try testing.expectEqualStrings("From", record.at(1));
    try testing.expectEqualStrings("Zarko", record.at(2));
}

test "at returns empty field correctly" {
    const fields = [_][]const u8{
        "",
    };

    const record = Record{
        .fields = &fields
    };

    try testing.expectEqualStrings("", record.at(0));
}

test "at can be used with len iteration" {
    const fields = [_][]const u8{
        "Hi",
        "From",
        "Zarko",
    };

    const record = Record{
        .fields = &fields
    };

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
