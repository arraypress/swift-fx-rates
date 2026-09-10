//
//  Currency.swift
//  FXRates
//

import Foundation

/// One currency a source knows about.
public struct Currency: Sendable, Hashable, Codable {

    /// The ISO 4217 code, or the community code for crypto, upper-case.
    public let code: String

    /// The name as the source writes it: `British Pound`.
    public let name: String

    /// A currency by code and name.
    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}
