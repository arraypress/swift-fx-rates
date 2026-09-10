//
//  Conversion+Substitution.swift
//  FXRates
//

import Foundation

extension Conversion {

    /// Whether the rate is from a different day than the one asked for.
    ///
    /// False for "latest": nothing was asked for, so nothing was substituted.
    public var wasSubstituted: Bool { requestedDay != nil && !isExactDate }
}
