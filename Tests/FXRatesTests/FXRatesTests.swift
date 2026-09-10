//
//  FXRatesTests.swift
//  FXRates
//
//  Every test answers from a recording of what the sources really sent on
//  2026-09-10 (URLs named beside each fixture), so nothing here needs the
//  network — a test that needs the ECB to be up tells you about the ECB.
//

import XCTest
@testable import FXRates

// MARK: - Recordings

/// Real responses, fetched once with curl and kept verbatim. The wide set's
/// tables run to 340 currencies; those two are trimmed to the keys the tests
/// read, with the digits exactly as served.
enum Recorded {
    /// https://api.frankfurter.dev/v1/latest?base=EUR&symbols=GBP,USD
    static let ecbLatest = #"{"amount":1.0,"base":"EUR","date":"2026-09-09","rates":{"GBP":0.85898,"USD":1.1652}}"#
    /// https://api.frankfurter.dev/v1/2026-08-09?base=EUR&symbols=GBP — a Sunday
    static let ecbSunday = #"{"amount":1.0,"base":"EUR","date":"2026-08-07","rates":{"GBP":0.85765}}"#
    /// https://api.frankfurter.dev/v1/2026-07-31?base=USD&symbols=GBP&amount=2400
    static let ecbDatedAmount = #"{"amount":2400.0,"base":"USD","date":"2026-07-31","rates":{"GBP":1788.2}}"#
    /// https://api.frankfurter.dev/v1/currencies
    static let ecbCurrencies = #"{"AUD":"Australian Dollar","BRL":"Brazilian Real","CAD":"Canadian Dollar","CHF":"Swiss Franc","CNY":"Chinese Renminbi Yuan","CZK":"Czech Koruna","DKK":"Danish Krone","EUR":"Euro","GBP":"British Pound","HKD":"Hong Kong Dollar","HUF":"Hungarian Forint","IDR":"Indonesian Rupiah","ILS":"Israeli New Shekel","INR":"Indian Rupee","ISK":"Icelandic Króna","JPY":"Japanese Yen","KRW":"South Korean Won","MXN":"Mexican Peso","MYR":"Malaysian Ringgit","NOK":"Norwegian Krone","NZD":"New Zealand Dollar","PHP":"Philippine Peso","PLN":"Polish Złoty","RON":"Romanian Leu","SEK":"Swedish Krona","SGD":"Singapore Dollar","THB":"Thai Baht","TRY":"Turkish Lira","USD":"United States Dollar","ZAR":"South African Rand"}"#
    /// https://api.frankfurter.dev/v1/latest?base=XXX → 404
    static let notFound = #"{"message":"not found"}"#
    /// https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.min.json (trimmed)
    static let wideLatest = #"{"date":"2026-09-10","eur":{"gbp":0.85854724,"usd":1.16380267,"btc":1.4859864e-05}}"#
    /// https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@2026-08-09/v1/currencies/eur.min.json (trimmed)
    static let wideSunday = #"{"date":"2026-08-09","eur":{"gbp":0.85685628}}"#
    /// https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.min.json (trimmed)
    static let wideCurrencies = #"{"btc":"Bitcoin","eur":"Euro","gbp":"British Pound","usd":"US Dollar"}"#
}

/// A transport that answers from the recordings and remembers what was asked.
final class RecordedTransport: Transport, @unchecked Sendable {
    var answers: [String: TransportResponse] = [:]
    var fallback: TransportResponse?
    var failure: Error?
    private(set) var requested: [URL] = []
    private(set) var timeouts: [TimeInterval] = []

    func answer(_ url: String, status: Int = 200, _ body: String) {
        answers[url] = TransportResponse(status: status, body: Data(body.utf8))
    }

    func get(_ url: URL, timeout: TimeInterval) async throws -> TransportResponse {
        requested.append(url)
        timeouts.append(timeout)
        if let failure { throw failure }
        if let hit = answers[url.absoluteString] { return hit }
        if let fallback { return fallback }
        XCTFail("no recording for \(url.absoluteString)")
        return TransportResponse(status: 0, body: Data())
    }
}

