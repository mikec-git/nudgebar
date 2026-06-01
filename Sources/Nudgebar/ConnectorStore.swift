import NudgebarCore
import NudgebarProviders
import NudgebarAuth
import Combine
import Foundation
import os.log

/// Manages connected cloud accounts and syncs their events into the alert
/// pipeline via the foundation's `CalendarSyncProvider` contract. EventKit stays
/// separate (handled by `CalendarAccess`); this covers the cloud/CalDAV providers.
@MainActor
final class ConnectorStore: ObservableObject {
    @Published private(set) var accounts: [ConnectedAccount] = []
    @Published private(set) var occurrences: [AlertOccurrence] = []
    @Published private(set) var lastSyncError: String?

    private static let logger = Logger(subsystem: "com.nudgebar", category: "Connectors")
    private let defaults: UserDefaults
    private let makeProvider: (ConnectedAccount) -> CalendarSyncProvider?
    private var providers: [String: CalendarSyncProvider] = [:]
    private var cursors: [String: SyncCursor] = [:]
    private static let accountsKey = "connectedAccounts"

    init(
        defaults: UserDefaults = .standard,
        makeProvider: @escaping (ConnectedAccount) -> CalendarSyncProvider? = { ConnectorProviderFactory.make(account: $0) }
    ) {
        self.defaults = defaults
        self.makeProvider = makeProvider
        loadAccounts()
    }

    var hasAccounts: Bool { !accounts.isEmpty }

    func account(for providerID: ProviderID) -> ConnectedAccount? {
        accounts.first { $0.providerID == providerID }
    }

    func addAccount(_ account: ConnectedAccount) {
        accounts.removeAll { $0.id == account.id }
        accounts.append(account)
        providers[account.id] = makeProvider(account)
        cursors[account.id] = nil
        persistAccounts()
    }

    func removeAccount(id: String) {
        accounts.removeAll { $0.id == id }
        providers[id] = nil
        cursors[id] = nil
        occurrences.removeAll { $0.accountID == id }
        persistAccounts()
    }

    /// Sync all connected accounts and replace the merged occurrence set.
    func sync(windowStart: Date, windowEnd: Date) async {
        guard !accounts.isEmpty else {
            if !occurrences.isEmpty { occurrences = [] }
            return
        }

        var merged: [AlertOccurrence] = []
        var firstError: String?

        for account in accounts {
            guard let provider = providers[account.id] else { continue }
            do {
                let sources = try await provider.discoverSources(for: account)
                let request = ProviderSyncRequest(
                    account: account,
                    sources: sources,
                    windowStart: windowStart,
                    windowEnd: windowEnd,
                    previousCursor: cursors[account.id],
                    trigger: .poll
                )
                let result = cursors[account.id] == nil
                    ? try await provider.initialSync(request: request)
                    : try await provider.incrementalSync(request: request)
                cursors[account.id] = result.nextCursor
                merged.append(contentsOf: result.occurrences.filter { !result.deletedOccurrenceIDs.contains($0.externalID) })
            } catch {
                let message = "\(account.displayName): \(error.localizedDescription)"
                firstError = firstError ?? message
                Self.logger.warning("Sync failed for \(account.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        occurrences = merged
        lastSyncError = firstError
    }

    private func loadAccounts() {
        guard let data = defaults.data(forKey: Self.accountsKey),
              let decoded = try? JSONDecoder().decode([ConnectedAccount].self, from: data) else {
            return
        }
        accounts = decoded
        for account in decoded {
            providers[account.id] = makeProvider(account)
        }
    }

    private func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: Self.accountsKey)
        }
    }
}

/// Builds the real `CalendarSyncProvider` for a connected account. Returns nil
/// when the provider isn't configured/credentialed yet (real clients are added
/// per provider).
enum ConnectorProviderFactory {
    static func make(account: ConnectedAccount, config: ConnectorClientConfig = ConnectorConfig.load()) -> CalendarSyncProvider? {
        switch account.providerID {
        case .calendly:
            guard let clientID = config.oauthClientID(for: .calendly), !clientID.isEmpty,
                  let metadata = ProviderAuthCatalog.metadata(providerID: .calendly, clientID: clientID, redirectURI: ConnectorConfig.redirectURI) else {
                return nil
            }
            let reference = ConnectorCredentials.oauthRefreshReference(providerID: .calendly, accountID: account.id)
            let tokenManager = OAuthTokenManager(metadata: metadata, clientSecret: config.oauthClientSecret(for: .calendly), refreshReference: reference)
            return CalendlyProvider(account: account, tokenManager: tokenManager)
        case .calCom:
            guard let reference = account.credentialReference,
                  let apiKey = ConnectorCredentials.read(reference: reference), !apiKey.isEmpty else {
                return nil
            }
            return CalComProvider(account: account, apiKey: apiKey)
        case .acuity:
            guard let reference = account.credentialReference,
                  let credentials = ConnectorCredentials.read(reference: reference), credentials.contains(":") else {
                return nil
            }
            return AcuityProvider(account: account, credentials: credentials)
        case .calDAV:
            guard let reference = account.credentialReference,
                  let credentials = ConnectorCredentials.read(reference: reference) else {
                return nil
            }
            return CalDAVProvider(account: account, credentials: credentials)
        case .eventKit, .googleCalendar, .microsoftGraph:
            // EventKit is handled directly by CalendarAccess; Google/Microsoft are
            // covered through macOS (EventKit), not a direct connector.
            return nil
        }
    }
}
