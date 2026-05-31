import Foundation

enum ConferenceType: String, Equatable, Sendable {
    case zoom
    case googleMeet
    case microsoftTeams
    case generic

    var label: String {
        switch self {
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .microsoftTeams: return "Teams"
        case .generic: return "Video call"
        }
    }
}

struct ConferenceLink: Equatable, Sendable {
    let type: ConferenceType
    let url: URL
}

/// Pure resolver that classifies an event's meeting URL / location / notes into a
/// conference type and a launch URL. Provider-agnostic: the caller supplies the
/// raw fields. A generic match is only accepted from the event's explicit meeting
/// URL, never from free-text location/notes (which may hold non-meeting links).
enum ConferenceLinkResolver {
    static func resolve(meetingURL: URL?, location: String? = nil, notes: String? = nil) -> ConferenceLink? {
        if let meetingURL, let link = classify(meetingURL, allowGeneric: true) {
            return link
        }
        for text in [location, notes].compactMap({ $0 }) {
            if let url = firstURL(in: text), let link = classify(url, allowGeneric: false) {
                return link
            }
        }
        return nil
    }

    static func classify(_ url: URL, allowGeneric: Bool) -> ConferenceLink? {
        guard let host = url.host?.lowercased() else {
            return nil
        }
        if host.contains("zoom.us") || host.contains("zoom.com") {
            return ConferenceLink(type: .zoom, url: url)
        }
        if host.contains("meet.google.com") {
            return ConferenceLink(type: .googleMeet, url: url)
        }
        if host.contains("teams.microsoft.com") || host.contains("teams.live.com") {
            return ConferenceLink(type: .microsoftTeams, url: url)
        }
        if allowGeneric, let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" {
            return ConferenceLink(type: .generic, url: url)
        }
        return nil
    }

    /// Find the first link in free text using the structured data detector (no regex).
    static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url
    }
}
