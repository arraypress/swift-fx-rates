//
//  ConversionBatch.swift
//  FXRates
//

import Foundation

/// Several conversions from one request, and the quotes that had no rate.
public struct ConversionBatch: Sendable, Hashable, Codable {

    /// One per quote the source carried, in the order asked.
    public let conversions: [Conversion]

    /// The quotes asked for that the source does not carry.
    public let missing: [String]

    /// A batch as the package assembled it.
    public init(conversions: [Conversion], missing: [String]) {
        self.conversions = conversions
        self.missing = missing
    }
}
