import Foundation

struct PlanInfo: Equatable {
    let displayName: String   // "Claude Max 5×"
    let email: String?
    let isActive: Bool
}

/// Hits the cheap, unrestricted `/api/oauth/profile` endpoint to learn
/// what plan the user is on. Plan info changes rarely — fetch once at launch.
enum ProfileFetcher {
    static func fetch() async throws -> PlanInfo {
        let creds = try CredentialsCache.current()

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/profile")!)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw ProbeError.http((resp as? HTTPURLResponse)?.statusCode ?? -1,
                                  String(data: data, encoding: .utf8) ?? "")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let account = json["account"] as? [String: Any] ?? [:]
        let org = json["organization"] as? [String: Any] ?? [:]
        let tier = org["rate_limit_tier"] as? String ?? ""
        let orgType = org["organization_type"] as? String ?? ""
        let status = org["subscription_status"] as? String ?? "active"

        return PlanInfo(
            displayName: prettyTier(tier: tier, orgType: orgType),
            email: account["email"] as? String,
            isActive: status == "active"
        )
    }

    private static func prettyTier(tier: String, orgType: String) -> String {
        // Known: default_claude_max_5x, default_claude_max_20x, default_claude_pro,
        //        default_api_tier_*, default_team, default_enterprise.
        let t = tier.lowercased()
        if t.contains("claude_max_20x") { return "Claude Max 20×" }
        if t.contains("claude_max_5x")  { return "Claude Max 5×" }
        if t.contains("claude_max")     { return "Claude Max" }
        if t.contains("claude_pro")     { return "Claude Pro" }
        if t.contains("team")           { return "Claude Team" }
        if t.contains("enterprise")     { return "Claude Enterprise" }
        if t.contains("api")            { return "API" }
        // Last-ditch: title-case the org type.
        return orgType
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
