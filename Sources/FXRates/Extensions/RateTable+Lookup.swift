//
//  RateTable+Lookup.swift
//  FXRates
//

import Foundation

extension RateTable {

    /// The rate for a quote currency, however its code was cased.
    public func rate(for quote: String) -> Decimal? {
        rates[Codes.normalised(quote)]
    }

    /// Whether the rate is from a different day than the one asked for.
    public var wasSubstituted: Bool { requestedDay != nil && !isExactDate }
}
