//
//  Conversion.swift
//  FXRates
//

import Foundation

/// An amount of one currency in another, at a rate on a day.
public struct Conversion: Sendable, Hashable, Codable {

    /// Where the rate came from.
    public let source: Source

    /// The currency converted from, upper-case.
    public let base: String

    /// The currency converted to, upper-case.
    public let quote: String

    /// Units of `quote` per unit of `base`.
    public let rate: Decimal

    /// The amount of `base` that was converted.
    public let amount: Decimal

    /// What it comes to in `quote`.
    public let converted: Decimal

    /// The day asked for, or nil for "latest".
    public let requestedDay: String?

    /// The day the rate was published — see ``RateTable/publishedOn``.
    public let publishedOn: String

    /// Whether the published day is the day asked for.
    public let isExactDate: Bool

    /// A conversion assembled by the package, or by a test.
    public init(
        source: Source, base: String, quote: String, rate: Decimal, amount: Decimal,
        converted: Decimal, requestedDay: String?, publishedOn: String, isExactDate: Bool
    ) {
        self.source = source
        self.base = base
        self.quote = quote
        self.rate = rate
        self.amount = amount
        self.converted = converted
        self.requestedDay = requestedDay
        self.publishedOn = publishedOn
        self.isExactDate = isExactDate
    }
}
