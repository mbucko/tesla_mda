import Foundation

/// The three values tesla.com uses to extrapolate the "Miles Driven Autonomously" counter.
///
/// The page does not stream live data: it publishes a weekly figure and a rate, and its
/// JavaScript computes `start + (now - startDate) * rate`. We reproduce that formula locally.
public struct CounterConstants: Codable, Equatable, Sendable {
    public var startMiles: Double
    public var startDate: Date
    public var milesPerMillisecond: Double

    public init(startMiles: Double, startDate: Date, milesPerMillisecond: Double) {
        self.startMiles = startMiles
        self.startDate = startDate
        self.milesPerMillisecond = milesPerMillisecond
    }

    public func miles(at date: Date) -> Double {
        let elapsedMilliseconds = date.timeIntervalSince(startDate) * 1000
        return startMiles + elapsedMilliseconds * milesPerMillisecond
    }

    public var milesPerDay: Double {
        milesPerMillisecond * 86_400_000
    }
}

/// Constants plus where they came from and when they were fetched.
public struct CounterSnapshot: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// Start, date and rate read from Tesla's counter script; the number ticks.
        case formula
        /// Only the static number in the page HTML could be read; the number does not tick.
        case staticFigure
    }

    public var constants: CounterConstants
    public var source: Source
    public var fetchedAt: Date

    public init(constants: CounterConstants, source: Source, fetchedAt: Date) {
        self.constants = constants
        self.source = source
        self.fetchedAt = fetchedAt
    }

    public func isRefreshDue(now: Date, interval: TimeInterval) -> Bool {
        now.timeIntervalSince(fetchedAt) >= interval
    }
}

extension CounterSnapshot {
    /// Decides which snapshot to keep after a refresh.
    ///
    /// Start, date and rate are always replaced together, because Tesla updates them together;
    /// mixing a new start with an old rate would jump the count. A static-figure fallback never
    /// replaces a working formula: the formula keeps ticking and the failure is reported instead.
    public static func resolve(current: CounterSnapshot?, fetched: CounterSnapshot) -> CounterSnapshot {
        if fetched.source == .staticFigure, let current, current.source == .formula {
            return current
        }
        return fetched
    }
}
