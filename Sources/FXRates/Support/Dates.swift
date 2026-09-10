//
//  Dates.swift
//  FXRates
//
//  Calendar days as the sources write them.
//

import Foundation

/// `YYYY-MM-DD` in and out.
enum Dates {

    /// Whether the text is a plausible calendar day: four-two-two digits,
    /// a real month, a day of 1–31, a year after 1900.
    static func isCalendarDate(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              year > 1900, (1...12).contains(month), (1...31).contains(day)
        else { return false }
        return true
    }

    /// The calendar day containing `date`, in UTC.
    ///
    /// UTC because both sources stamp their tables with a plain date and
    /// neither says which zone; the ECB's day ends at 16:00 CET and a caller
    /// in Auckland asking for "today" would otherwise get tomorrow.
    static func day(from date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
