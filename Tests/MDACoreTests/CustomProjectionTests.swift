import Foundation
import Testing
@testable import MDACore

@Suite struct CustomProjectionTests {
    private func day(_ year: Int, _ month: Int, _ day: Int) -> DateComponents {
        DateComponents(year: year, month: month, day: day)
    }

    @Test func baseDateIsEndOfDayInChosenTimeZone() throws {
        let central = try #require(CustomProjection(day: day(2026, 10, 18), timeZone: .central, miles: 1, weeklyGrowthPercent: 0))
        // Same instant Tesla stamps its figures with: 10/18/2026 23:59:59 CDT.
        #expect(central.baseDate == robotaxiStart)

        let eastern = try #require(CustomProjection(day: day(2026, 10, 18), timeZone: .eastern, miles: 1, weeklyGrowthPercent: 0))
        let pacific = try #require(CustomProjection(day: day(2026, 10, 18), timeZone: .pacific, miles: 1, weeklyGrowthPercent: 0))
        #expect(eastern.baseDate == robotaxiStart.addingTimeInterval(-3600))
        #expect(pacific.baseDate == robotaxiStart.addingTimeInterval(2 * 3600))
    }

    @Test func endOfDayFollowsDaylightSaving() throws {
        // 1/15/2027 23:59:59 CST = 1/16/2027 05:59:59Z.
        let winter = try #require(CustomProjection(day: day(2027, 1, 15), timeZone: .central, miles: 1, weeklyGrowthPercent: 0))
        #expect(winter.baseDate == ISO8601DateFormatter().date(from: "2027-01-16T05:59:59Z"))
    }

    @Test func matchesBaseMilesAtBaseDate() throws {
        let projection = try #require(CustomProjection(day: day(2026, 10, 18), timeZone: .central, miles: 3_000_000, weeklyGrowthPercent: 10))
        #expect(projection.miles(at: projection.baseDate) == 3_000_000)
    }

    @Test func compoundsWeekly() throws {
        let projection = try #require(CustomProjection(day: day(2026, 10, 18), timeZone: .central, miles: 1_000_000, weeklyGrowthPercent: 10))
        let week: TimeInterval = 7 * 86_400
        #expect(abs(projection.miles(at: projection.baseDate.addingTimeInterval(week)) - 1_100_000) < 1e-6)
        #expect(abs(projection.miles(at: projection.baseDate.addingTimeInterval(2 * week)) - 1_210_000) < 1e-6)
        // Half a week grows by sqrt(1.1), not by half of 10%.
        #expect(abs(projection.miles(at: projection.baseDate.addingTimeInterval(week / 2)) - 1_000_000 * 1.1.squareRoot()) < 1e-6)
    }

    @Test func rejectsInvalidInput() {
        #expect(CustomProjection(day: day(2026, 10, 18), timeZone: .central, miles: 0, weeklyGrowthPercent: 10) == nil)
        #expect(CustomProjection(day: day(2026, 10, 18), timeZone: .central, miles: 1_000, weeklyGrowthPercent: -100) == nil)
        #expect(CustomProjection(day: DateComponents(year: 2026), timeZone: .central, miles: 1_000, weeklyGrowthPercent: 10) == nil)
    }

    @Test func supersededOnlyWhenTeslaPublishesFigureNewerThanBase() throws {
        let projection = try #require(CustomProjection(day: day(2026, 10, 20), timeZone: .central, miles: 3_300_000, weeklyGrowthPercent: 10))
        let week: TimeInterval = 7 * 86_400
        func snapshot(_ start: Date, _ source: CounterSnapshot.Source = .formula) -> CounterSnapshot {
            CounterSnapshot(constants: CounterConstants(startMiles: 3_000_000, startDate: start, milesPerMillisecond: 0.001),
                            source: source, fetchedAt: start)
        }
        let old = snapshot(robotaxiStart)
        let newer = snapshot(robotaxiStart.addingTimeInterval(week))

        #expect(projection.isSuperseded(previous: old, fetched: newer))
        // Re-reading the same figure every day doesn't turn the projection off.
        #expect(!projection.isSuperseded(previous: old, fetched: old))
        // A new figure that is still older than the base date doesn't either.
        let olderBase = try #require(CustomProjection(day: day(2026, 11, 30), timeZone: .central, miles: 1, weeklyGrowthPercent: 0))
        #expect(!olderBase.isSuperseded(previous: old, fetched: newer))
        // A static-figure fallback is stamped with the fetch time, not a publish date.
        #expect(!projection.isSuperseded(previous: old, fetched: snapshot(robotaxiStart.addingTimeInterval(week), .staticFigure)))
        #expect(projection.isSuperseded(previous: nil, fetched: newer))
    }
}
