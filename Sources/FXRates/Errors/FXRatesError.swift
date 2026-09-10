//
//  FXRatesError.swift
//  FXRates
//

import Foundation

/// What went wrong, in words a caller can print unchanged.
public enum FXRatesError: Error, LocalizedError, Equatable, Sendable {

    /// The source answered 404: no such currency, or a date outside its series.
    ///
    /// Both sources answer the same way for both mistakes, so `dated` says
    /// which repair to suggest — a hint pointing at the wrong fix costs more
    /// than no hint.
    case noData(String, dated: Bool, source: Source)

    /// The source carries none of the quotes asked for.
    case missingRates(base: String, quotes: [String], source: Source)

    /// The source is throttling requests.
    case rateLimited

    /// The source or the network failed: a status outside 2xx, a timeout, DNS.
    case upstream(String)

    /// The source answered, but not in the shape it answered yesterday.
    case decoding(String)

    /// Not a calendar day written `YYYY-MM-DD`.
    case badDate(String)

    /// A negative or non-finite amount.
    case badAmount(Decimal)

    public var errorDescription: String? {
        switch self {
        case .noData(let subject, let dated, let source):
            let repair = dated
                ? "check the currency exists and that the date is not before the series begins"
                : "no such currency on this source"
            return "No data for \(subject) (\(source.rawValue)): \(repair)"
        case .missingRates(let base, let quotes, let source):
            return "No \(source.rawValue) rate for \(base) to \(quotes.joined(separator: ", "))"
        case .rateLimited:
            return "The rate source is throttling us; try again shortly"
        case .upstream(let message):
            return "The rate source could not be read: \(message)"
        case .decoding(let what):
            return "\(what) was not in the expected shape"
        case .badDate(let text):
            return "not a date: \(text.isEmpty ? "(empty)" : text)\nwrite it as YYYY-MM-DD"
        case .badAmount(let amount):
            return "not an amount to convert: \(amount)\nuse zero or more; a refund is a positive amount the other way"
        }
    }
}
