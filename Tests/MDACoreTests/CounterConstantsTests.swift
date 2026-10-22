import Foundation
import Testing
@testable import MDACore

@Suite struct CounterConstantsTests {
    let constants = CounterConstants(startMiles: 3_112_541, startDate: robotaxiStart, milesPerMillisecond: 0.0009221)

    @Test func matchesStartAtStartDate() {
        #expect(constants.miles(at: robotaxiStart) == 3_112_541)
    }

    @Test func extrapolatesAtTeslaRate() {
        let oneDayLater = robotaxiStart.addingTimeInterval(86_400)
        #expect(abs(constants.miles(at: oneDayLater) - 3_192_210.44) < 0.001)
        #expect(constants.milesPerDay.rounded() == 79_669)
    }

    @Test func newFormulaReplacesStartAndRateTogether() {
        let old = CounterSnapshot(constants: constants, source: .formula, fetchedAt: robotaxiStart)
        let updated = CounterConstants(startMiles: 3_700_000, startDate: robotaxiStart.addingTimeInterval(604_800), milesPerMillisecond: 0.0012)
        let fetched = CounterSnapshot(constants: updated, source: .formula, fetchedAt: robotaxiStart.addingTimeInterval(700_000))
        #expect(CounterSnapshot.resolve(current: old, fetched: fetched) == fetched)
    }

    @Test func staticFallbackDoesNotReplaceWorkingFormula() {
        let old = CounterSnapshot(constants: constants, source: .formula, fetchedAt: robotaxiStart)
        let fallback = CounterSnapshot(
            constants: CounterConstants(startMiles: 3_700_000, startDate: robotaxiStart, milesPerMillisecond: 0),
            source: .staticFigure, fetchedAt: robotaxiStart.addingTimeInterval(86_400))
        #expect(CounterSnapshot.resolve(current: old, fetched: fallback) == old)
        #expect(CounterSnapshot.resolve(current: nil, fetched: fallback) == fallback)
    }

    @Test func refreshIsDueAfterInterval() {
        let snapshot = CounterSnapshot(constants: constants, source: .formula, fetchedAt: robotaxiStart)
        #expect(!snapshot.isRefreshDue(now: robotaxiStart.addingTimeInterval(3600), interval: 86_400))
        #expect(snapshot.isRefreshDue(now: robotaxiStart.addingTimeInterval(86_400), interval: 86_400))
    }

    @Test func storeRoundTripsSnapshotAndMilestone() throws {
        let suite = "MDACoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SnapshotStore(defaults: defaults)
        #expect(store.loadSnapshot() == nil)

        let snapshot = CounterSnapshot(constants: constants, source: .formula, fetchedAt: robotaxiStart)
        store.save(snapshot)
        store.lastCelebratedMillion = 3
        #expect(store.loadSnapshot() == snapshot)
        #expect(SnapshotStore(defaults: defaults).lastCelebratedMillion == 3)
    }
}
