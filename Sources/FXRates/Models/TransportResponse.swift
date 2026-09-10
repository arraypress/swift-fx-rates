//
//  TransportResponse.swift
//  FXRates
//

import Foundation

/// What came back: the status and the bytes.
public struct TransportResponse: Sendable, Hashable {

    /// The HTTP status, or 0 when there was no HTTP response.
    public let status: Int

    /// The body, possibly empty.
    public let body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}
