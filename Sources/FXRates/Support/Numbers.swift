//
//  Numbers.swift
//  FXRates
//

import Foundation

/// Decimals on and off the wire.
enum Numbers {

    /// A decimal as plain digits: `2400`, `0.5`, never `2.4e3`.
    static func text(_ value: Decimal) -> String {
        "\(value)"
    }

    /// Units of quote per unit of base, from an amount and what it came to.
    ///
    /// Zero amount has no rate — division by zero is not a rate of zero, but
    /// nothing was converted, so zero is what the caller sees.
    static func rate(amount: Decimal, converted: Decimal) -> Decimal {
        guard amount != 0 else { return 0 }
        return converted / amount
    }
}
