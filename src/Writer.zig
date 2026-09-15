//! Provides a CSV writer.

const std = @import("std");
const Dialect = @import("Dialect.zig").Dialect;

/// Writes CSV data to the given `std.Io.Writer`.
pub const Writer = struct {
    /// The choosed writer to use for writing.
    writer: *std.Io.Writer,

    /// The CSV dialect to use while writing.
    dialect: Dialect,

    /// Creates a writer from the given `std.Io.Writer`.
    pub fn init(writer: *std.Io.Writer, dialect: Dialect) Writer {
        return .{
            .writer = writer,
            .dialect = dialect,
        };
    }

    /// Writes one CSV record.
    ///
    /// Fields are quoted when necessary. Quotes inside quoted fields are
    /// escaped by doubling them, as required by CSV.
    pub fn writeRecord(self: *Writer, fields: []const []const u8) !void {
        for (fields, 0..) |field, i| {
            if (i != 0) {
                try self.writer.writeByte(self.dialect.separator);
            }

            try self.writeField(field);
        }

        try self.writer.writeAll(self.dialect.line_ending.bytes());
    }

    /// Writes one CSV field.
    ///
    /// A field is written without quotes when it does not contain any
    /// character that requires CSV quoting. Otherwise, the field is
    /// surrounded by the dialect's quote character.
    ///
    /// When a quoted field contains the quote character itself, each
    /// occurrence is escaped by writing the quote character twice.
    pub fn writeField(self: *Writer, field: []const u8) !void {
        if (!needsQuotes(field, self.dialect)) {
            try self.writer.writeAll(field);
            return;
        }

        try self.writer.writeByte(self.dialect.quote);

        for (field) |byte| {
            if (byte == self.dialect.quote) {
                try self.writer.writeByte(self.dialect.quote);
            }

            try self.writer.writeByte(byte);
        }

        try self.writer.writeByte(self.dialect.quote);
    }

    /// Returns whether `field` must be quoted according to `dialect`.
    ///
    /// A CSV field must be quoted when it contains the dialect's separator,
    /// quote character, a line feed, or a carriage return.
    ///
    /// The function only determines whether quoting is necessary; it does not
    /// modify or write the field.
    fn needsQuotes(field: []const u8, dialect: Dialect) bool {
        for (field) |c| {
            if (dialect.isSeparator(c) or
                dialect.isQuote(c) or
                dialect.isLineEndingByte(c))
            {
                return true;
            }
        }

        return false;
    }
};

test "writes an empty record" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{});

    try std.testing.expectEqualStrings(
        "\n",
        io_writer.buffered(),
    );
}

test "writes a record" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{
        "name",
        "age",
        "city",
    });

    try std.testing.expectEqualStrings(
        "name,age,city\n",
        io_writer.buffered(),
    );
}

test "writes multiple records" {
    var buffer: [256]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{
        "alice",
        "20",
        "Rome",
    });

    try writer.writeRecord(&.{
        "bob",
        "30",
        "Milan",
    });

    try std.testing.expectEqualStrings(
        "alice,20,Rome\n" ++
            "bob,30,Milan\n",
        io_writer.buffered(),
    );
}

test "writes an empty field" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{
        "hello",
        "",
        "world",
    });

    try std.testing.expectEqualStrings(
        "hello,,world\n",
        io_writer.buffered(),
    );
}

test "quotes field containing separator" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{
        "hello",
        "hello, world",
    });

    try std.testing.expectEqualStrings(
        "hello,\"hello, world\"\n",
        io_writer.buffered(),
    );
}

test "escapes quotes by doubling them" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{
        "hello",
        "say \"hello\"",
    });

    try std.testing.expectEqualStrings(
        "hello,\"say \"\"hello\"\"\"\n",
        io_writer.buffered(),
    );
}

test "quotes field containing newline" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{
        "hello",
        "line one\nline two",
    });

    try std.testing.expectEqualStrings(
        "hello,\"line one\nline two\"\n",
        io_writer.buffered(),
    );
}

test "quotes field containing carriage return" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{
        .line_ending = .crlf,
    });

    try writer.writeRecord(&.{
        "hello",
        "line one\rline two",
    });

    try std.testing.expectEqualStrings(
        "hello,\"line one\rline two\"\r\n",
        io_writer.buffered(),
    );
}

test "quotes field containing quote without separator" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{
        "hello",
        "say \"hello\"",
    });

    try std.testing.expectEqualStrings(
        "hello,\"say \"\"hello\"\"\"\n",
        io_writer.buffered(),
    );
}

test "handles field containing separator, quote and newline" {
    var buffer: [256]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeRecord(&.{
        "a,b\"c\nd",
    });

    try std.testing.expectEqualStrings(
        "\"a,b\"\"c\nd\"\n",
        io_writer.buffered(),
    );
}

test "supports custom separator" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{
        .separator = ';',
    });

    try writer.writeRecord(&.{
        "hello",
        "world",
    });

    try std.testing.expectEqualStrings(
        "hello;world\n",
        io_writer.buffered(),
    );
}

test "quotes custom separator" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{
        .separator = ';',
    });

    try writer.writeRecord(&.{
        "hello",
        "hello;world",
    });

    try std.testing.expectEqualStrings(
        "hello;\"hello;world\"\n",
        io_writer.buffered(),
    );
}

test "supports custom quote character" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{
        .quote = '\'',
    });

    try writer.writeRecord(&.{
        "hello",
        "it's me",
    });

    try std.testing.expectEqualStrings(
        "hello,'it''s me'\n",
        io_writer.buffered(),
    );
}

test "supports CRLF line endings" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{
        .line_ending = .crlf,
    });

    try writer.writeRecord(&.{
        "hello",
        "world",
    });

    try std.testing.expectEqualStrings(
        "hello,world\r\n",
        io_writer.buffered(),
    );
}

test "quotes fields containing CRLF" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{
        .line_ending = .crlf,
    });

    try writer.writeRecord(&.{
        "hello",
        "line one\r\nline two",
    });

    try std.testing.expectEqualStrings(
        "hello,\"line one\r\nline two\"\r\n",
        io_writer.buffered(),
    );
}

test "writes fields individually" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeField("hello");
    try io_writer.writeByte(',');
    try writer.writeField("hello, world");

    try std.testing.expectEqualStrings(
        "hello,\"hello, world\"",
        io_writer.buffered(),
    );
}

test "handles empty strings without quoting" {
    var buffer: [128]u8 = undefined;
    var io_writer = std.Io.Writer.fixed(&buffer);

    var writer = Writer.init(&io_writer, .{});

    try writer.writeField("");

    try std.testing.expectEqualStrings(
        "",
        io_writer.buffered(),
    );
}
