const std = @import("std");

pub const Dialect = @import("dialect.zig").Dialect;
pub const Row = @import("row.zig").Row;

/// Creates a zero-allocation CSV parser specialized for ReaderType.
///
/// ReaderType must provide:
/// - takeByte() !?u8
///
/// The parser reads one record at a time from the input stream into a
/// caller-provided line buffer, then splits fields into caller-provided
/// field slices.
///
/// No heap allocations are performed during parsing.
///
/// This parser currently handles delimiter-separated records line-by-line
/// and does not implement quoted-field CSV escaping.
pub fn Parser(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        /// Underlying byte stream reader.
        reader: ReaderType,

        /// CSV dialect configuration.
        dialect: Dialect,

        /// Single-byte pushback buffer for lookahead.
        pending: ?u8 = null,

        /// Creates a parser.
        pub fn init(reader: ReaderType, dialect: Dialect) Self {
            return .{
                .reader = reader,
                .dialect = dialect,
            };
        }

        /// Reads next CSV row.
        ///
        /// Returns:
        /// - Row: parsed row
        /// - null: EOF before any data
        ///
        /// Errors:
        /// - LineTooLong
        /// - TooManyFields
        /// - UnexpectedEndOfFile
        pub fn next(
            self: *Self,
            line_buf: []u8,
            fields_buf: [][]const u8,
        ) !?Row {
            var write_index: usize = 0;
            var field_start: usize = 0;
            var field_count: usize = 0;

            var in_quote = false;
            var field_started = false;
            var row_started = false;

            while (true) {
                const maybe = try self.getByte();

                if (maybe == null) {
                    if (!row_started and field_count == 0 and write_index == 0)
                        return null;

                    if (in_quote)
                        return error.UnexpectedEndOfFile;

                    try self.pushField(
                        fields_buf,
                        &field_count,
                        line_buf[field_start..write_index],
                    );

                    return Row{ .fields = fields_buf[0..field_count] };
                }

                const byte = maybe.?;
                row_started = true;

                if (in_quote) {
                    if (byte == '"') {
                        if (try self.getByte()) |next_byte| {
                            if (next_byte == '"') {
                                try self.append(line_buf, &write_index, '"');
                                field_started = true;
                            } else {
                                self.unread(next_byte);
                                in_quote = false;
                            }
                        } else {
                            in_quote = false;
                        }
                    } else {
                        try self.append(line_buf, &write_index, byte);
                        field_started = true;
                    }
                    continue;
                }

                switch (byte) {
                    '"' => {
                        if (!field_started) {
                            in_quote = true;
                        } else {
                            try self.append(line_buf, &write_index, '"');
                            field_started = true;
                        }
                    },

                    else => {
                        if (byte == self.dialect.delimiter) {
                            try self.pushField(
                                fields_buf,
                                &field_count,
                                line_buf[field_start..write_index],
                            );
                            field_start = write_index;
                            field_started = false;
                        } else if (byte == self.dialect.record_delimiter) {
                            return self.finishRow(
                                fields_buf,
                                &field_count,
                                line_buf,
                                field_start,
                                write_index,
                            );
                        } else {
                            try self.append(line_buf, &write_index, byte);
                            field_started = true;
                        }
                    },
                }
            }
        }

        /// Returns the next byte from the input stream, if available.
        ///
        /// This function reads from an internal one-byte pushback buffer first
        /// (used for lookahead during parsing). If no pending byte exists, it
        /// delegates to the underlying reader.
        ///
        /// Behavior:
        /// - Returns ?u8 containing the next byte if available.
        /// - Returns null when end-of-stream is reached.
        /// - Propagates any underlying reader errors except EndOfStream,
        ///   which is mapped to null.
        ///
        /// This is the primary byte-fetching primitive used by the parser and
        /// supports controlled unreading via unread().
        fn getByte(self: *Self) !?u8 {
            if (self.pending) |byte| {
                self.pending = null;
                return byte;
            }

            const byte = self.reader.takeByte() catch |err| switch (err) {
                error.EndOfStream => return null,
                else => return err,
            };

            if (byte == '\r') {
                const next_byte = self.reader.takeByte() catch |err| switch (err) {
                    error.EndOfStream => return '\r',
                    else => return err,
                };

                if (next_byte == '\n') return '\n';

                self.pending = next_byte;
                return '\r';
            }

            return byte;
        }

        /// Pushes a single byte back into the parser's input stream.
        ///
        /// This enables limited lookahead by allowing the next call to getByte()
        /// to return this byte instead of reading from the underlying reader.
        ///
        /// Behavior:
        /// - Only a single byte of pushback is supported.
        /// - Calling unread() twice without an intervening getByte() will
        /// overwrite the previously stored byte.
        ///
        /// Typical usage:
        /// Used after peeking ahead (via getByte()) when a byte has been read
        /// but determined not to belong to the current parsing context.
        fn unread(self: *Self, byte: u8) void {
            self.pending = byte;
        }

        /// Appends a single byte into the output buffer at the current write index.
        ///
        /// This function is used to build the current CSV field inside line_buf
        /// during parsing. It performs a bounds check to ensure the buffer is not
        /// exceeded.
        ///
        /// Behavior:
        /// - Writes byte at buf[write_index.*]
        /// - Increments write_index
        /// - Returns error.LineTooLong if the buffer capacity is exceeded
        ///
        /// This function does not allocate and operates entirely on caller-provided
        /// memory.
        fn append(
            self: *Self,
            buf: []u8,
            i: *usize,
            byte: u8,
        ) !void {
            _ = self;
            if (i.* >= buf.len)
                return error.LineTooLong;

            buf[i.*] = byte;
            i.* += 1;
        }

        /// Appends a parsed field slice into the output fields buffer.
        ///
        /// This function is called whenever a field boundary is reached
        /// (delimiter, row end, or EOF). It stores a slice of line_buf
        /// representing the current field into fields_buf.
        ///
        /// Behavior:
        /// - Stores field as a slice (zero-copy view into line_buf)
        /// - Increments field count
        /// - Returns error.TooManyFields if the buffer is full
        ///
        /// The function does not copy data; ownership remains with line_buf.
        fn pushField(
            self: *Self,
            fields: [][]const u8,
            count: *usize,
            field: []const u8,
        ) !void {
            _ = self;
            if (count.* >= fields.len)
                return error.TooManyFields;

            fields[count.*] = field;
            count.* += 1;
        }

        /// Finalizes the current CSV row and returns it as a Row.
        ///
        /// This helper centralizes row completion logic so that all row-ending
        /// conditions (delimiter, newline, CRLF, EOF, custom record delimiter)
        /// behave consistently.
        ///
        /// It performs a final field push for the current in-progress field and
        /// returns a Row that references slices inside line_buf
        /// (zero-copy).
        ///
        /// This function does not allocate and does not modify buffers beyond
        /// finalizing the current field boundaries.
        fn finishRow(
            self: *Self,
            fields_buf: [][]const u8,
            field_count: *usize,
            line_buf: []const u8,
            field_start: usize,
            write_index: usize,
        ) !?Row {
            try self.pushField(
                fields_buf,
                field_count,
                line_buf[field_start..write_index],
            );

            return Row{
                .fields = fields_buf[0..field_count.*],
            };
        }
    };
}

