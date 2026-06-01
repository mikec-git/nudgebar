import Foundation

/// Lenient parser for the date strings returned by calendar/scheduling APIs:
/// ISO-8601 with/without fractional seconds (any precision) and RFC-822 style
/// no-colon offsets, plus date-only values.
enum CalendarDateParsing {
    static func parse(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        // Strip fractional seconds of any digit count (e.g. ".000000") and retry.
        if let dot = raw.firstIndex(of: ".") {
            var end = raw.index(after: dot)
            while end < raw.endIndex, raw[end].isNumber { end = raw.index(after: end) }
            let stripped = raw.replacingCharacters(in: dot..<end, with: "")
            if let date = iso.date(from: stripped) { return date }
        }

        // RFC-822 style offset without a colon (e.g. Acuity's "-0800").
        let offsetFormatter = DateFormatter()
        offsetFormatter.locale = Locale(identifier: "en_US_POSIX")
        offsetFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = offsetFormatter.date(from: raw) { return date }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }
}
