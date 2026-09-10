//
//  FXRates.swift
//  FXRates
//
//  The namespace: what a currency was worth, today or on the day it mattered.
//

import Foundation

/// Exchange rates, current and historical, from two open sources.
///
/// The date is the point. A distributor remitted in dollars on the last day
/// of July, and the statement has to say what that was in sterling on that
/// day — not today. The European Central Bank publishes a reference rate
/// every working day, and that is the figure an accountant or a tax
/// authority will accept; a community-maintained set covers ten times as many
/// currencies, including crypto, and publishes at weekends, but is not an
/// official rate. Both are keyless. ``Source`` says which you asked for and
/// every result says which you got.
///
/// Money is `Decimal` throughout: a rate read from the wire keeps exactly the
/// digits it was published with, and an amount multiplied by it does not grow
/// a `0.30000000000000004`.
public enum FXRates {

    /// The transport every request goes through. Replace it in tests with one
    /// that answers from recordings, so nothing here needs the network to be
    /// proven right.
    public nonisolated(unsafe) static var transport: any Transport = URLSessionTransport()

    /// Seconds to wait for a source before giving up.
    public nonisolated(unsafe) static var timeout: TimeInterval = 15

    // MARK: Rates

    /// The latest published rates for `base`, for every currency the source
    /// carries or only `symbols`.
    ///
    /// - Throws: ``FXRatesError`` — `noData` when the source has no such
    ///   currency, `upstream`/`rateLimited` for a failing source, `decoding`
    ///   when the payload is not the shape it was yesterday.
    public static func latest(
        base: String = "EUR", symbols: [String]? = nil, source: Source = .ecb
    ) async throws -> RateTable {
        try await fetch(base: base, symbols: symbols, day: nil, amount: nil, source: source).table
    }

    /// The rates published for the calendar day containing `date`, read in UTC.
    ///
    /// The ECB publishes on working days only, so a Saturday, a Sunday or one
    /// of its holidays comes back as the preceding working day's table. The
    /// substitution is silent in the API; here ``RateTable/publishedOn`` says
    /// which day was used and ``RateTable/isExactDate`` says whether it was
    /// the one asked for. The wide source publishes every day.
    ///
    /// - Throws: ``FXRatesError/noData(_:dated:source:)`` for a date before
    ///   the series begins or after the last publication.
    public static func rates(
        on date: Date, base: String = "EUR", symbols: [String]? = nil, source: Source = .ecb
    ) async throws -> RateTable {
        try await rates(onDay: Dates.day(from: date), base: base, symbols: symbols, source: source)
    }

    /// The same, for a day written as `YYYY-MM-DD` — the form callers usually
    /// already hold.
    ///
    /// - Throws: ``FXRatesError/badDate(_:)`` when the text is not a calendar date.
    public static func rates(
        onDay day: String, base: String = "EUR", symbols: [String]? = nil, source: Source = .ecb
    ) async throws -> RateTable {
        guard Dates.isCalendarDate(day) else { throw FXRatesError.badDate(day) }
        return try await fetch(base: base, symbols: symbols, day: day, amount: nil, source: source).table
    }

    /// Every currency the source knows, sorted by code.
    public static func currencies(source: Source = .ecb) async throws -> [Currency] {
        let response: TransportResponse
        do {
            response = try await transport.get(Endpoints.currencies(source: source), timeout: timeout)
        } catch {
            throw FXRatesError.upstream(StatusMapping.readable(error))
        }
        let body = try StatusMapping.body(of: response, subject: "the currency list", dated: false, source: source)
        return try Parsing.currencies(from: body)
    }

    // MARK: Conversion

    /// `amount` of `base` in `quote`, at today's rate or the rate on a day.
    ///
    /// - Throws: ``FXRatesError/missingRates(base:quotes:source:)`` when the
    ///   source has no rate for the pair; ``FXRatesError/badAmount(_:)`` for a
    ///   negative amount — a refund is a positive amount the other way.
    public static func convert(
        _ amount: Decimal, from base: String, to quote: String,
        on date: Date? = nil, source: Source = .ecb
    ) async throws -> Conversion {
        let batch = try await convert(amount, from: base, to: [quote], onDay: date.map(Dates.day(from:)), source: source)
        guard let first = batch.conversions.first else {
            throw FXRatesError.missingRates(base: Codes.normalised(base), quotes: [Codes.normalised(quote)], source: source)
        }
        return first
    }

    /// `amount` of `base` in each of `quotes`, from one request.
    ///
    /// Quotes the source does not carry are listed in
    /// ``ConversionBatch/missing`` rather than thrown, so asking for four
    /// currencies and getting three tells you which one is absent. Only when
    /// none of them exist is it an error.
    ///
    /// On the ECB source the amount is sent to Frankfurter, which multiplies
    /// server-side and rounds the result the way its published tables do, and
    /// the rate is derived back from that figure; that keeps the converted
    /// amount identical to the one the source itself would show. The wide
    /// source publishes rates only, so the multiplication is done here, in
    /// `Decimal`.
    public static func convert(
        _ amount: Decimal, from base: String, to quotes: [String],
        onDay day: String? = nil, source: Source = .ecb
    ) async throws -> ConversionBatch {
        guard amount >= 0, amount.isFinite else { throw FXRatesError.badAmount(amount) }
        if let day, !Dates.isCalendarDate(day) { throw FXRatesError.badDate(day) }
        let parsed = try await fetch(base: base, symbols: quotes, day: day, amount: amount, source: source)
        return Assembly.batch(from: parsed, amount: amount, quotes: quotes.map(Codes.normalised))
    }

    // MARK: The one fetch

    private static func fetch(
        base: String, symbols: [String]?, day: String?, amount: Decimal?, source: Source
    ) async throws -> Parsed {
        let base = Codes.normalised(base)
        let symbols = symbols?.map(Codes.normalised)
        let url = Endpoints.rates(source: source, base: base, symbols: symbols, day: day, amount: amount)
        let response: TransportResponse
        do {
            response = try await transport.get(url, timeout: timeout)
        } catch {
            throw FXRatesError.upstream(StatusMapping.readable(error))
        }
        let body = try StatusMapping.body(of: response, subject: "\(base) rates", dated: day != nil, source: source)
        let parsed: Parsed
        switch source {
        case .ecb: parsed = try Parsing.ecbTable(from: body, base: base, requestedDay: day, symbols: symbols, amount: amount)
        case .wide: parsed = try Parsing.wideTable(from: body, base: base, requestedDay: day, symbols: symbols)
        }
        if let symbols, !symbols.isEmpty, parsed.table.rates.isEmpty {
            throw FXRatesError.missingRates(base: base, quotes: symbols, source: source)
        }
        return parsed
    }
}
