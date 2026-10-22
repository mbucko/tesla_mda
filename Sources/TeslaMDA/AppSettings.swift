import Foundation
import MDACore

/// UserDefaults keys shared by the settings UI (@AppStorage) and the status item.
enum SettingsKey {
    static let displayFormat = "displayFormat"
    static let showUnit = "showUnit"
    static let confettiEnabled = "confettiEnabled"
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
        ])
    }

    var displayFormat: DisplayFormat {
        defaults.string(forKey: SettingsKey.displayFormat).flatMap(DisplayFormat.init) ?? .compact2
    }

    var showUnit: Bool { defaults.bool(forKey: SettingsKey.showUnit) }
    var confettiEnabled: Bool { defaults.bool(forKey: SettingsKey.confettiEnabled) }
}
