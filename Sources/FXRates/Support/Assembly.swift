//
//  Assembly.swift
//  FXRates
//

import Foundation

/// A table into conversions.
enum Assembly {

    /// One conversion per quote the table carries, in the order asked.
    ///
    /// When the source worked the amount out itself (Frankfurter does, and
    /// rounds the way its tables do) that figure is kept; otherwise it is
    /// `rate × amount` in `Decimal`, which is exact.
    static func batch(from parsed: Parsed, amount: Decimal, quotes: [String]) -> ConversionBatch {
        let table = parsed.table
        let conversions = quotes.compactMap { quote -> Conversion? in
            guard let rate = table.rates[quote] else { return nil }
            return Conversion(
                source: table.source, base: table.base, quote: quote, rate: rate,
                amount: amount, converted: parsed.converted?[quote] ?? rate * amount,
                requestedDay: table.requestedDay, publishedOn: table.publishedOn,
                isExactDate: table.isExactDate
            )
        }
        return ConversionBatch(conversions: conversions, missing: table.missing)
    }
}
