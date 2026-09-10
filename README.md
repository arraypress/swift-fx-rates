# Swift FX Rates

What a currency was worth, today or on the day it mattered — as `Decimal` values from two open sources, on any Apple platform.

```swift
import FXRates

try await FXRates.convert(2400, from: "USD", to: "GBP", on: lastDayOfJuly)
// Conversion(rate: 0.74508…, converted: 1788.2, publishedOn: "2026-07-31", isExactDate: true, source: .ecb)

let sunday = try await FXRates.rates(onDay: "2026-08-09", base: "EUR", symbols: ["GBP"])
sunday.publishedOn        // "2026-08-07" — the ECB does not publish at weekends
sunday.isExactDate        // false, and it says so

try await FXRates.latest(base: "EUR").rate(for: "usd")          // 1.1652
try await FXRates.convert(1, from: "EUR", to: "BTC", source: .wide)   // 0.000014859864
try await FXRates.currencies()                                   // 30, sorted by code
```

## Why

| Question | The wrong answer, and why it is tempting |
|---|---|
| What was $2,400 in sterling on 31 July? | Today's rate. The statement has to say what it was **on that day**; the ECB has published a reference rate every working day since 1999, and that is the figure an accountant accepts. |
| What about a Sunday? | Whatever the API returns. It returns Friday's, silently. On a royalty conversion, a different day's rate than the one recorded against a payment is real money — so the published day is a field here, not a footnote. |
| `0.85898 * 100` | `85.89800000000001`. Money is `Decimal` throughout: a rate keeps exactly the digits it was published with, and multiplying by it does not grow noise. |
| Is there a rate for Bitcoin? | Not from a central bank. The wide source carries about 340 currencies including crypto and publishes at weekends — and the result says it is a community aggregate, not an official rate. |
| Why did the source say 404? | It says 404 for an unknown currency and for a date outside its series alike; the error here says which repair to try. |

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-fx-rates.git", from: "0.1.0")
```

Foundation only. No dependencies, every Apple platform, macOS 14+. No key for either source.

## Two sources

```swift
FXRates.latest(source: .ecb)     // the default
FXRates.latest(source: .wide)
```

| | `.ecb` | `.wide` |
|---|---|---|
| Currencies | 30 | about 340, including crypto |
| Weekends | no — the preceding working day | yes |
| Authority | **official reference rate** | community aggregate |
| Back to | 1999 | 2024 |

The ECB rate, via Frankfurter, is the citable one. The wide set is published as dated
package versions on a CDN — the date is the version, which is what makes it work without
a key or a server. Every result carries its `source`, and `Source.describedAs` says it in
words a report can print.

## A day's rates

```swift
try await FXRates.rates(on: date, base: "EUR", symbols: ["GBP", "USD"])   // the calendar day, in UTC
try await FXRates.rates(onDay: "2026-07-31", base: "EUR")                  // the string form callers already hold
```

`RateTable` carries `requestedDay`, `publishedOn` and `isExactDate`. A `Date` becomes its
UTC calendar day, because both sources stamp their tables with a plain date and neither
says which zone; a caller in Auckland asking for "today" would otherwise get tomorrow. A
day that is not written `YYYY-MM-DD` is refused before any request is made.

## Converting

```swift
try await FXRates.convert(2400, from: "USD", to: "GBP", on: date)
try await FXRates.convert(2400, from: "USD", to: ["GBP", "EUR", "XYZ"], onDay: "2026-07-31")
// ConversionBatch(conversions: [GBP, EUR], missing: ["XYZ"])
```

Asking for four currencies and getting three tells you which one is absent; only when
none of them exist is it an error. On the ECB source the amount is sent to Frankfurter,
which multiplies server-side and rounds the way its published tables do, and the rate is
derived back — so the converted figure is the one the source itself would show. The wide
source publishes rates only, so the multiplication is done here, exactly.

A negative amount is refused: a refund is a positive amount the other way.

## Errors

`noData` (a 404, with `dated` saying whether to check the date or the currency),
`missingRates`, `rateLimited`, `upstream`, `decoding`, `badDate`, `badAmount` — every one
with a description a caller can print unchanged.

## Testing without the network

```swift
FXRates.transport = RecordedTransport()   // anything conforming to Transport
```

`Transport` is one GET as a value. The package's own suite answers every request from
recordings of what the sources sent, so a red build is about this code and never about the
ECB.

## Sources

- [Frankfurter](https://frankfurter.dev) — the ECB's reference rates as JSON, free, no key, `api.frankfurter.dev`.
- [fawazahmed0/currency-api](https://github.com/fawazahmed0/exchange-api) — the community set, served by jsDelivr as dated npm versions, free, no key, no rate limit. Both ask that clients identify themselves; the default transport sends a User-Agent naming this package.

## Tested

41 tests, every one offline: every URL the package builds, the parsers against recorded
responses from both sources (a Sunday resolving to the Friday, Frankfurter's converted
figure kept and the rate derived back, an exponent-notation crypto rate decoded to its
digits), Decimal arithmetic without binary noise, a missing quote named rather than thrown,
every status and connection failure mapped to its error, every error's words, and every
model through JSON.

## Licence

MIT.
