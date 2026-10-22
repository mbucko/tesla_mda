import AppKit
import MDACore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.displayFormat) private var displayFormat = DisplayFormat.compact2
    @AppStorage(SettingsKey.showUnit) private var showUnit = false
    @AppStorage(SettingsKey.confettiEnabled) private var confettiEnabled = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    let previewConfetti: () -> Void

    var body: some View {
        Form {
            Section("Menu Bar") {
                Picker("Number", selection: $displayFormat) {
                    ForEach(DisplayFormat.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Toggle("Show \"mi\" after the number", isOn: $showUnit)
            }
            Section("Milestones") {
                Toggle("Confetti when a new million is passed", isOn: $confettiEnabled)
                Button("Preview Confetti", action: previewConfetti)
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchAtLoginError {
                    Text(launchAtLoginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let isEnabled = SMAppService.mainApp.status == .enabled
        guard enabled != isEnabled else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin = isEnabled
        }
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let previewConfetti: () -> Void

    init(previewConfetti: @escaping () -> Void) {
        self.previewConfetti = previewConfetti
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(previewConfetti: previewConfetti)))
            window.title = "Tesla MDA Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            // Open on the current Space instead of switching to the one it was last shown on.
            window.collectionBehavior = [.moveToActiveSpace]
            window.center()
            self.window = window
        }
        // A menu bar (accessory) app is never frontmost, and macOS may decline NSApp.activate(),
        // which left the window behind other apps. orderFrontRegardless raises it either way.
        window?.orderFrontRegardless()
        window?.makeKey()
        NSApp.activate()
    }
}
