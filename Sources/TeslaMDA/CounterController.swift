import Foundation
import MDACore

/// Owns the counter data: loads the saved snapshot, refreshes it from tesla.com once a day,
/// and computes the current figure from it.
@MainActor
final class CounterController {
    static let refreshInterval: TimeInterval = 24 * 60 * 60

    private(set) var snapshot: CounterSnapshot?
    private(set) var lastError: String?
    private(set) var isRefreshing = false
    var onChange: (() -> Void)?

    private let service: ConstantsService
    private let store: SnapshotStore

    init(service: ConstantsService, store: SnapshotStore) {
        self.service = service
        self.store = store
        snapshot = store.loadSnapshot()
    }

    func miles(at date: Date) -> Double? {
        snapshot?.constants.miles(at: date)
    }

    func refreshIfDue(now: Date = Date()) {
        guard snapshot?.isRefreshDue(now: now, interval: Self.refreshInterval) ?? true else { return }
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        onChange?()
        Task {
            await performRefresh()
            isRefreshing = false
            onChange?()
        }
    }

    private func performRefresh() async {
        do {
            let fetched = try await service.fetchSnapshot()
            let resolved = CounterSnapshot.resolve(current: snapshot, fetched: fetched)
            if resolved == fetched {
                snapshot = fetched
                store.save(fetched)
                lastError = fetched.source == .staticFigure
                    ? "Couldn't read Tesla's counter formula; showing the static figure"
                    : nil
            } else {
                lastError = "Couldn't read Tesla's counter formula; still using the last one"
            }
        } catch {
            lastError = "Refresh failed: \(error.localizedDescription)"
        }
    }
}
