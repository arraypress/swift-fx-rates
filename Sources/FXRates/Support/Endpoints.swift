//
//  Endpoints.swift
//  FXRates
//
//  Every URL this package asks for, built in one place.
//

import Foundation

/// URL builders, pure so a test can read the exact request.
enum Endpoints {

    /// Frankfurter serves the ECB's tables.
    static let ecbRoot = "https://api.frankfurter.dev/v1"

    /// The wide set is a dated npm package on a CDN — the date is the version,
    /// which is the trick that makes it work without a key or a server.
    static let wideRoot = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api"

    /// The currency list.
    static func currencies(source: Source) -> URL {
        switch source {
        case .ecb: URL(string: "\(ecbRoot)/currencies")!
        case .wide: URL(string: "\(wideRoot)@latest/v1/currencies.min.json")!
        }
    }

    /// A rate table: the latest one, or a day's.
    ///
    /// `amount` is only meaningful to Frankfurter, which multiplies server-side;
    /// the wide source ignores it, so it is not sent there.
    static func rates(source: Source, base: String, symbols: [String]?, day: String?, amount: Decimal?) -> URL {
        switch source {
        case .ecb:
            var components = URLComponents(string: "\(ecbRoot)/\(day ?? "latest")")!
            var items = [URLQueryItem(name: "base", value: base)]
            if let symbols, !symbols.isEmpty {
                items.append(URLQueryItem(name: "symbols", value: symbols.joined(separator: ",")))
            }
            if let amount {
                items.append(URLQueryItem(name: "amount", value: Numbers.text(amount)))
            }
            components.queryItems = items
            return components.url!
        case .wide:
            return URL(string: "\(wideRoot)@\(day ?? "latest")/v1/currencies/\(base.lowercased()).min.json")!
        }
    }
}