// Tests
//
// A Reader.fixed() is used as a simple in-memory reader for testing the parser.

const testing = std.testing;

// Test parsing simple CSV rows without allocation.
test "Parse simple CSV rows" {
    const input = std.Io.Reader.fixed("a,byte,c\n1,2,3\n");

    var parser = Parser(@TypeOf(input)).init(
        input,
        .{},
    );

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row1 = (try parser.next(&line_buf, &field_buf)).?;
    try testing.expectEqual(@as(usize, 3), row1.fields.len);
    try testing.expectEqualStrings("a", row1.fields[0]);
    try testing.expectEqualStrings("byte", row1.fields[1]);
    try testing.expectEqualStrings("c", row1.fields[2]);

    const row2 = (try parser.next(&line_buf, &field_buf)).?;
    try testing.expectEqual(@as(usize, 3), row2.fields.len);
    try testing.expectEqualStrings("1", row2.fields[0]);
    try testing.expectEqualStrings("2", row2.fields[1]);
    try testing.expectEqualStrings("3", row2.fields[2]);

    const row3 = try parser.next(&line_buf, &field_buf);
    try testing.expect(row3 == null);
}

// Test to see if empty fields are parsed correctly, including consecutive delimiters.
test "Parse empty fields" {
    const input = std.Io.Reader.fixed("a,,c\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 3), row.fields.len);
    try testing.expectEqualStrings("a", row.fields[0]);
    try testing.expectEqualStrings("", row.fields[1]);
    try testing.expectEqualStrings("c", row.fields[2]);
}

// Test to see if a trailing delimiter results in an empty field.
test "Parse trailing empty field" {
    const input = std.Io.Reader.fixed("a,byte,\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 3), row.fields.len);
    try testing.expectEqualStrings("a", row.fields[0]);
    try testing.expectEqualStrings("byte", row.fields[1]);
    try testing.expectEqualStrings("", row.fields[2]);
}

// Test that different delimiters can be configured and parsed correctly, also called Pizza Pasta test.
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⠤⠴⠖⡚⢉⠍⡉⢡⠂⠔⡉⡙⠶⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⠴⠒⡍⠩⢐⠨⢐⠂⡡⠌⡐⠌⠤⠘⡠⠑⡐⢂⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⠴⠚⢩⠠⠘⡐⠠⠃⡌⠄⡃⢌⠐⣤⣡⢮⣖⣻⣵⠿⠽⠛⢣⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡶⠏⡀⠸⠈⡀⢆⠱⠈⢁⠶⢀⢱⢰⡾⢿⣶⣹⡾⠏⠉⠀⠀⠀⠀⠈⢇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⢀⡤⠞⡉⠰⠠⠡⢑⠨⠐⡂⢌⡘⢠⢦⡗⢯⣳⡿⠛⠋⠁⢀⣤⣶⢿⣻⣿⣶⣤⡈⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⣀⠴⢋⠐⠤⢁⠡⠡⠑⢂⠡⡑⣨⢴⡺⣏⡷⡞⠋⠁⠀⠀⠀⢤⣿⢯⣟⣯⠿⣽⣞⡯⣿⣎⢧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⢀⣼⠏⡐⠌⡨⠐⠌⢂⠥⠉⣄⡧⣞⢧⡯⠗⠉⠁⠀⢠⠖⢦⠀⠘⣿⣯⣟⣾⣟⡿⣷⣫⡿⣵⣿⠠⠱⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⣰⢿⣽⠤⠼⣤⡁⠎⡘⢠⡦⡟⣧⣽⠞⠫⠂⠀⡀⠒⠀⠈⠑⢅⢀⠘⡸⣷⣭⢾⣽⣻⣞⣏⣟⡷⢃⠂⠀⠈⢣⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⣼⡿⠋⡇⠀⠀⠀⠙⣧⡞⡯⢵⣻⠞⠁⠊⠀⢀⣤⣶⡾⣟⣿⢷⣶⣤⣀⠈⠢⠙⡛⠾⠷⠿⠚⡋⠁⠊⠀⣀⣀⣈⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠻⢤⡡⢨⡀⠀⠀⠀⠸⣯⣝⡿⠁⠀⡊⠀⣴⡿⣯⢷⣻⡽⣳⣟⡾⣽⣻⣶⠀⠀⠀⢁⠀⠀⠁⠀⣀⣶⣿⣿⣻⢯⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠙⠳⣔⡀⠀⠀⠀⣷⠏⠀⣠⡘⠀⣾⡿⣽⡽⣛⣳⣟⣷⣻⣽⢳⣟⡾⡇⠀⠐⠏⠇⠀⡠⣵⣿⣳⠿⣼⣳⡟⣾⢿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠙⠶⣀⢀⡇⠀⠀⠓⠃⠀⣿⡽⣯⡽⣿⡽⣞⣯⢷⢾⣟⡾⣽⡇⠀⠀⠀⠀⠀⡆⣿⣍⣿⣻⢧⡾⣽⡿⣞⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠈⠙⡏⠃⠦⣀⡀⠄⠘⢿⣧⣼⢷⣻⣟⣾⢻⣉⣹⣷⠟⠀⢀⠴⡄⠀⠀⢁⣿⡽⡞⣷⢿⣛⣷⣻⢽⡾⢷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⢸⠆⡴⢦⣑⠉⠓⢦⡀⠙⠛⠿⢧⣿⡾⠯⠟⠋⠁⠀⠀⠈⠗⠁⠠⢄⠀⠪⠻⣷⣯⣟⡽⣶⢯⡿⣤⣼⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⢸⢸⡀⠀⠈⠓⡎⡀⠙⠒⢄⡠⠐⠀⠀⠀⠀⠀⠀⠀⢁⣨⣤⣶⡶⣶⢦⣤⣀⠑⠈⠹⠛⠛⠛⠉⠩⠄⠈⢣⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠸⣆⡇⠀⠀⠀⣧⠟⡇⠇⡠⢬⠙⠒⠤⣀⠀⠀⢁⣴⡿⣯⡷⣯⣽⢿⣯⣻⣽⢿⣦⠀⠀⠀⢰⡲⠀⠀⠀⠈⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⡇⣸⡄⢀⣄⡀⠀⠐⢿⣯⣽⣳⠿⣧⣟⣻⣶⣻⣞⠿⣞⣧⠀⠀⠀⠀⠀⠘⠓⠀⢈⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡋⢀⡇⠙⠤⠜⠀⠈⢳⠀⣀⠈⠳⢯⣟⣷⣻⢷⣫⣶⣯⢿⡽⣾⠆⠀⠀⠀⡐⡁⢁⣴⡿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡜⡁⢸⠇⠀⠀⠀⠀⠀⡞⢸⠁⠉⠲⢄⡈⠳⢯⣟⡏⢱⣟⡾⣽⡿⡀⢀⢤⡰⠀⢰⣿⢯⣟⣳⠿⣆⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠇⢸⠀⠀⠀⠀⠀⣸⢁⡼⠀⠀⠀⠀⠙⣦⣠⡎⠻⢿⣽⣽⠞⠑⠁⠀⠉⢀⡆⢺⡿⣾⡝⣯⣟⡿⣆⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⠴⠃⠀⠀⠀⠀⠀⠹⡴⠇⠀⠀⠀⠀⠀⠻⠏⡇⡖⠦⣌⡁⡁⣀⠀⠀⠀⠀⠀⠹⢟⣷⣹⢯⣟⣽⢿⡄⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⢧⠃⠀⠈⢙⡆⢎⣁⡂⠀⡀⠀⠀⠈⢛⠯⣿⣮⣟⣽⣷⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣾⠀⠀⠀⠸⣄⡼⠁⠙⢶⠈⠳⠄⢀⡀⠀⠐⣠⠭⡉⠂⢳⡀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡎⢰⠑⠲⢄⡙⠂⠀⠑⠚⠁⠀⠀⠹⡄⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠀⢸⠀⠀⠀⠙⢶⡀⠀⠢⣄⡀⠀⠀⠑⣄⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠃⣸⠀⠀⠀⠀⠀⠙⡎⢐⡀⢝⠢⡀⠀⢸⡀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⠏⠁⠀⠀⠀⠀⠀⠀⣷⡏⠹⢆⡀⠉⠷⠆⣷
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠙⢦⡀⡤⠏
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⡁⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡇⡇⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠁⠀
// Credit: emojicombos.com (ASCII art collection, author unknown)
test "Custom delimiter semicolon" {
    const input = std.Io.Reader.fixed("a;byte;c\n");

    var parser = Parser(@TypeOf(input)).init(input, .{
        .delimiter = ';',
    });

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 3), row.fields.len);
    try testing.expectEqualStrings("a", row.fields[0]);
    try testing.expectEqualStrings("byte", row.fields[1]);
    try testing.expectEqualStrings("c", row.fields[2]);
}

