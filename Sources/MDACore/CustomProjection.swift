import Foundation

/// US time zones a custom base date can be anchored to.
public enum ProjectionTimeZone: String, CaseIterable, Sendable {
    case eastern = "ET"
    case central = "CT"
    case pacific = "PT"

    public var timeZone: TimeZone {
        switch self {
        case .eastern: TimeZone(identifier: "America/New_York")!
        case .central: TimeZone(identifier: "America/Chicago")!
        case .pacific: TimeZone(identifier: "America/Los_Angeles")!
        }
    }
}

/// A user-supplied base figure projected forward at a compounding weekly growth rate,
/// used instead of Tesla's linear formula.
public struct CustomProjection: Equatable, Sendable {
    private static let week: TimeInterval = 7 * 86_400

    public let baseMiles: Double
    /// 23:59:59 on the chosen day in the chosen time zone, matching how Tesla stamps its figures.
    public let baseDate: Date
    /// 0.1 = 10% per week.
    public let weeklyGrowth: Double
    public let timeZone: ProjectionTimeZone

    /// Returns nil when the day is incomplete, miles aren't positive, or growth is -100% or lower.
    public init?(day: DateComponents, timeZone: ProjectionTimeZone, miles: Double, weeklyGrowthPercent: Double) {
        guard miles > 0, weeklyGrowthPercent > -100,
              let year = day.year, let month = day.month, let dayOfMonth = day.day
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone.timeZone
        guard let endOfDay = calendar.date(from: DateComponents(
            year: year, month: month, day: dayOfMonth, hour: 23, minute: 59, second: 59))
        else { return nil }

        baseMiles = miles
        baseDate = endOfDay
        weeklyGrowth = weeklyGrowthPercent / 100
        self.timeZone = timeZone
    }

    public func miles(at date: Date) -> Double {
        baseMiles * pow(1 + weeklyGrowth, date.timeIntervalSince(baseDate) / Self.week)
    }

    /// True when a refresh brought a newly published Tesla figure dated after this projection's base.
    /// Static-figure fallbacks don't count: their date is the fetch time, not a publish date.
    public func isSuperseded(previous: CounterSnapshot?, fetched: CounterSnapshot) -> Bool {
        guard fetched.source == .formula else { return false }
        let published = fetched.constants.startDate
        let isNewFigure = previous.map { published > $0.constants.startDate } ?? true
        return isNewFigure && published > baseDate
    }
}
