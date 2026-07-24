# Zarko

A CSV parsing library for Zig.

Zarko provides a simple way to parse CSV data while supporting configurable dialects, records, quoting, and line endings.

______________________________________________________________________

## Features

- Parse CSV data from memory
- Support quoted fields
- Handle escaped quotes
- Configure CSV dialect options
  - Field separators
  - Quote characters
  - Line endings

______________________________________________________________________

## Usage

Import Zarko and create a parser with your CSV input, like it's done in the `main.zig` example.

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

______________________________________________________________________

## Memory Management

Zarko does not own the input CSV data. The input slice must remain valid while parsing.

Parsed records use the allocator provided when creating the parser.

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
