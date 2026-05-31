import AppKit
import Combine
import SwiftUI

@main
struct NudgebarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Real settings are shown via an AppDelegate-owned window (reliable for an
        // accessory app); this placeholder satisfies the App scene requirement.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItemController: StatusItemController?
    private var settingsWindow: NSWindow?
    private let shortcuts = GlobalShortcuts()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.openSettingsAction = { [weak self] in self?.openSettings() }
        model.start()
        statusItemController = StatusItemController(model: model)

        configureShortcuts()
        model.preferences.$shortcuts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.configureShortcuts() }
            .store(in: &cancellables)
    }

    func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView().environmentObject(model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Nudgebar Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func configureShortcuts() {
        var bindings: [ShortcutAction: ShortcutBinding] = [:]
        for action in ShortcutAction.allCases {
            if let binding = model.preferences.shortcut(for: action) {
                bindings[action] = binding
            }
        }
        shortcuts.configure(
            bindings: bindings,
            handlers: [
                .snoozeAll: { [weak self] in self?.model.snoozeAllAlerts() },
                .dismissAll: { [weak self] in self?.model.dismissAllAlerts() },
                .openPopover: { [weak self] in self?.statusItemController?.togglePopoverFromShortcut() }
            ]
        )
    }
}
