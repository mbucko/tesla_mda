import Foundation

public enum DisplayFormat: String, CaseIterable, Sendable {
    /// 3.35M
    case compact2
    /// 3.351M
    case compact3
    /// 3,351,066
    case full
}

public struct MilesFormatter: Sendable {
    public var format: DisplayFormat
    public var showUnit: Bool
    public var locale: Locale

    public init(format: DisplayFormat, showUnit: Bool = false, locale: Locale = .current) {
        self.format = format
        self.showUnit = showUnit
        self.locale = locale
    }

    public func string(for miles: Double) -> String {
        let number = switch format {
        case .compact2: compact(miles, fractionDigits: 2)
        case .compact3: compact(miles, fractionDigits: 3)
        case .full: Self.fullNumber(miles, locale: locale)
        }
        return showUnit ? "\(number) mi" : number
    }

    public static func fullNumber(_ miles: Double, locale: Locale = .current) -> String {
        Int(miles.rounded(.down)).formatted(.number.locale(locale))
    }

    /// Truncates rather than rounds, so "4.00M" never shows before 4,000,000 is actually reached.
    private func compact(_ miles: Double, fractionDigits: Int) -> String {
        let (divisor, suffix): (Double, String) = switch miles {
        case 1_000_000_000...: (1_000_000_000, "B")
        case 1_000_000...: (1_000_000, "M")
        case 1_000...: (1_000, "K")
        default: (1, "")
        }
        let scale = pow(10, Double(fractionDigits))
        let truncated = (miles / divisor * scale).rounded(.down) / scale
        let digits = suffix.isEmpty ? 0 : fractionDigits
        let style = FloatingPointFormatStyle<Double>.number
            .locale(locale)
            .precision(.fractionLength(digits))
            .grouping(.never)
        return truncated.formatted(style) + suffix
    }
}
