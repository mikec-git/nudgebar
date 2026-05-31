import NudgebarCore
import Foundation
import Security

public enum CredentialKind: String, Codable, Equatable, Sendable {
    case oauthRefreshToken
    case oauthAccessToken
    case calDAVPassword
    case apiKey
    case basicAuthPassword
    case pkceVerifier
}

public struct CredentialRecord: Equatable, Sendable {
    public let reference: CredentialReference
    public let kind: CredentialKind
    public let secret: Data

    public init(reference: CredentialReference, kind: CredentialKind, secret: Data) {
        self.reference = reference
        self.kind = kind
        self.secret = secret
    }
}

public protocol CredentialStore {
    func save(_ record: CredentialRecord) throws
    func read(reference: CredentialReference) throws -> CredentialRecord?
    func delete(reference: CredentialReference) throws
}

public enum CredentialStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}

public final class KeychainCredentialStore: CredentialStore {
    private let accessGroup: String?

    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }

    public func save(_ record: CredentialRecord) throws {
        var query = baseQuery(for: record.reference)
        query[kSecValueData as String] = record.secret
        query[kSecAttrDescription as String] = record.kind.rawValue

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                baseQuery(for: record.reference) as CFDictionary,
                [
                    kSecValueData as String: record.secret,
                    kSecAttrDescription as String: record.kind.rawValue
                ] as CFDictionary
            )

            guard updateStatus == errSecSuccess else {
                throw CredentialStoreError.unexpectedStatus(updateStatus)
            }
        } else if addStatus != errSecSuccess {
            throw CredentialStoreError.unexpectedStatus(addStatus)
        }
    }

    public func read(reference: CredentialReference) throws -> CredentialRecord? {
        var query = baseQuery(for: reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            return nil
        }

        return CredentialRecord(
            reference: reference,
            kind: CredentialKind(rawValue: reference.kind) ?? .oauthRefreshToken,
            secret: data
        )
    }

    public func delete(reference: CredentialReference) throws {
        let status = SecItemDelete(baseQuery(for: reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for reference: CredentialReference) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: reference.service,
            kSecAttrAccount as String: reference.account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

public final class InMemoryCredentialStore: CredentialStore {
    private var records: [CredentialReference: CredentialRecord] = [:]

    public init() {}

    public func save(_ record: CredentialRecord) throws {
        records[record.reference] = record
    }

    public func read(reference: CredentialReference) throws -> CredentialRecord? {
        records[reference]
    }

    public func delete(reference: CredentialReference) throws {
        records.removeValue(forKey: reference)
    }
}
