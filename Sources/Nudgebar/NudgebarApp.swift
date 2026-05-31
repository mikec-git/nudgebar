import AppKit
import Combine
import SwiftUI

@main
struct NudgebarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItemController: StatusItemController?
    private let shortcuts = GlobalShortcuts()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.start()
        statusItemController = StatusItemController(model: model)

        configureShortcuts()
        model.preferences.$shortcuts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.configureShortcuts() }
            .store(in: &cancellables)
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
