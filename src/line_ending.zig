//! Defines line ending types used by Zarko.

/// Represents the line ending used by a CSV.
pub const LineEnding = enum {
    /// Line Feed (`\n`).
    lf,

    /// Carriage Return + Line Feed (`\r\n`).
    crlf,

    /// Carriage Return (`\r`)
    cr,
};
