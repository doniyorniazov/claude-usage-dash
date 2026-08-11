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
    /// 60s margin so a token about to lapse fails fast with a clear message, not a 401.
    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

enum Keychain {
    private static let service = "Claude Code-credentials"

    /// Reads the OAuth credentials Claude Code stores under service "Claude Code-credentials".
    /// Reading the secret data triggers the macOS keychain access prompt — go through
    /// CredentialsCache instead of calling this directly.
    static func loadClaudeCredentials(account: String? = nil) throws -> ClaudeCredentials {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let account { query[kSecAttrAccount as String] = account }
        var item: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound, account != nil {
            // Retry without account constraint (any account under this service).
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

    /// Attribute-only lookup: identifies the item and its modification date without
    /// touching the secret, so it never triggers the keychain access prompt.
    static func credentialsAttributes() throws -> (mdat: Date, account: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.osStatus(status)
        }
        guard let attrs = item as? [String: Any],
              let mdat = attrs[kSecAttrModificationDate as String] as? Date
        else { throw KeychainError.unexpectedFormat }
        return (mdat, attrs[kSecAttrAccount as String] as? String)
    }
}

/// The app is ad-hoc signed, so macOS can't durably remember "Always Allow" and every
/// secret read risks a password prompt. Cache credentials in memory and re-read the
/// secret only when the item's modification date shows Claude Code rewrote it.
enum CredentialsCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: (creds: ClaudeCredentials, mdat: Date)?
    nonisolated(unsafe) private static var lastFailure: (mdat: Date, error: Error)?

    static func current() throws -> ClaudeCredentials {
        lock.lock()
        defer { lock.unlock() }
        let attrs: (mdat: Date, account: String?)
        do { attrs = try Keychain.credentialsAttributes() }
        catch {
            // The freshness check is an optimization — a valid cache still serves.
            if let hit = cached, !hit.creds.isExpired { return hit.creds }
            throw error
        }
        if let hit = cached, hit.mdat == attrs.mdat { return hit.creds }
        // A failed read (e.g. prompt denied) stays failed until the item changes;
        // re-prompting every probe would recreate the bug this cache exists to fix.
        if let failure = lastFailure, failure.mdat == attrs.mdat { throw failure.error }
        do {
            let fresh = try Keychain.loadClaudeCredentials(account: attrs.account)
            cached = (fresh, attrs.mdat)
            lastFailure = nil
            return fresh
        } catch {
            lastFailure = (attrs.mdat, error)
            throw error
        }
    }
}
