import Foundation

enum ProbeError: Error, LocalizedError {
    case notAuthenticated(String)
    case http(Int, String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated(let m): return m
        case .http(let code, let body): return "HTTP \(code): \(body.prefix(120))"
        case .transport(let e): return e.localizedDescription
        }
    }
}

/// Sends a minimal /v1/messages request and parses the
/// `anthropic-ratelimit-unified-*` response headers.
/// One probe costs roughly 8 input + 1 output token on Haiku — ~$0.00001.
enum UsageProbe {
    static func fetch() async throws -> LimitState {
        let creds: ClaudeCredentials
        do { creds = try Keychain.loadClaudeCredentials() }
        catch { throw ProbeError.notAuthenticated((error as? LocalizedError)?.errorDescription ?? "Keychain read failed") }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "authorization")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "."]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw ProbeError.transport(error)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw ProbeError.http(-1, "no http response")
        }
        // 200 and 429 both carry the unified headers; 401 means re-auth needed.
        if http.statusCode == 401 {
            throw ProbeError.notAuthenticated("OAuth token rejected. Sign in again with `claude`.")
        }
        // For other failures we still try to parse headers if present.
        let state = parseHeaders(http)
        if state == nil {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProbeError.http(http.statusCode, body)
        }
        return state!
    }

    private static func parseHeaders(_ http: HTTPURLResponse) -> LimitState? {
        // HTTPURLResponse header keys are case-insensitive via .value(forHTTPHeaderField:).
        func h(_ key: String) -> String? {
            http.value(forHTTPHeaderField: key)
        }
        func d(_ key: String) -> Double? {
            h(key).flatMap(Double.init)
        }
        func dateFromEpoch(_ key: String) -> Date? {
            d(key).map { Date(timeIntervalSince1970: $0) }
        }
        let sess = d("anthropic-ratelimit-unified-5h-utilization")
        let week = d("anthropic-ratelimit-unified-7d-utilization")
        guard sess != nil || week != nil else { return nil }

        let overageStatus = h("anthropic-ratelimit-unified-overage-status")?.lowercased()
        let overageReason = h("anthropic-ratelimit-unified-overage-disabled-reason") ?? ""
        let credits: CreditsState
        switch overageStatus {
        case "allowed": credits = .allowed
        case "rejected": credits = .rejected(reason: overageReason)
        default: credits = .unknown
        }

        return LimitState(
            sessionUtilization: sess ?? 0,
            sessionResetAt: dateFromEpoch("anthropic-ratelimit-unified-5h-reset"),
            weeklyUtilization: week ?? 0,
            weeklyResetAt: dateFromEpoch("anthropic-ratelimit-unified-7d-reset"),
            credits: credits,
            fetchedAt: Date()
        )
    }
}
