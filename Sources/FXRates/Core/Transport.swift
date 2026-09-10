//
//  Transport.swift
//  FXRates
//

import Foundation

/// One HTTP GET, as a value.
///
/// The only thing in this package that touches the network, so the only thing
/// a test has to replace. A recording of a real response, fed back through
/// this, proves every parser and every error mapping without a socket.
public protocol Transport: Sendable {

    /// Fetches `url`, giving up after `timeout` seconds.
    ///
    /// - Throws: whatever the connection failed with; the caller renders it
    ///   as ``FXRatesError/upstream(_:)``. A non-2xx status is NOT an error
    ///   here — it comes back in the response for the caller to map.
    func get(_ url: URL, timeout: TimeInterval) async throws -> TransportResponse
}
