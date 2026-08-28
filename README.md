# Zarko

A CSV parsing library for Zig.

Zarko provides a simple way to parse CSV data while supporting configurable dialects, records, quoting, and line endings.

______________________________________________________________________

## Features

- Parse CSV data from memory
- Support quoted fields
- Handle escaped quotes
- Borrow field data directly from the input when possible
- Configure CSV dialect options
  - Field separators
  - Quote characters
  - Line endings

______________________________________________________________________

## Usage

Import Zarko and create a parser with your CSV input.

```zig
const csv =
        \\name,age,city
        \\Matteo,22,Rome
        \\Linus,56,Helsinki
        \\Ada,"36",London
        \\QuoteTest,"312","Hello, ""World!"""
    ;

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();

    var parser = zarko.Parser.init(arena.allocator(), csv, .{});

    while (try parser.next()) |record| {
        for (record.fields) |field| {
            std.debug.print("{s} ", .{field});
        }
        std.debug.print("\n", .{});
    }
```

Quoted fields are unwrapped and escaped quotes are unescaped:

```text
"Hello, ""World!"""
```

becomes:

```text
Hello, "World!"
```

______________________________________________________________________

## Records and Memory Management

Zarko does not own the input CSV data. The input slice must remain valid as long as any parser record contains fields borrowed from it.

Each parsed `Record` owns its field slice and any field data that had to be allocated while parsing, such as fields containing escaped quotes.

Records must be deinitialized when they are no longer needed:

```zig
var record = (try parser.next()).?;
defer record.deinit(allocator);
```

Fields that do not require allocation borrow directly from the input. Fields that require quote unescaping are allocated using the allocator provided to the parser and are owned by the corresponding `Record`.

```zig
var first = (try parser.next()).?;
defer first.deinit(allocator);

var second = (try parser.next()).?;
defer second.deinit(allocator);
```

The parser does not own previously returned records.

______________________________________________________________________

## Dialects

CSV formats are not always identical. Zarko allows customizing parsing rules through `Dialect`.

```zig
const dialect = zarko.Dialect{
    .separator = ';',
    .quote = '"',
    .line_ending = .lf,
};
```

For example, this can be used to parse semicolon-separated data:

```text
name;age;city
Matteo;22;Rome
```

______________________________________________________________________

## Installation

Add Zarko as a dependency in your `build.zig.zon`:

```zig
.dependencies = .{
    .zarko = .{
        .url = "https://github.com/TynK-M/zarko/archive/HEAD.tar.gz",
    },
},
```

Then import it in your Zig code:

```zig
const zarko = @import("zarko");
```

______________________________________________________________________

## License

See the [MIT License](LICENSE) for details.
