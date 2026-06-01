import AppKit
import Combine
import SwiftUI

@main
struct NudgebarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Real settings/about are shown via AppDelegate-owned windows (reliable for
        // an accessory app); the Settings scene satisfies the App requirement and
        // the command override points "About" at our own window.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appInfo) {
                    Button("About \(AppInfo.name)") { appDelegate.showAbout() }
                }
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let model = AppModel()
    private var statusItemController: StatusItemController?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private let shortcuts = GlobalShortcuts()
    private var cancellables: Set<AnyCancellable> = []
    private weak var hostAppMenuDelegate: NSMenuDelegate?

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
            window.backgroundColor = Brand.inkNSColor
            window.appearance = NSAppearance(named: .darkAqua)
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        present(settingsWindow)
    }

    func showAbout() {
        if aboutWindow == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "About \(AppInfo.name)"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.backgroundColor = Brand.inkNSColor
            window.appearance = NSAppearance(named: .darkAqua)
            window.delegate = self
            window.center()
            aboutWindow = window
        }
        present(aboutWindow)
    }

    /// Bring a window forward and become a regular app so the "Nudgebar" menu bar
    /// (and text-field copy/paste) is available; revert to accessory when closed.
    private func present(_ window: NSWindow?) {
        let needsPolicySwitch = NSApp.activationPolicy() != .regular
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        guard needsPolicySwitch else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // Documented macOS bug (FB7743313): switching .accessory -> .regular doesn't
        // let the menu bar adopt our menu until the change propagates, so activating
        // immediately leaves the launching app's menu up until a manual refocus. Wait
        // a beat, then activate, so "Nudgebar" shows in the bar on first open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        installAppMenuTidy()
    }

    /// Become the app menu's delegate so we can strip Services and retarget the
    /// About / Settings items every time it opens - reliable no matter when SwiftUI
    /// (re)builds the menu, which one-shot cleanup on activation kept racing.
    private func installAppMenuTidy() {
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }
        if appMenu.delegate !== self {
            hostAppMenuDelegate = appMenu.delegate
            appMenu.delegate = self
        }
        tidyAppMenu(appMenu)
    }

    private func tidyAppMenu(_ menu: NSMenu) {
        // Drop the unused Services submenu. Match by title or by the live services
        // menu identity, never by a nil submenu (which would catch About/Hide/Quit).
        let services = NSApp.servicesMenu
        if let item = menu.items.first(where: {
            $0.title == "Services" || ($0.submenu != nil && $0.submenu === services)
        }) {
            menu.removeItem(item)
        }
        NSApp.servicesMenu = nil

        // "About Nudgebar" opens our branded window.
        if let about = menu.items.first(where: {
            $0.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:)) || $0.title.hasPrefix("About")
        }) {
            about.target = self
            about.action = #selector(aboutMenuAction)
            about.title = "About \(AppInfo.name)"
        }
        // "Settings…" (⌘,) opens our real window instead of the empty placeholder
        // scene; when it's already open, openSettings just refocuses it (no-op).
        if let settings = menu.items.first(where: {
            let selector = $0.action.map(NSStringFromSelector) ?? ""
            return selector.contains("Settings") || selector.contains("Preferences")
                || $0.title.hasPrefix("Settings") || $0.title.hasPrefix("Preferences")
        }) {
            settings.target = self
            settings.action = #selector(settingsMenuAction)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        hostAppMenuDelegate?.menuNeedsUpdate?(menu)
        tidyAppMenu(menu)
    }

    @objc private func aboutMenuAction() { showAbout() }
    @objc private func settingsMenuAction() { openSettings() }

    func windowWillClose(_ notification: Notification) {
        // Once no Nudgebar window remains, drop back to a pure menu-bar app.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let anyVisible = [self.settingsWindow, self.aboutWindow].contains { $0?.isVisible == true }
            if !anyVisible { NSApp.setActivationPolicy(.accessory) }
        }
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

/// Custom About window contents - renders our logo, version, release date, and a
/// GitHub link (the standard about panel wouldn't show our branding reliably).
struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Brand.inkDeep)
                RingLogo(state: .urgent).frame(width: 68, height: 68)
            }
            .frame(width: 104, height: 104)
            Wordmark(size: 26)
            Text("Version \(AppInfo.version)").font(Brand.font(13)).foregroundStyle(Brand.sand)
            Text("Released \(AppInfo.releaseDate)").font(Brand.font(12)).foregroundStyle(Brand.stone)
            Button {
                if let url = URL(string: AppInfo.repoURL) { NSWorkspace.shared.open(url) }
            } label: {
                Label("View on GitHub", systemImage: "arrow.up.forward.square")
                    .font(Brand.font(13, .semibold)).foregroundStyle(Brand.blush)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(28)
        .frame(width: 320)
        .background(Brand.ink)
        .environment(\.colorScheme, .dark)
    }
}
