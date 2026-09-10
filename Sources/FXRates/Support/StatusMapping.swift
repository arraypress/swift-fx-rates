//
//  StatusMapping.swift
//  FXRates
//
//  An HTTP status into the one thing it means here.
//

import Foundation

/// From a response to its body, or to the error the status stands for.
enum StatusMapping {

    /// The body of a 200; otherwise the error.
    static func body(of response: TransportResponse, subject: String, dated: Bool, source: Source) throws -> Data {
        switch response.status {
        case 200: return response.body
        case 404: throw FXRatesError.noData(subject, dated: dated, source: source)
        case 429: throw FXRatesError.rateLimited
        default: throw FXRatesError.upstream("the rate source returned \(response.status)")
        }
    }

    /// A connection failure in a sentence, without the `NSError` furniture.
    ///
    /// `localizedDescription` is the sentence when the error carries one;
    /// a Swift error wrapped by URLSession sometimes only has it inside its
    /// `description`, so that is read as a fallback, stopping at the comma or
    /// brace that closes the entry.
    static func readable(_ error: Error) -> String {
        let localized = (error as NSError).localizedDescription
        if !localized.isEmpty, !localized.hasPrefix("The operation couldn") { return localized }
        let message = String(describing: error)
        if let range = message.range(of: "NSLocalizedDescription=") {
            let sentence = message[range.upperBound...].prefix { $0 != "," && $0 != "}" }
            if !sentence.isEmpty { return String(sentence).trimmingCharacters(in: .whitespaces) }
        }
        return localized
    }
}
