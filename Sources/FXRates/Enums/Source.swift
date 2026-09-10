//
//  Source.swift
//  FXRates
//

import Foundation

/// Where a rate comes from. Two sources, because they answer different questions.
public enum Source: String, CaseIterable, Sendable, Codable {

    /// European Central Bank reference rates, via Frankfurter.
    ///
    /// Thirty currencies, working days only, published daily at about 16:00
    /// CET, back to 1999. The citable one: an accountant or a tax authority
    /// will accept an ECB reference rate for a conversion, which is the whole
    /// reason to prefer a narrower source for money that ends up in a return.
    case ecb

    /// A community-maintained set of about 340 currencies including crypto.
    ///
    /// Published as dated package versions and served from a CDN, so there is
    /// no key and no rate limit; available at weekends, back to 2024. Broader,
    /// but not an official rate — fine for what something roughly costs, not
    /// for a figure that has to be defended.
    case wide

    /// What the rate is, in words a report can print: `ECB reference rate`.
    public var describedAs: String {
        switch self {
        case .ecb: "ECB reference rate"
        case .wide: "community aggregate"
        }
    }
}
