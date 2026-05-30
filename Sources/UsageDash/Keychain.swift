import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case unexpectedFormat
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "No 'Claude Code-credentials' item found in Keychain. Sign in with `claude` first."
        case .unexpectedFormat:
            return "Keychain item exists but has unexpected format."
        case .osStatus(let s):
            return "Keychain error \(s): \(SecCopyErrorMessageString(s, nil) as String? ?? "unknown")"
        }
    }
}

struct ClaudeCredentials {
    let accessToken: String
    let expiresAt: Date
    let subscriptionType: String?
    var isExpired: Bool { Date() >= expiresAt }
}

enum Keychain {
    /// Reads the OAuth credentials Claude Code stores under service "Claude Code-credentials".
    /// Tries the current macOS user as account name first, then any matching item.
    static func loadClaudeCredentials() throws -> ClaudeCredentials {
        let service = "Claude Code-credentials"
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            // Try without account constraint (any account under this service).
            query.removeValue(forKey: kSecAttrAccount as String)
            status = SecItemCopyMatching(query as CFDictionary, &item)
        }
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.osStatus(status)
        }
        guard let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              let expiresMs = oauth["expiresAt"] as? Double
        else { throw KeychainError.unexpectedFormat }

        return ClaudeCredentials(
            accessToken: token,
            expiresAt: Date(timeIntervalSince1970: expiresMs / 1000),
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }
}
