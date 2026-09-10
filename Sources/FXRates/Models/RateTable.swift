//
//  RateTable.swift
//  FXRates
//

import Foundation

/// The rates published for one base currency on one day.
public struct RateTable: Sendable, Hashable, Codable {

    /// Where the table came from.
    public let source: Source

    /// The currency the rates are quoted against, upper-case.
    public let base: String

    /// The day that was asked for, as `YYYY-MM-DD`, or nil for "latest".
    public let requestedDay: String?

    /// The day the rates were actually published, as `YYYY-MM-DD`.
    ///
    /// Not always the day asked for: the ECB does not publish at weekends or
    /// on its holidays, so a Sunday comes back as the preceding Friday. On a
    /// royalty conversion, using a different day's rate than the one recorded
    /// against a payment is real money, which is why this is a field and not
    /// a footnote.
    public let publishedOn: String

    /// Whether `publishedOn` is the day that was asked for. Always true for
    /// "latest", since nothing was asked for.
    public let isExactDate: Bool

    /// Units of each quote currency per unit of `base`, keyed by upper-case code.
    public let rates: [String: Decimal]

    /// Currencies that were asked for and the source does not carry.
    public let missing: [String]

    public init(
        source: Source, base: String, requestedDay: String?, publishedOn: String,
        isExactDate: Bool, rates: [String: Decimal], missing: [String]
    ) {
        self.source = source
        self.base = base
        self.requestedDay = requestedDay
        self.publishedOn = publishedOn
        self.isExactDate = isExactDate
        self.rates = rates
        self.missing = missing
    }
}
