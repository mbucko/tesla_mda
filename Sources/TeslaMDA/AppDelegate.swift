import AppKit
import MDACore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let pageURL = ConstantsService.defaultPageURL
    /// How often to check whether the daily refresh is due (also retries failed refreshes).
    private static let refreshCheckInterval: TimeInterval = 60 * 60

    private let defaults = UserDefaults.standard
    private lazy var settings = AppSettings(defaults: defaults)
    private lazy var store = SnapshotStore(defaults: defaults)
    private lazy var controller = CounterController(service: ConstantsService(client: URLSessionHTTPClient()), store: store)
    private lazy var tracker = MilestoneTracker(lastCelebrated: store.lastCelebratedMillion)
    private let confetti = ConfettiOverlay()
    private lazy var settingsWindow = SettingsWindowController { [weak self] in self?.celebrate(force: true) }

    private var statusItem: NSStatusItem!
    private var timers: [Timer] = []
    private var renderedTitle: NSAttributedString?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults(in: defaults)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "car.fill", accessibilityDescription: "Robotaxi")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        controller.onChange = { [weak self] in self?.tick() }
        resyncMilestones()
        tick()
        controller.refreshIfDue()

        timers = [
            repeatingTimer(interval: 1) { $0.tick() },
            repeatingTimer(interval: Self.refreshCheckInterval) { $0.controller.refreshIfDue() },
        ]

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resyncMilestones()
                self?.controller.refreshIfDue()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func repeatingTimer(interval: TimeInterval, action: @escaping @MainActor @Sendable (AppDelegate) -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
        timer.tolerance = interval * 0.1
        // .common keeps the number ticking while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    // MARK: - Counter

    private func tick() {
        let miles = controller.miles(at: Date())
        updateStatusItem(miles: miles)
        if let miles, tracker.check(miles) != nil {
            store.lastCelebratedMillion = tracker.lastCelebrated
            celebrate(force: false)
        }
    }

    /// Millions passed while the app wasn't watching (not running, Mac asleep) are not celebrated.
    private func resyncMilestones() {
        guard let miles = controller.miles(at: Date()) else { return }
        tracker.syncSilently(to: miles)
        store.lastCelebratedMillion = tracker.lastCelebrated
    }

    private func celebrate(force: Bool) {
        guard force || settings.confettiEnabled,
              let button = statusItem.button, let window = button.window
        else { return }
        confetti.burst(from: window.convertToScreen(button.convert(button.bounds, to: nil)))
    }

    private func updateStatusItem(miles: Double?) {
        guard let button = statusItem.button else { return }

        let text: String
        if let miles {
            text = MilesFormatter(format: settings.displayFormat, showUnit: settings.showUnit).string(for: miles)
        } else {
            text = controller.isRefreshing ? "Loading…" : "—"
        }

        let title = NSAttributedString(string: text, attributes: [
            // Monospaced digits keep the item from changing width as the number ticks.
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .baselineOffset: -0.5,
        ])
        if title != renderedTitle {
            button.attributedTitle = title
            renderedTitle = title
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let now = Date()

        if let snapshot = controller.snapshot {
            let miles = snapshot.constants.miles(at: now)
            menu.addItem(info("\(MilesFormatter.fullNumber(miles)) miles driven autonomously"))
            if snapshot.source == .formula {
                menu.addItem(info("Tesla figure as of \(Self.asOfFormatter.string(from: snapshot.constants.startDate))"))
                menu.addItem(info("Estimated rate: \(MilesFormatter.fullNumber(snapshot.constants.milesPerDay)) mi/day"))
            }
            menu.addItem(info("Updated \(snapshot.fetchedAt.formatted(.relative(presentation: .named, unitsStyle: .wide)))"))
        } else {
            menu.addItem(info(controller.isRefreshing ? "Loading Tesla data…" : "No data yet"))
        }
        if let error = controller.lastError {
            menu.addItem(info("⚠︎ \(error)"))
        }

        menu.addItem(.separator())
        let refresh = item(controller.isRefreshing ? "Refreshing…" : "Refresh Now", #selector(refreshNow), key: "r")
        refresh.isEnabled = !controller.isRefreshing
        menu.addItem(refresh)
        menu.addItem(item("Open Tesla Safety Page", #selector(openPage)))
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit", #selector(quit), key: "q"))
    }

    /// Tesla's figures are stamped 23:59:59 Central Time.
    private static let asOfFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        return formatter
    }()

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func refreshNow() { controller.refresh() }
    @objc private func openPage() { NSWorkspace.shared.open(Self.pageURL) }
    @objc private func openSettings() { settingsWindow.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
