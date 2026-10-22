import Testing
@testable import MDACore

@Suite struct MilestoneTrackerTests {
    @Test func reportsMillionWhenCrossedLive() {
        var tracker = MilestoneTracker(lastCelebrated: 0)
        tracker.syncSilently(to: 3_999_998)
        #expect(tracker.check(3_999_999) == nil)
        #expect(tracker.check(4_000_000) == 4)
        #expect(tracker.check(4_000_001) == nil)
    }

    @Test func syncSkipsMillionsPassedWhileNotWatching() {
        var tracker = MilestoneTracker(lastCelebrated: 3)
        tracker.syncSilently(to: 5_200_000)
        #expect(tracker.lastCelebrated == 5)
        #expect(tracker.check(5_300_000) == nil)
    }

    @Test func doesNotRepeatAfterDownwardRevision() {
        var tracker = MilestoneTracker(lastCelebrated: 4)
        tracker.syncSilently(to: 3_990_000)
        #expect(tracker.lastCelebrated == 4)
        #expect(tracker.check(4_000_100) == nil)
    }
}
