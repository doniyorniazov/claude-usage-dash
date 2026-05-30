import Foundation

enum CreditsState: Equatable {
    case allowed                   // overage requests are accepted (you have credits or no cap)
    case rejected(reason: String)  // overage blocked — e.g. out_of_credits
    case unknown
}

struct LimitState: Equatable {
    var sessionUtilization: Double      // 0.0...1.0+, the 5h window
    var sessionResetAt: Date?
    var weeklyUtilization: Double       // 0.0...1.0+, the 7d window
    var weeklyResetAt: Date?
    var credits: CreditsState
    var fetchedAt: Date

    static let unknown = LimitState(
        sessionUtilization: 0, sessionResetAt: nil,
        weeklyUtilization: 0, weeklyResetAt: nil,
        credits: .unknown, fetchedAt: .distantPast
    )

    /// The number we show in the menu bar — whichever window is more depleted.
    var representativeUtilization: Double {
        max(sessionUtilization, weeklyUtilization)
    }
}
