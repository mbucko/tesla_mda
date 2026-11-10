import Foundation
import MDACore

/// UserDefaults keys shared by the settings UI (@AppStorage) and the status item.
enum SettingsKey {
    static let displayFormat = "displayFormat"
    static let showUnit = "showUnit"
    static let confettiEnabled = "confettiEnabled"
    static let projectionEnabled = "projectionEnabled"
    /// The picked calendar day as a `Date` (seconds since reference date); only its local y/m/d is used.
    static let projectionDay = "projectionDay"
    static let projectionTimeZone = "projectionTimeZone"
    static let projectionMiles = "projectionMiles"
    static let projectionWeeklyGrowthPercent = "projectionWeeklyGrowthPercent"
}

extension DisplayFormat {
    var label: String {
        switch self {
        case .compact2: "3.35M"
        case .compact3: "3.351M"
        case .full: "3,351,066"
        }
    }
}

struct AppSettings {
    let defaults: UserDefaults

    static func registerDefaults(in defaults: UserDefaults) {
        defaults.register(defaults: [
            SettingsKey.displayFormat: DisplayFormat.compact2.rawValue,
            SettingsKey.showUnit: false,
            SettingsKey.confettiEnabled: true,
            SettingsKey.projectionEnabled: false,
            SettingsKey.projectionTimeZone: ProjectionTimeZone.central.rawValue,
        ])
    }

    var displayFormat: DisplayFormat {
        defaults.string(forKey: SettingsKey.displayFormat).flatMap(DisplayFormat.init) ?? .compact2
    }

    var showUnit: Bool { defaults.bool(forKey: SettingsKey.showUnit) }
    var confettiEnabled: Bool { defaults.bool(forKey: SettingsKey.confettiEnabled) }

    /// The custom projection when it's switched on and its inputs are valid; otherwise Tesla's formula is used.
    var customProjection: CustomProjection? {
        guard defaults.bool(forKey: SettingsKey.projectionEnabled),
              defaults.object(forKey: SettingsKey.projectionDay) != nil
        else { return nil }
        let pickedDay = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: SettingsKey.projectionDay))
        return CustomProjection(
            day: Calendar.current.dateComponents([.year, .month, .day], from: pickedDay),
            timeZone: defaults.string(forKey: SettingsKey.projectionTimeZone).flatMap(ProjectionTimeZone.init) ?? .central,
            miles: defaults.double(forKey: SettingsKey.projectionMiles),
            weeklyGrowthPercent: defaults.double(forKey: SettingsKey.projectionWeeklyGrowthPercent))
    }

    func disableCustomProjection() {
        defaults.set(false, forKey: SettingsKey.projectionEnabled)
    }
}
