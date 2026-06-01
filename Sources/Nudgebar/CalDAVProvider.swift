import NudgebarCore
import NudgebarProviders
import Foundation

struct ICalEvent: Equatable {
    var uid: String
    var summary: String
    var start: Date
    var end: Date
    var location: String?
    var organizer: String?
    var isAllDay: Bool
    var cancelled: Bool
}

/// Pure parser for iCalendar VEVENT blocks (RFC 5545 essentials). Unit-tested.
enum ICalParser {
    static func events(from ical: String) -> [ICalEvent] {
        let lines = unfold(ical)
        var events: [ICalEvent] = []
        var props: [String: (params: [String: String], value: String)] = [:]
        var inEvent = false

        for line in lines {
            if line == "BEGIN:VEVENT" { inEvent = true; props = [:]; continue }
            if line == "END:VEVENT" {
                inEvent = false
                if let event = makeEvent(props) { events.append(event) }
                continue
            }
            guard inEvent, let parsed = parseLine(line) else { continue }
            props[parsed.name] = (parsed.params, parsed.value)
        }
        return events
    }

    /// Join folded continuation lines (those starting with a space or tab).
    static func unfold(_ text: String) -> [String] {
        var result: [String] = []
        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if let first = line.first, first == " " || first == "\t", !result.isEmpty {
                result[result.count - 1] += line.dropFirst()
            } else {
                result.append(line)
            }
        }
        return result
    }

    static func parseLine(_ line: String) -> (name: String, params: [String: String], value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let lhs = String(line[line.startIndex..<colon])
        let value = String(line[line.index(after: colon)...])
        let segments = lhs.split(separator: ";").map(String.init)
        guard let name = segments.first else { return nil }
        var params: [String: String] = [:]
        for segment in segments.dropFirst() {
            let kv = segment.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { params[kv[0].uppercased()] = kv[1] }
        }
        return (name.uppercased(), params, value)
    }

    private static func makeEvent(_ props: [String: (params: [String: String], value: String)]) -> ICalEvent? {
        guard let dtstart = props["DTSTART"], let (start, isAllDay) = parseDate(dtstart.value, tzid: dtstart.params["TZID"]) else {
            return nil
        }
        let end: Date
        if let dtend = props["DTEND"], let (parsed, _) = parseDate(dtend.value, tzid: dtend.params["TZID"]) {
            end = parsed
        } else {
            end = start.addingTimeInterval(1800)
        }
        let organizer: String?
        if let org = props["ORGANIZER"] {
            organizer = org.params["CN"] ?? org.value.replacingOccurrences(of: "mailto:", with: "")
        } else {
            organizer = nil
        }
        return ICalEvent(
            uid: props["UID"]?.value ?? UUID().uuidString,
            summary: unescape(props["SUMMARY"]?.value ?? "Untitled event"),
            start: start,
            end: end,
            location: props["LOCATION"].map { unescape($0.value) },
            organizer: organizer,
            isAllDay: isAllDay,
            cancelled: (props["STATUS"]?.value.uppercased() == "CANCELLED")
        )
    }

    static func parseDate(_ value: String, tzid: String?) -> (Date, Bool)? {
        if value.count == 8 {
            return formatter("yyyyMMdd", timeZone: tzid ?? "UTC").date(from: value).map { ($0, true) }
        }
        if value.hasSuffix("Z") {
            return formatter("yyyyMMdd'T'HHmmss", timeZone: "UTC").date(from: String(value.dropLast())).map { ($0, false) }
        }
        return formatter("yyyyMMdd'T'HHmmss", timeZone: tzid ?? TimeZone.current.identifier).date(from: value).map { ($0, false) }
    }

    private static func formatter(_ format: String, timeZone: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZone) ?? .current
        formatter.dateFormat = format
        return formatter
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

/// Real CalDAV client (Basic auth). Discovers calendars via PROPFIND and fetches
/// events via a calendar-query REPORT, parsing the returned iCalendar data.
final class CalDAVProvider: CalendarSyncProvider {
    let descriptor: ProviderDescriptor
    private let account: ConnectedAccount
    private let serverURL: URL
    private let basicToken: String
    private let session: URLSession

    /// `credentials` is "serverURL\u{1F}username\u{1F}password".
    init?(account: ConnectedAccount, credentials: String, session: URLSession = .shared) {
        let parts = credentials.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let url = URL(string: parts[0]), url.scheme?.lowercased() == "https" else {
            return nil
        }
        self.account = account
        self.serverURL = url
        self.basicToken = Data("\(parts[1]):\(parts[2])".utf8).base64EncodedString()
        self.session = session
        self.descriptor = ProviderDescriptor(id: .calDAV, authMode: .calDAVCredentials, capabilities: [.readEvents, .recurringEvents], notes: "CalDAV")
    }

    func discoverAccounts() async throws -> [ConnectedAccount] { [account] }

