import Foundation

/// Pure, `Sendable` formatting helpers shared by presenters.
nonisolated enum Formatters {
    private static let minutesPerHour = 60

    private static let dayParser = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
    private static let timestampParser = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let timestampParserNoFraction = Date.ISO8601FormatStyle()

    /// "2014-11-05" → "2014". Returns `nil` for empty or malformed input.
    static func year(from dateString: String?) -> String? {
        guard let date = day(from: dateString) else { return nil }
        return date.formatted(.dateTime.year().locale(Locale(identifier: "en_US_POSIX")))
    }

    /// "2014-11-05" → "Nov 5, 2014".
    static func longDate(from dateString: String?) -> String? {
        day(from: dateString)?.formatted(.dateTime.month(.abbreviated).day().year())
    }

    static func day(from dateString: String?) -> Date? {
        guard let value = dateString?.nilIfBlank else { return nil }
        return try? dayParser.parse(value)
    }

    /// Parses ISO-8601 timestamps with or without fractional seconds.
    static func timestamp(from string: String?) -> Date? {
        guard let value = string?.nilIfBlank else { return nil }
        return (try? timestampParser.parse(value)) ?? (try? timestampParserNoFraction.parse(value))
    }

    /// 169 → "2h 49m"; 45 → "45m". Returns `nil` for missing/zero runtimes.
    static func runtime(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let hours = minutes / minutesPerHour
        let remainder = minutes % minutesPerHour
        switch (hours, remainder) {
        case (0, _): return "\(remainder)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(remainder)m"
        }
    }

    /// 12_345 → "12K".
    static func compact(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US")))
    }

    /// 165_000_000 → "$165M". Returns `nil` when TMDB reports 0 (unknown).
    static func money(_ value: Int?) -> String? {
        guard let value, value > 0 else { return nil }
        return value.formatted(
            .currency(code: "USD").notation(.compactName).locale(Locale(identifier: "en_US"))
        )
    }

    /// 7.456 → "7.5".
    static func rating(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
    }

    /// "en" → "English".
    static func languageName(code: String?) -> String? {
        guard let code = code?.nilIfBlank else { return nil }
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? code.uppercased()
    }

    static func relative(_ date: Date, now: Date = .now) -> String {
        date.formatted(.relative(presentation: .named).locale(Locale(identifier: "en_US")))
    }
}
