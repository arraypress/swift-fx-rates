//
//  Parsed.swift
//  FXRates
//

import Foundation

/// A table, and the converted amounts the source itself worked out when it did.
///
/// Internal: the public shape is ``RateTable`` and ``ConversionBatch``; this
/// carries Frankfurter's server-side figures from the parser to the assembly
/// so they are reported rather than re-multiplied.
struct Parsed {
    let table: RateTable

    /// Frankfurter's own converted figures, keyed by quote, when an amount was sent.
    let converted: [String: Decimal]?
}
