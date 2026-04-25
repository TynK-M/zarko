![zig](https://img.shields.io/badge/Zig-0.16-orange)
![version](https://img.shields.io/badge/version-0.0.2-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-greem.svg)](https://opensource.org/licenses/MIT)
![repo size](https://img.shields.io/github/repo-size/TynK-M/zarko)

# zarko

zarko is a structured text parsing library for Zig. It focuses on CSV, TSV and other delimited formats, providing a clear API, predictable behavior and room to grow into a broader toolkit for working with tabular text data.

zarko aims to be simple to integrate, easy to reason about and flexible enough to handle real world input. It is designed with correctness, testability and transparency in mind.

## Features

- Parsing for CSV, TSV and custom delimited formats  
- Configurable delimiters, quoting and escaping rules  
- Streaming and buffered parsing  
- Row by row iteration  
- Zero hidden allocations  
- Clear and predictable error handling  
- Small and focused API surface  

## Goals

zarko is intended to be a reliable foundation for applications that need to read or process structured text. The long term goal is to support multiple dialects, handle edge cases consistently and provide a set of tools that make working with tabular data straightforward in Zig.

## Non goals

zarko does not aim to be a full data analysis framework or a replacement for higher level tools. It focuses on parsing and representing structured text cleanly and efficiently.

## Installation

Add zarko as a git dependency.

```zig
.{
    .name = "your_project",
    .version = "0.0.2",
    .dependencies = .{
        .zarko = .{
            .url = "https://github.com/TynK-M/zarko",
        },
    },
}
```

## Status

zarko is in early development. The API may change as the library evolves and gains support for more formats and edge cases.

## License

This project includes a [LICENSE](LICENSE) file. Please refer to it for license terms.
