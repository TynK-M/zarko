const std = @import("std");

pub const Config = @import("config.zig").Config;
pub const Row = @import("row.zig").Row;

/// Creates a zero-allocation CSV parser specialized for `ReaderType`.
///
/// `ReaderType` must provide:
/// - `takeByte() !?u8`
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

        /// Input source.
        reader: ReaderType,

        /// Parser options.
        config: Config,

        /// Creates a parser.
        pub fn init(reader: ReaderType, config: Config) Self {
            return .{
                .reader = reader,
                .config = config,
            };
        }

        /// Reads the next CSV row, returning null on end of input.
        ///
        /// Returns:
        /// - `Row`: on success.
        /// - `null`: if end of input (EOF) is reached before reading any data.
        /// - `error.TooManyFields`: if the number of fields exceeds the provided buffer.
        pub fn next(
            self: *Self,
            line_buf: []u8,
            fields_buf: [][]const u8,
        ) !?Row {
            const len = try readLine(
                self,
                line_buf,
                self.config.record_delimiter,
            );

            if (len == null) return null;

            var raw = line_buf[0..len.?];
            if (raw.len > 0 and raw[raw.len - 1] == '\r') {
                raw = raw[0 .. raw.len - 1];
            }

            var count: usize = 0;
            var start: usize = 0;
            var i: usize = 0;
            while (i <= raw.len) : (i += 1) {
                if ((i == raw.len) or (!(i == raw.len) and raw[i] == self.config.delimiter)) {
                    if (count >= fields_buf.len)
                        return error.TooManyFields;

                    fields_buf[count] = raw[start..i];
                    count += 1;
                    start = i + 1;
                }
            }

            return Row{
                .fields = fields_buf[0..count],
            };
        }

        /// Reads a line from the reader into the buffer, stopping at the delimiter.
        ///
        /// Returns:
        /// - `usize`: the number of bytes read into the buffer, excluding the delimiter.
        /// - `null`: if end of input (EOF) is reached before reading any data.
        /// - `error.LineTooLong`: if the line exceeds the buffer size.
        ///
        /// Note: The buffer is not null-terminated, and the caller should use the returned length to determine the valid portion of the buffer.
        fn readLine(
            self: *Self,
            buf: []u8,
            delimiter: u8,
        ) !?usize {
            var i: usize = 0;
            while (true) {
                const byte = try self.reader.takeByte() orelse {
                    if (i == 0) return null;
                    return i;
                };

                if (byte == delimiter) return i;
                if (i >= buf.len) return error.LineTooLong;

                buf[i] = byte;
                i += 1;
            }
        }
    };
}

// Tests
//
// A Reader.fixed() is used as a simple in-memory reader for testing the parser.

const testing = std.testing;

// Test parsing simple CSV rows without allocation.
test "Parse simple CSV rows" {
    const input = std.Io.Reader.fixed("a,b,c\n1,2,3\n");

    var parser = Parser(@TypeOf(input)).init(
        input,
        .{},
    );

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row1 = (try parser.next(&line_buf, &field_buf)).?;
    try testing.expectEqual(@as(usize, 3), row1.fields.len);
    try testing.expectEqualStrings("a", row1.fields[0]);
    try testing.expectEqualStrings("b", row1.fields[1]);
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
    const input = std.Io.Reader.fixed("a,b,\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 3), row.fields.len);
    try testing.expectEqualStrings("a", row.fields[0]);
    try testing.expectEqualStrings("b", row.fields[1]);
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
    const input = std.Io.Reader.fixed("a;b;c\n");

    var parser = Parser(@TypeOf(input)).init(input, .{
        .delimiter = ';',
    });

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 3), row.fields.len);
    try testing.expectEqualStrings("a", row.fields[0]);
    try testing.expectEqualStrings("b", row.fields[1]);
    try testing.expectEqualStrings("c", row.fields[2]);
}

// Test that a custom record delimiter can be configured and parsed correctly.
test "Custom record delimiter" {
    const input = std.Io.Reader.fixed("a,b,c|1,2,3|");

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
    const input = std.Io.Reader.fixed("a,b,c");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqual(@as(usize, 3), row.fields.len);
    try testing.expectEqualStrings("a", row.fields[0]);
    try testing.expectEqualStrings("b", row.fields[1]);
    try testing.expectEqualStrings("c", row.fields[2]);

    try testing.expect((try parser.next(&line_buf, &field_buf)) == null);
}

// Test that if the number of fields exceeds the provided buffer, an error is returned instead of overflowing.
test "Too many fields returns error" {
    const input = std.Io.Reader.fixed("a,b,c,d\n");

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
    const input = std.Io.Reader.fixed("a,b,c\r\n");

    var parser = Parser(@TypeOf(input)).init(input, .{});

    var line_buf: [128]u8 = undefined;
    var field_buf: [16][]const u8 = undefined;

    const row = (try parser.next(&line_buf, &field_buf)).?;

    try testing.expectEqualStrings("c", row.fields[2]);
}