private func decimal(_ text: String) -> Decimal { Decimal(string: text)! }

// MARK: - URLs

final class EndpointTests: XCTestCase {

    func testTheLatestECBTableWithSymbols() {
        XCTAssertEqual(
            Endpoints.rates(source: .ecb, base: "EUR", symbols: ["GBP", "USD"], day: nil, amount: nil).absoluteString,
            "https://api.frankfurter.dev/v1/latest?base=EUR&symbols=GBP,USD"
        )
    }

    func testADatedECBTableWithAnAmount() {
        XCTAssertEqual(
            Endpoints.rates(source: .ecb, base: "USD", symbols: ["GBP"], day: "2026-07-31", amount: 2400).absoluteString,
            "https://api.frankfurter.dev/v1/2026-07-31?base=USD&symbols=GBP&amount=2400"
        )
        XCTAssertEqual(
            Endpoints.rates(source: .ecb, base: "USD", symbols: ["GBP"], day: nil, amount: decimal("12.50")).absoluteString,
            "https://api.frankfurter.dev/v1/latest?base=USD&symbols=GBP&amount=12.5"
        )
    }

    func testNoSymbolsMeansTheWholeTable() {
        XCTAssertEqual(
            Endpoints.rates(source: .ecb, base: "EUR", symbols: nil, day: nil, amount: nil).absoluteString,
            "https://api.frankfurter.dev/v1/latest?base=EUR"
        )
        XCTAssertEqual(
            Endpoints.rates(source: .ecb, base: "EUR", symbols: [], day: nil, amount: nil).absoluteString,
            "https://api.frankfurter.dev/v1/latest?base=EUR"
        )
    }

    func testTheWideSetIsADatedPackageWithALowerCaseBase() {
        XCTAssertEqual(
            Endpoints.rates(source: .wide, base: "EUR", symbols: ["GBP"], day: nil, amount: 5).absoluteString,
            "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.min.json",
            "the amount is not sent: the wide source only publishes rates"
        )
        XCTAssertEqual(
            Endpoints.rates(source: .wide, base: "EUR", symbols: nil, day: "2026-08-09", amount: nil).absoluteString,
            "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@2026-08-09/v1/currencies/eur.min.json"
        )
    }

    func testTheCurrencyLists() {
        XCTAssertEqual(Endpoints.currencies(source: .ecb).absoluteString, "https://api.frankfurter.dev/v1/currencies")
        XCTAssertEqual(
            Endpoints.currencies(source: .wide).absoluteString,
            "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.min.json"
        )
    }
}

// MARK: - Parsing the recordings

final class ParsingTests: XCTestCase {

    func testAnECBTableKeepsTheDigitsItWasPublishedWith() throws {
        let parsed = try Parsing.ecbTable(from: Data(Recorded.ecbLatest.utf8), base: "EUR", requestedDay: nil, symbols: ["GBP", "USD"], amount: nil)
        XCTAssertEqual(parsed.table.rates["GBP"], decimal("0.85898"))
        XCTAssertEqual(parsed.table.rates["USD"], decimal("1.1652"))
        XCTAssertEqual("\(parsed.table.rates["GBP"]!)", "0.85898", "no 0.85897999999999996")
        XCTAssertEqual(parsed.table.publishedOn, "2026-09-09")
        XCTAssertTrue(parsed.table.isExactDate, "nothing was asked for, so nothing was substituted")
        XCTAssertNil(parsed.table.requestedDay)
        XCTAssertNil(parsed.converted)
        XCTAssertEqual(parsed.table.missing, [])
    }

