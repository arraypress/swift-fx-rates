//
//  URLSessionTransport.swift
//  FXRates
//

import Foundation

/// The default transport: `URLSession.shared` with a User-Agent that names
/// this package, because both sources ask that clients identify themselves.
public struct URLSessionTransport: Transport {

    /// The header every request carries.
    public static let userAgent = "swift-fx-rates (https://github.com/arraypress/swift-fx-rates)"

    /// The shared session, with the package User-Agent.
    public init() {}

    /// One GET through `URLSession.shared`; a non-2xx status is returned, not thrown.
    public func get(_ url: URL, timeout: TimeInterval) async throws -> TransportResponse {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        return TransportResponse(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data)
    }
}
