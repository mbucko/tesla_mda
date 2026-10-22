/// Detects when the counter passes a whole million while the app is watching.
///
/// Milestones that pass while the app isn't watching (not running, Mac asleep) are skipped:
/// call `syncSilently(to:)` whenever watching resumes.
public struct MilestoneTracker: Sendable {
    public private(set) var lastCelebrated: Int

    public init(lastCelebrated: Int) {
        self.lastCelebrated = lastCelebrated
    }

    /// Advances past any millions already reached without reporting them.
    public mutating func syncSilently(to miles: Double) {
        lastCelebrated = max(lastCelebrated, Self.millions(in: miles))
    }

    /// Returns the million just passed (e.g. 4 for 4,000,000), or nil.
    /// Each million is reported at most once, even if the figure is later revised down and back up.
    public mutating func check(_ miles: Double) -> Int? {
        let current = Self.millions(in: miles)
        guard current > lastCelebrated else { return nil }
        lastCelebrated = current
        return current
    }

    private static func millions(in miles: Double) -> Int {
        Int((miles / 1_000_000).rounded(.down))
    }
}