    func testASundayComesBackAsTheFridayAndSaysSo() throws {
        let table = try Parsing.ecbTable(from: Data(Recorded.ecbSunday.utf8), base: "EUR", requestedDay: "2026-08-09", symbols: ["GBP"], amount: nil).table
        XCTAssertEqual(table.publishedOn, "2026-08-07")
        XCTAssertEqual(table.requestedDay, "2026-08-09")
        XCTAssertFalse(table.isExactDate)
        XCTAssertTrue(table.wasSubstituted)
    }

    func testAWorkingDayIsExact() throws {
        let table = try Parsing.ecbTable(from: Data(Recorded.ecbDatedAmount.utf8), base: "USD", requestedDay: "2026-07-31", symbols: ["GBP"], amount: 2400).table
        XCTAssertTrue(table.isExactDate)
        XCTAssertFalse(table.wasSubstituted)
    }

    func testAnAmountSentToFrankfurterIsKeptAndTheRateDerivedBack() throws {
        // Frankfurter multiplies server-side and rounds the way its tables do:
        // 2400 USD came back as 1788.2 GBP. That figure is kept, because it is
        // the one the source itself shows; the rate is what it implies.
        let parsed = try Parsing.ecbTable(from: Data(Recorded.ecbDatedAmount.utf8), base: "USD", requestedDay: "2026-07-31", symbols: ["GBP"], amount: 2400)
        XCTAssertEqual(parsed.converted?["GBP"], decimal("1788.2"))
        XCTAssertEqual(parsed.table.rates["GBP"], decimal("1788.2") / 2400)
        XCTAssertEqual("\(parsed.table.rates["GBP"]!)".prefix(8), "0.745083")
    }

    func testTheWideSetKeepsItsDigitsIncludingExponents() throws {
        let table = try Parsing.wideTable(from: Data(Recorded.wideLatest.utf8), base: "EUR", requestedDay: nil, symbols: nil).table
        XCTAssertEqual(table.rates["GBP"], decimal("0.85854724"))
        XCTAssertEqual(table.rates["USD"], decimal("1.16380267"))
        XCTAssertEqual(table.rates["BTC"], decimal("0.000014859864"), "1.4859864e-05 on the wire")
        XCTAssertEqual(table.publishedOn, "2026-09-10")
        XCTAssertEqual(table.source, .wide)
    }

    func testTheWideSetPublishesOnASunday() throws {
        let table = try Parsing.wideTable(from: Data(Recorded.wideSunday.utf8), base: "EUR", requestedDay: "2026-08-09", symbols: ["GBP"]).table
        XCTAssertEqual(table.publishedOn, "2026-08-09")
        XCTAssertTrue(table.isExactDate)
        XCTAssertEqual(table.rates["GBP"], decimal("0.85685628"))
    }

    func testSymbolsFilterTheTableAndNameWhatIsAbsent() throws {
        let table = try Parsing.wideTable(from: Data(Recorded.wideLatest.utf8), base: "EUR", requestedDay: nil, symbols: ["GBP", "XYZ", "BTC"]).table
        XCTAssertEqual(Set(table.rates.keys), ["GBP", "BTC"])
        XCTAssertEqual(table.missing, ["XYZ"])
    }

    func testTheECBCurrencyListIsThirtySortedByCode() throws {
        let list = try Parsing.currencies(from: Data(Recorded.ecbCurrencies.utf8))
        XCTAssertEqual(list.count, 30)
        XCTAssertEqual(list.first, Currency(code: "AUD", name: "Australian Dollar"))
        XCTAssertEqual(list.map(\.code), list.map(\.code).sorted())
        XCTAssertEqual(list.first { $0.code == "GBP" }?.name, "British Pound")
    }

    func testTheWideCurrencyListUpperCasesItsCodes() throws {
        let list = try Parsing.currencies(from: Data(Recorded.wideCurrencies.utf8))
        XCTAssertEqual(list.map(\.code), ["BTC", "EUR", "GBP", "USD"])
        XCTAssertEqual(list.first?.name, "Bitcoin")
    }

