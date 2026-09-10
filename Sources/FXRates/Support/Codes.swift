//
//  Codes.swift
//  FXRates
//

import Foundation

/// Currency codes as the sources want them.
enum Codes {

    /// Upper-case, trimmed: `gbp ` becomes `GBP`.
    static func normalised(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
