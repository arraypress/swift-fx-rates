//
//  Parsing.swift
//  FXRates
//
//  The two sources' payloads into one table.
//

import Foundation

/// Decoders for what the sources actually send, fed from recordings in tests.
enum Parsing {

    /// Frankfurter: `{"amount":1.0,"base":"EUR","date":"2026-09-09","rates":{"GBP":0.85898}}`.
    ///
    /// When an `amount` was sent, `rates` holds converted amounts, not rates;
    /// the rate is derived back so the table always means the same thing.
    static func ecbTable(from data: Data, base: String, requestedDay: String?, symbols: [String]?, amount: Decimal?) throws -> Parsed {
        struct Payload: Decodable { let date: String; let rates: [String: Decimal] }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw FXRatesError.decoding("The rates")
        }
        var rates: [String: Decimal] = [:]
        var converted: [String: Decimal] = [:]
        for (code, value) in payload.rates {
            let key = Codes.normalised(code)
            if let amount {
                rates[key] = Numbers.rate(amount: amount, converted: value)
                converted[key] = value
            } else {
                rates[key] = value
            }
        }
        return Parsed(
            table: table(source: .ecb, base: base, requestedDay: requestedDay, publishedOn: payload.date, rates: rates, symbols: symbols),
            converted: amount == nil ? nil : converted
        )
    }

    /// The wide set: `{"date":"2026-09-10","eur":{"gbp":0.85854724,…}}`, one
    /// object per base, keyed in lower case.
    static func wideTable(from data: Data, base: String, requestedDay: String?, symbols: [String]?) throws -> Parsed {
        // Decoded with a keyed container rather than JSONSerialization, which
        // hands numbers back as doubles and would turn 0.85854724 into
        // 0.85854723999999995; `Decimal` through `Decodable` keeps the digits.
        struct Payload: Decodable {
            let date: String
            let tables: [String: [String: Decimal]]
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Key.self)
                var tables: [String: [String: Decimal]] = [:]
                var date = ""
                for key in container.allKeys {
                    if key.stringValue == "date" {
                        date = try container.decode(String.self, forKey: key)
                    } else if let table = try? container.decode([String: Decimal].self, forKey: key) {
                        tables[key.stringValue] = table
                    }
                }
                self.date = date
                self.tables = tables
            }
            struct Key: CodingKey {
                let stringValue: String
                init?(stringValue: String) { self.stringValue = stringValue }
                var intValue: Int? { nil }
                init?(intValue: Int) { nil }
            }
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let raw = payload.tables[base.lowercased()] else {
            throw FXRatesError.decoding("The rates")
        }
        guard !payload.date.isEmpty else { throw FXRatesError.decoding("The rates") }
        var rates: [String: Decimal] = [:]
        for (code, value) in raw { rates[Codes.normalised(code)] = value }
        return Parsed(
            table: table(source: .wide, base: base, requestedDay: requestedDay, publishedOn: payload.date, rates: rates, symbols: symbols),
            converted: nil
        )
    }

    /// `{"AUD":"Australian Dollar",…}` from either source, sorted by code.
    static func currencies(from data: Data) throws -> [Currency] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw FXRatesError.decoding("The currency list")
        }
        return object.keys.sorted().map { Currency(code: Codes.normalised($0), name: object[$0] ?? "") }
    }

    /// Keeps only the symbols asked for, and names the ones that were not there.
    private static func table(
        source: Source, base: String, requestedDay: String?, publishedOn: String,
        rates: [String: Decimal], symbols: [String]?
    ) -> RateTable {
        var kept = rates
        var missing: [String] = []
        if let symbols, !symbols.isEmpty {
            kept = [:]
            for symbol in symbols {
                if let rate = rates[symbol] { kept[symbol] = rate } else { missing.append(symbol) }
            }
        }
        return RateTable(
            source: source, base: base, requestedDay: requestedDay, publishedOn: publishedOn,
            isExactDate: requestedDay == nil || requestedDay == publishedOn,
            rates: kept, missing: missing
        )
    }
}