    func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
          <d:prop><d:resourcetype/><d:displayname/></d:prop>
        </d:propfind>
        """
        let data = try await request(url: serverURL, method: "PROPFIND", body: body, depth: "1")
        let calendars = CalDAVXML.calendars(from: data, baseURL: serverURL)
        if calendars.isEmpty {
            return [CalendarSource(id: serverURL.absoluteString, title: account.displayName, sourceTitle: "CalDAV", providerID: .calDAV, accountID: account.id, externalID: serverURL.absoluteString)]
        }
        return calendars.map { entry in
            CalendarSource(id: entry.href, title: entry.name, sourceTitle: "CalDAV", providerID: .calDAV, accountID: account.id, externalID: entry.href)
        }
    }

    func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }
    func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }

    private func sync(_ syncRequest: ProviderSyncRequest) async throws -> ProviderSyncResult {
        let sources = syncRequest.sources.isEmpty ? try await discoverSources(for: syncRequest.account) : syncRequest.sources
        let stamp = ICalParser.utcStampFormatter()
        var occurrences: [AlertOccurrence] = []

        for source in sources {
            guard let url = URL(string: source.externalID) else { continue }
            let body = """
            <?xml version="1.0" encoding="utf-8"?>
            <c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
              <d:prop><c:calendar-data/></d:prop>
              <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT">
                <c:time-range start="\(stamp.string(from: syncRequest.windowStart))" end="\(stamp.string(from: syncRequest.windowEnd))"/>
              </c:comp-filter></c:comp-filter></c:filter>
            </c:calendar-query>
            """
            let data = try await request(url: url, method: "REPORT", body: body, depth: "1")
            for ical in CalDAVXML.calendarData(from: data) {
                for event in ICalParser.events(from: ical) where event.start >= syncRequest.windowStart && event.start <= syncRequest.windowEnd {
                    occurrences.append(map(event, account: syncRequest.account, source: source))
                }
            }
        }

        let cursor = SyncCursor(providerID: .calDAV, accountID: syncRequest.account.id, sourceID: sources.first?.id ?? "all", value: "synced", updatedAt: Date())
        return ProviderSyncResult(occurrences: occurrences, nextCursor: cursor, completedAt: Date())
    }

    private func map(_ event: ICalEvent, account: ConnectedAccount, source: CalendarSource) -> AlertOccurrence {
        AlertOccurrence(
            id: "caldav:\(account.id):\(source.id):\(event.uid)",
            title: event.summary,
            startDate: event.start,
            endDate: event.end,
            calendarTitle: source.title,
            location: event.location,
            providerID: .calDAV,
            accountID: account.id,
            sourceID: source.id,
            externalID: event.uid,
            status: event.cancelled ? .cancelled : .confirmed,
            isAllDay: event.isAllDay,
            organizer: event.organizer
        )
    }

    private func request(url: URL, method: String, body: String, depth: String) async throws -> Data {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("Basic \(basicToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(depth, forHTTPHeaderField: "Depth")
        urlRequest.httpBody = body.data(using: .utf8)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ProviderSyncError.transport(String(data: data, encoding: .utf8) ?? "CalDAV request failed")
        }
        return data
    }
}

extension ICalParser {
    static func utcStampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }
}

/// Minimal CalDAV multistatus XML extraction via XMLParser.
enum CalDAVXML {
    struct CalendarEntry { let href: String; let name: String }

    static func calendars(from data: Data, baseURL: URL) -> [CalendarEntry] {
        let delegate = PropfindDelegate(baseURL: baseURL)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        parser.parse()
        return delegate.calendars
    }

    static func calendarData(from data: Data) -> [String] {
        let delegate = CalendarDataDelegate()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        parser.parse()
        return delegate.calendarData
    }

    private final class PropfindDelegate: NSObject, XMLParserDelegate {
        var calendars: [CalendarEntry] = []
        private let baseURL: URL
        private var href = ""
        private var displayName = ""
        private var isCalendar = false
        private var current = ""

        init(baseURL: URL) { self.baseURL = baseURL }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
            current = ""
            if elementName == "response" { href = ""; displayName = ""; isCalendar = false }
            if elementName == "calendar" { isCalendar = true }
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { current += string }
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            switch elementName {
            case "href": if href.isEmpty { href = current.trimmingCharacters(in: .whitespacesAndNewlines) }
            case "displayname": displayName = current.trimmingCharacters(in: .whitespacesAndNewlines)
            case "response":
                if isCalendar, !href.isEmpty {
                    let resolved = URL(string: href, relativeTo: baseURL)?.absoluteString ?? href
                    calendars.append(CalendarEntry(href: resolved, name: displayName.isEmpty ? "Calendar" : displayName))
                }
            default: break
            }
        }
    }

    private final class CalendarDataDelegate: NSObject, XMLParserDelegate {
        var calendarData: [String] = []
        private var capturing = false
        private var buffer = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
            if elementName == "calendar-data" { capturing = true; buffer = "" }
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { if capturing { buffer += string } }
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            if elementName == "calendar-data" { capturing = false; calendarData.append(buffer) }
        }
    }
}