// Test that a custom record delimiter can be configured and parsed correctly.
test "Custom record delimiter" {
    const input = std.Io.Reader.fixed("a,byte,c|1,2,3|");

    var parser = Parser(@TypeOf(input)).init(input, .{
        .record_delimiter = '|',
    });

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row1 = (try parser.next(&line_buf, &field_buf)).?;
    try testing.expectEqualStrings("a", row1.fields[0]);

    const row2 = (try parser.next(&line_buf, &field_buf)).?;
    try testing.expectEqualStrings("1", row2.fields[0]);

    const row3 = try parser.next(&line_buf, &field_buf);
    try testing.expect(row3 == null);
}

// Test that a line ending with a carriage return is handled correctly, which is common in CRLF line endings.
test "Single field row" {
    const input = std.Io.Reader.fixed("hello\r\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 1), row.fields.len);
    try testing.expectEqualStrings("hello", row.fields[0]);
}

// Test that an empty row is parsed as a single empty field, which is consistent with how CSV parsers typically handle this case.
test "Empty row" {
    const input = std.Io.Reader.fixed("\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 1), row.fields.len);
    try testing.expectEqualStrings("", row.fields[0]);
}

// Test that the last row of input is parsed correctly even if it doesn't end with a newline, which is a common edge case in CSV parsing.
test "Last row without newline" {
    const input = std.Io.Reader.fixed("a,byte,c");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 3), row.fields.len);
    try testing.expectEqualStrings("a", row.fields[0]);
    try testing.expectEqualStrings("byte", row.fields[1]);
    try testing.expectEqualStrings("c", row.fields[2]);

    try testing.expect((try parser.next(&line_buf, &field_buf)) == null);
}

// Test that if the number of fields exceeds the provided buffer, an error is returned instead of overflowing.
test "Too many fields returns error" {
    const input = std.Io.Reader.fixed("a,byte,c,d\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [2][]const u8 = undefined;

    try testing.expectError(
        error.TooManyFields,
        parser.next(&line_buf, &field_buf),
    );
}

// Test that if a line exceeds the provided buffer, an error is returned instead of overflowing.
test "Line too long returns error" {
    const input = std.Io.Reader.fixed("abcdef\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [3]u8 = undefined;
    var field_buf: [8][]const u8 = undefined;

    try testing.expectError(
        error.LineTooLong,
        parser.next(&line_buf, &field_buf),
    );
}

// Test that a line ending with CRLF is handled correctly, ensuring that the carriage return is trimmed from
// the last field, which is important for compatibility with files created on Windows.
test "CRLF line ending trims carriage return" {
    const input = std.Io.Reader.fixed("a,byte,c\r\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqualStrings("c", row.fields[2]);
}
