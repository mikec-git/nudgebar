import XCTest
import NudgebarCore
import NudgebarProviders
@testable import Nudgebar

/// Stubs HTTP responses by URL so providers can be exercised end-to-end (fetch →
/// parse → occurrences) without hitting the network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URL) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url, let (status, data) = Self.responder?(url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

private func stubbedSession(_ responder: @escaping (URL) -> (Int, Data)) -> URLSession {
    StubURLProtocol.responder = responder
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

/// In-memory provider for ConnectorStore integration tests (no network).
private final class FakeProvider: CalendarSyncProvider {
    enum Outcome { case success([AlertOccurrence]); case failure }
    let descriptor = ProviderDescriptor(id: .calCom, authMode: .apiKey, capabilities: [.readEvents], notes: "fake")
    private let outcome: Outcome
    init(_ outcome: Outcome) { self.outcome = outcome }

    func discoverAccounts() async throws -> [ConnectedAccount] { [] }
    func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        [CalendarSource(id: account.id, title: "Fake", sourceTitle: "Fake", providerID: .calCom, accountID: account.id, externalID: account.id)]
    }
    func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try result() }
    func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try result() }

    private func result() throws -> ProviderSyncResult {
        switch outcome {
        case .success(let occurrences): return ProviderSyncResult(occurrences: occurrences, completedAt: Date(timeIntervalSince1970: 0))
        case .failure: throw ProviderSyncError.transport("boom")
        }
    }
}

final class ConnectorSyncTests: XCTestCase {
    private func request(_ account: ConnectedAccount) -> ProviderSyncRequest {
        ProviderSyncRequest(account: account, sources: [], windowStart: .distantPast, windowEnd: .distantFuture, previousCursor: nil, trigger: .poll)
    }

    // MARK: Provider pipelines (fetch -> parse -> occurrences)

    func testCalComProviderFetchesAndMapsBookings() async throws {
        let json = #"{"status":"success","data":[{"uid":"B1","title":"Demo","start":"2026-06-02T10:00:00.000Z","end":"2026-06-02T10:30:00.000Z","status":"accepted","location":"https://meet.example/x"}]}"#
        let session = stubbedSession { url in
            XCTAssertTrue(url.absoluteString.contains("api.cal.com/v2/bookings"))
            return (200, Data(json.utf8))
        }
        let account = ConnectedAccount(id: "acc", providerID: .calCom, displayName: "Cal.com")
        let provider = CalComProvider(account: account, apiKey: "key", session: session)
        let result = try await provider.initialSync(request: request(account))
        XCTAssertEqual(result.occurrences.map(\.title), ["Demo"])
        XCTAssertEqual(result.occurrences.first?.providerID, .calCom)
        XCTAssertEqual(result.occurrences.first?.calendarTitle, "Cal.com")
    }

    func testCalComProviderSurfacesHTTPStatusOnError() async {
        let session = stubbedSession { _ in (401, Data(#"{"message":"no api key"}"#.utf8)) }
        let account = ConnectedAccount(id: "acc", providerID: .calCom, displayName: "Cal.com")
        let provider = CalComProvider(account: account, apiKey: "bad", session: session)
        do {
            _ = try await provider.initialSync(request: request(account))
            XCTFail("expected a transport error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("401"), "error should include the HTTP status: \(error.localizedDescription)")
        }
    }

    func testCalendlyProviderFetchesAndMapsEvents() async throws {
        let user = #"{"resource":{"uri":"https://api.calendly.com/users/U1","name":"Me"}}"#
        let events = #"{"collection":[{"uri":"https://api.calendly.com/scheduled_events/EV1","name":"Intro","status":"active","start_time":"2026-06-02T10:00:00.000000Z","end_time":"2026-06-02T10:30:00.000000Z","location":{"type":"zoom","join_url":"https://zoom.us/j/1"}}]}"#
        let session = stubbedSession { url in
            if url.absoluteString.contains("users/me") { return (200, Data(user.utf8)) }
            if url.absoluteString.contains("scheduled_events") { return (200, Data(events.utf8)) }
            return (404, Data())
        }
        let account = ConnectedAccount(id: "acc", providerID: .calendly, displayName: "Calendly")
        let provider = CalendlyProvider(account: account, personalAccessToken: "pat", session: session)
        let result = try await provider.initialSync(request: request(account))
        XCTAssertEqual(result.occurrences.map(\.title), ["Intro"])
        XCTAssertEqual(result.occurrences.first?.providerID, .calendly)
        XCTAssertEqual(result.occurrences.first?.calendarTitle, "Calendly")
    }

    // MARK: ConnectorStore integration

    @MainActor
    private func makeStore(_ outcome: FakeProvider.Outcome) -> (ConnectorStore, String) {
        let suite = "ConnectorSyncTests.\(UUID().uuidString)"
        let store = ConnectorStore(defaults: UserDefaults(suiteName: suite)!, makeProvider: { _ in FakeProvider(outcome) })
        return (store, suite)
    }

    @MainActor
    func testStoreSyncPopulatesOccurrences() async {
        let occurrence = AlertOccurrence(id: "x", title: "T", startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 1800), calendarTitle: "Fake", accountID: "a")
        let (store, suite) = makeStore(.success([occurrence]))
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        store.addAccount(ConnectedAccount(id: "a", providerID: .calCom, displayName: "Fake"))
        await store.sync(windowStart: .distantPast, windowEnd: .distantFuture)
        XCTAssertEqual(store.occurrences.map(\.id), ["x"])
        XCTAssertNil(store.lastSyncError)
    }

    @MainActor
    func testStoreSyncFailureSetsErrorAndClearsOccurrences() async {
        let (store, suite) = makeStore(.failure)
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        store.addAccount(ConnectedAccount(id: "a", providerID: .calCom, displayName: "Fake"))
        await store.sync(windowStart: .distantPast, windowEnd: .distantFuture)
        XCTAssertTrue(store.occurrences.isEmpty)
        XCTAssertNotNil(store.lastSyncError)
    }

    @MainActor
    func testRemoveAccountClearsOccurrences() async {
        let occurrence = AlertOccurrence(id: "x", title: "T", startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 1800), calendarTitle: "Fake", accountID: "a")
        let (store, suite) = makeStore(.success([occurrence]))
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        store.addAccount(ConnectedAccount(id: "a", providerID: .calCom, displayName: "Fake"))
        await store.sync(windowStart: .distantPast, windowEnd: .distantFuture)
        store.removeAccount(id: "a")
        XCTAssertTrue(store.occurrences.isEmpty)
    }

    @MainActor
    func testPersistedAccountRebuildsProviderAfterReload() async {
        let occurrence = AlertOccurrence(id: "x", title: "T", startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 1800), calendarTitle: "Fake", accountID: "a")
        let suite = "ConnectorSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = ConnectorStore(defaults: defaults, makeProvider: { _ in FakeProvider(.success([occurrence])) })
        first.addAccount(ConnectedAccount(id: "a", providerID: .calCom, displayName: "Fake"))

        // A fresh store from the same defaults simulates an app relaunch.
        let reloaded = ConnectorStore(defaults: defaults, makeProvider: { _ in FakeProvider(.success([occurrence])) })
        XCTAssertEqual(reloaded.accounts.map(\.id), ["a"])
        await reloaded.sync(windowStart: .distantPast, windowEnd: .distantFuture)
        XCTAssertEqual(reloaded.occurrences.map(\.id), ["x"], "provider should be rebuilt for persisted accounts")
    }
}