    func testAPayloadInTheWrongShapeIsADecodingError() {
        for bad in ["", "{}", "[]", "not json", #"{"date":"2026-09-09"}"#, #"{"rates":{"GBP":1}}"#] {
            XCTAssertThrowsError(try Parsing.ecbTable(from: Data(bad.utf8), base: "EUR", requestedDay: nil, symbols: nil, amount: nil), bad) { error in
                XCTAssertEqual(error as? FXRatesError, .decoding("The rates"))
            }
        }
        XCTAssertThrowsError(try Parsing.wideTable(from: Data(#"{"date":"2026-09-10","usd":{"gbp":0.7}}"#.utf8), base: "EUR", requestedDay: nil, symbols: nil)) { error in
            XCTAssertEqual(error as? FXRatesError, .decoding("The rates"), "the base's own table is missing")
        }
        XCTAssertThrowsError(try Parsing.currencies(from: Data("[1,2]".utf8))) { error in
            XCTAssertEqual(error as? FXRatesError, .decoding("The currency list"))
        }
    }
}

// MARK: - Codes and days

final class CodesAndDatesTests: XCTestCase {

    func testCodesAreUpperCasedAndTrimmed() {
        XCTAssertEqual(Codes.normalised(" gbp "), "GBP")
        XCTAssertEqual(Codes.normalised("Btc\n"), "BTC")
    }

    func testCalendarDaysAreRecognised() {
        for good in ["2026-07-31", "1999-01-04", "2024-02-29"] {
            XCTAssertTrue(Dates.isCalendarDate(good), good)
        }
        for bad in ["31-07-2026", "2026-7-31", "yesterday", "2026", "2026-13-01", "2026-07-32", "", "1899-12-31", "2026-07-31T00:00"] {
            XCTAssertFalse(Dates.isCalendarDate(bad), bad)
        }
    }

    func testADateBecomesItsUTCDay() {
        // 23:30 UTC on 9 August is still the 9th, whatever the machine's zone.
        let lateOnTheNinth = Date(timeIntervalSince1970: 1_786_318_200)
        XCTAssertEqual(Dates.day(from: lateOnTheNinth), "2026-08-09")
        XCTAssertEqual(Dates.day(from: lateOnTheNinth.addingTimeInterval(1800)), "2026-08-10")
    }

    func testDecimalsGoOnTheWireAsPlainDigits() {
        XCTAssertEqual(Numbers.text(2400), "2400")
        XCTAssertEqual(Numbers.text(decimal("12.50")), "12.5")
        XCTAssertEqual(Numbers.text(decimal("0.0001")), "0.0001")
    }

    func testARateIsDerivedFromAnAmountAndZeroHasNone() {
        XCTAssertEqual(Numbers.rate(amount: 2400, converted: decimal("1788.2")), decimal("1788.2") / 2400)
        XCTAssertEqual(Numbers.rate(amount: 0, converted: 0), 0)
    }
}

// MARK: - Through the front door

final class FXRatesTests: XCTestCase {

    private var transport = RecordedTransport()

    override func setUp() {
        transport = RecordedTransport()
        FXRates.transport = transport
        FXRates.timeout = 15
    }

    override func tearDown() {
        FXRates.transport = URLSessionTransport()
    }

    func testTheLatestRates() async throws {
        transport.answer("https://api.frankfurter.dev/v1/latest?base=EUR&symbols=GBP,USD", Recorded.ecbLatest)
        let table = try await FXRates.latest(base: "eur", symbols: ["gbp", "usd"])
        XCTAssertEqual(table.rate(for: "gbp"), decimal("0.85898"))
        XCTAssertEqual(table.base, "EUR")
        XCTAssertEqual(transport.timeouts, [15])
    }

    func testRatesOnADateAskForItsUTCDay() async throws {
        transport.answer("https://api.frankfurter.dev/v1/2026-08-09?base=EUR&symbols=GBP", Recorded.ecbSunday)
        let sunday = Date(timeIntervalSince1970: 1_786_318_200)   // 2026-08-09T23:30Z
        let table = try await FXRates.rates(on: sunday, base: "EUR", symbols: ["GBP"])
        XCTAssertEqual(table.requestedDay, "2026-08-09")
        XCTAssertEqual(table.publishedOn, "2026-08-07")
        XCTAssertTrue(table.wasSubstituted)
    }

    func testABadDayIsRefusedBeforeAnyRequest() async {
        await XCTAssertThrowsErrorAsync(try await FXRates.rates(onDay: "yesterday", base: "EUR")) { error in
            XCTAssertEqual(error as? FXRatesError, .badDate("yesterday"))
        }
        XCTAssertTrue(transport.requested.isEmpty)
    }

    func testASingleConversionAtTodaysRate() async throws {
        transport.answer("https://api.frankfurter.dev/v1/latest?base=EUR&symbols=GBP&amount=100", #"{"amount":100.0,"base":"EUR","date":"2026-09-09","rates":{"GBP":85.898}}"#)
        let conversion = try await FXRates.convert(100, from: "EUR", to: "GBP")
        XCTAssertEqual(conversion.converted, decimal("85.898"))
        XCTAssertEqual(conversion.rate, decimal("0.85898"))
        XCTAssertEqual(conversion.amount, 100)
        XCTAssertEqual(conversion.quote, "GBP")
        XCTAssertNil(conversion.requestedDay)
        XCTAssertFalse(conversion.wasSubstituted)
    }

    func testAConversionOnTheDayItHappened() async throws {
        transport.answer("https://api.frankfurter.dev/v1/2026-07-31?base=USD&symbols=GBP&amount=2400", Recorded.ecbDatedAmount)
        let batch = try await FXRates.convert(2400, from: "USD", to: ["GBP"], onDay: "2026-07-31")
        let gbp = try XCTUnwrap(batch.conversions.first)
        XCTAssertEqual(gbp.converted, decimal("1788.2"), "Frankfurter's own figure, not rate × amount re-rounded")
        XCTAssertEqual(gbp.publishedOn, "2026-07-31")
        XCTAssertTrue(gbp.isExactDate)
        XCTAssertEqual(batch.missing, [])
    }

    func testTheWideSourceMultipliesHereInDecimal() async throws {
        transport.answer("https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.min.json", Recorded.wideLatest)
        let batch = try await FXRates.convert(2400, from: "EUR", to: ["GBP", "BTC"], source: .wide)
        XCTAssertEqual(batch.conversions.map(\.quote), ["GBP", "BTC"])
        XCTAssertEqual(batch.conversions[0].converted, decimal("2060.513376"), "2400 × 0.85854724, exactly")
        XCTAssertEqual(batch.conversions[1].converted, decimal("0.0356636736"))
        XCTAssertEqual("\(batch.conversions[0].converted)", "2060.513376")
    }

    func testAQuoteTheSourceLacksIsNamedNotThrown() async throws {
        transport.answer("https://api.frankfurter.dev/v1/latest?base=EUR&symbols=GBP,XYZ&amount=1", #"{"amount":1.0,"base":"EUR","date":"2026-09-09","rates":{"GBP":0.85898}}"#)
        let batch = try await FXRates.convert(1, from: "EUR", to: ["GBP", "XYZ"])
        XCTAssertEqual(batch.conversions.map(\.quote), ["GBP"])
        XCTAssertEqual(batch.missing, ["XYZ"])
    }

    func testEveryQuoteMissingIsAnError() async {
        transport.answer("https://api.frankfurter.dev/v1/latest?base=EUR&symbols=XYZ,ZZZ&amount=1", #"{"amount":1.0,"base":"EUR","date":"2026-09-09","rates":{}}"#)
        await XCTAssertThrowsErrorAsync(try await FXRates.convert(1, from: "EUR", to: ["XYZ", "ZZZ"])) { error in
            XCTAssertEqual(error as? FXRatesError, .missingRates(base: "EUR", quotes: ["XYZ", "ZZZ"], source: .ecb))
        }
    }

    func testAnUnknownBaseIsNoDataWithTheUndatedRepair() async {
        transport.answer("https://api.frankfurter.dev/v1/latest?base=XXX&symbols=GBP", status: 404, Recorded.notFound)
        await XCTAssertThrowsErrorAsync(try await FXRates.latest(base: "XXX", symbols: ["GBP"])) { error in
            XCTAssertEqual(error as? FXRatesError, .noData("XXX rates", dated: false, source: .ecb))
        }
    }

    func testADateOutsideTheSeriesIsNoDataWithTheDatedRepair() async {
        transport.answer("https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@2099-01-01/v1/currencies/eur.min.json", status: 404, "")
        await XCTAssertThrowsErrorAsync(try await FXRates.rates(onDay: "2099-01-01", base: "EUR", source: .wide)) { error in
            XCTAssertEqual(error as? FXRatesError, .noData("EUR rates", dated: true, source: .wide))
        }
    }

    func testThrottlingAndOutagesAreTheirOwnErrors() async {
        transport.fallback = TransportResponse(status: 429, body: Data())
        await XCTAssertThrowsErrorAsync(try await FXRates.latest()) { error in
            XCTAssertEqual(error as? FXRatesError, .rateLimited)
        }
        transport.fallback = TransportResponse(status: 503, body: Data())
        await XCTAssertThrowsErrorAsync(try await FXRates.latest()) { error in
            XCTAssertEqual(error as? FXRatesError, .upstream("the rate source returned 503"))
        }
    }

    func testAConnectionFailureReadsAsASentence() async {
        transport.failure = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost,
                                    userInfo: [NSLocalizedDescriptionKey: "A server with the specified hostname could not be found."])
        await XCTAssertThrowsErrorAsync(try await FXRates.currencies()) { error in
            XCTAssertEqual(error as? FXRatesError, .upstream("A server with the specified hostname could not be found."))
        }
    }

    func testTheCurrencyLists() async throws {
        transport.answer("https://api.frankfurter.dev/v1/currencies", Recorded.ecbCurrencies)
        transport.answer("https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.min.json", Recorded.wideCurrencies)
        let ecb = try await FXRates.currencies()
        let wide = try await FXRates.currencies(source: .wide)
        XCTAssertEqual(ecb.count, 30)
        XCTAssertEqual(wide.map(\.code), ["BTC", "EUR", "GBP", "USD"])
    }

    func testNegativeAndNonFiniteAmountsAreRefused() async {
        await XCTAssertThrowsErrorAsync(try await FXRates.convert(-5, from: "EUR", to: "GBP")) { error in
            XCTAssertEqual(error as? FXRatesError, .badAmount(-5))
        }
        await XCTAssertThrowsErrorAsync(try await FXRates.convert(Decimal.nan, from: "EUR", to: "GBP")) { _ in }
        XCTAssertTrue(transport.requested.isEmpty)
    }

    func testZeroConvertsToZeroWithNoRate() async throws {
        transport.answer("https://api.frankfurter.dev/v1/latest?base=EUR&symbols=GBP&amount=0", #"{"amount":0.0,"base":"EUR","date":"2026-09-09","rates":{"GBP":0.0}}"#)
        let conversion = try await FXRates.convert(0, from: "EUR", to: "GBP")
        XCTAssertEqual(conversion.converted, 0)
        XCTAssertEqual(conversion.rate, 0)
    }

    func testTheTimeoutIsPassedThrough() async throws {
        FXRates.timeout = 3
        transport.answer("https://api.frankfurter.dev/v1/currencies", Recorded.ecbCurrencies)
        _ = try await FXRates.currencies()
        XCTAssertEqual(transport.timeouts, [3])
    }
}

// MARK: - Words and shapes

final class ErrorAndModelTests: XCTestCase {

    func testEveryErrorSaysWhatToDo() {
        XCTAssertEqual(FXRatesError.noData("XXX rates", dated: false, source: .ecb).localizedDescription,
                       "No data for XXX rates (ecb): no such currency on this source")
        XCTAssertEqual(FXRatesError.noData("EUR rates", dated: true, source: .wide).localizedDescription,
                       "No data for EUR rates (wide): check the currency exists and that the date is not before the series begins")
        XCTAssertEqual(FXRatesError.missingRates(base: "EUR", quotes: ["XYZ", "ZZZ"], source: .ecb).localizedDescription,
                       "No ecb rate for EUR to XYZ, ZZZ")
        XCTAssertTrue(FXRatesError.rateLimited.localizedDescription.contains("throttling"))
        XCTAssertEqual(FXRatesError.upstream("timed out").localizedDescription, "The rate source could not be read: timed out")
        XCTAssertEqual(FXRatesError.decoding("The rates").localizedDescription, "The rates was not in the expected shape")
        XCTAssertTrue(FXRatesError.badDate("").localizedDescription.contains("(empty)"))
        XCTAssertTrue(FXRatesError.badAmount(-1).localizedDescription.contains("refund"))
    }

    func testSourcesSayWhatTheyAre() {
        XCTAssertEqual(Source.ecb.describedAs, "ECB reference rate")
        XCTAssertEqual(Source.wide.describedAs, "community aggregate")
        XCTAssertEqual(Source.allCases.map(\.rawValue), ["ecb", "wide"])
    }

    func testEverythingRoundTripsThroughJSON() throws {
        let table = RateTable(source: .ecb, base: "EUR", requestedDay: "2026-08-09", publishedOn: "2026-08-07",
                              isExactDate: false, rates: ["GBP": decimal("0.85765")], missing: ["XYZ"])
        XCTAssertEqual(try JSONDecoder().decode(RateTable.self, from: JSONEncoder().encode(table)), table)
        let conversion = Conversion(source: .wide, base: "EUR", quote: "BTC", rate: decimal("0.000014859864"), amount: 2400,
                                    converted: decimal("0.0356636736"), requestedDay: nil, publishedOn: "2026-09-10", isExactDate: true)
        XCTAssertEqual(try JSONDecoder().decode(Conversion.self, from: JSONEncoder().encode(conversion)), conversion)
        let batch = ConversionBatch(conversions: [conversion], missing: [])
        XCTAssertEqual(try JSONDecoder().decode(ConversionBatch.self, from: JSONEncoder().encode(batch)), batch)
        let currency = Currency(code: "GBP", name: "British Pound")
        XCTAssertEqual(try JSONDecoder().decode(Currency.self, from: JSONEncoder().encode(currency)), currency)
        for source in Source.allCases {
            XCTAssertEqual(try JSONDecoder().decode(Source.self, from: JSONEncoder().encode(source)), source)
        }
    }

    func testDecimalsSurviveJSONWithoutBinaryNoise() throws {
        let conversion = Conversion(source: .ecb, base: "EUR", quote: "GBP", rate: decimal("0.85898"), amount: decimal("0.1"),
                                    converted: decimal("0.085898"), requestedDay: nil, publishedOn: "2026-09-09", isExactDate: true)
        let text = String(decoding: try JSONEncoder().encode(conversion), as: UTF8.self)
        XCTAssertTrue(text.contains(#""rate":0.85898"#), text)
        XCTAssertTrue(text.contains(#""amount":0.1"#), text)
    }

    func testLookupIgnoresCase() {
        let table = RateTable(source: .ecb, base: "EUR", requestedDay: nil, publishedOn: "2026-09-09",
                              isExactDate: true, rates: ["GBP": 1], missing: [])
        XCTAssertEqual(table.rate(for: "gbp"), 1)
        XCTAssertNil(table.rate(for: "usd"))
        XCTAssertFalse(table.wasSubstituted)
    }
}

// MARK: - Async assertion

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath, line: UInt = #line,
    _ handler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("expected an error", file: file, line: line)
    } catch {
        handler(error)
    }
}
