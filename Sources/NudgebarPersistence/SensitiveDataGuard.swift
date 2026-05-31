import Foundation

public enum SensitiveDataGuardError: Error, Equatable {
    case sensitiveKey(String)
    case sensitiveValue(String)
}

public enum SensitiveDataGuard {
    private static let sensitiveKeyFragments = [
        "token",
        "password",
        "secret",
        "apikey",
        "api_key",
        "authorization",
        "basic ",
        "pkce",
        "verifier",
        "meetinglink",
        "meeting_link",
        "attendee",
        "private_note",
        "rawpayload",
        "raw_payload"
    ]

    private static let sensitiveValuePatterns = [
        "bearer ",
        "basic ",
        "client_secret",
        "refresh_token",
        "access_token",
        "api_key",
        "-----begin "
    ]

    public static func validateNonSensitive(
        key: String,
        valueDescription: String
    ) throws {
        let normalizedKey = key.lowercased()
        if let match = sensitiveKeyFragments.first(where: { normalizedKey.contains($0) }) {
            throw SensitiveDataGuardError.sensitiveKey(match)
        }

        let normalizedValue = valueDescription.lowercased()
        if let match = sensitiveValuePatterns.first(where: { normalizedValue.contains($0) }) {
            throw SensitiveDataGuardError.sensitiveValue(match)
        }
    }
}
