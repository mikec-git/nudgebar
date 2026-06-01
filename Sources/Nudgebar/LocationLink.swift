import Foundation

/// Finds the first web link in a location string - whether the whole string is a
/// URL or one is embedded in longer text ("Room A — https://…"). Uses
/// NSDataDetector rather than fragile regex.
enum LocationLink {
    static func firstURL(in text: String) -> URL? {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let url = detector.firstMatch(in: text, options: [], range: range)?.url,
              let scheme = url.scheme, scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
}
