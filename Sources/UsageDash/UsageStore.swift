import Foundation
import Combine

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var state: LimitState = .unknown
    @Published private(set) var plan: PlanInfo? = nil
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastError: String? = nil

    /// How often to probe in the background. The unified rate-limit headers update
    /// every request, so we just need a heartbeat — 5 min is cheap and responsive.
    @Published var refreshIntervalSeconds: Double {
        didSet {
            UserDefaults.standard.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds")
            restartTimer()
        }
    }

    private var timer: Timer?

    init() {
        let stored = UserDefaults.standard.object(forKey: "refreshIntervalSeconds") as? Double
        self.refreshIntervalSeconds = stored ?? 300
    }

    func start() {
        refresh()
        fetchPlan()
        restartTimer()
    }

    private func fetchPlan() {
        Task {
            if let p = try? await ProfileFetcher.fetch() {
                await MainActor.run { self.plan = p }
            }
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshIntervalSeconds, repeats: true) { [weak self] _ in
            // Strict-concurrency: capture into an immutable so the inner Task
            // doesn't re-capture the `var self` from the weak-self binding.
            let store = self
            Task { @MainActor in store?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            do {
                let s = try await UsageProbe.fetch()
                await MainActor.run {
                    self.state = s
                    self.lastError = nil
                    self.isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                    self.isRefreshing = false
                }
            }
        }
    }
}
