import AppKit
import Combine
import SwiftUI

/// Owns the `NSStatusItem` (recognizable calendar glyph + live countdown title)
/// and the `NSPopover` hosting the upcoming-events view. Left-click toggles the
/// popover; right-click (or control-click) shows an Open / Settings / Quit menu.
@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables: Set<AnyCancellable> = []
    private var lastProximity: StatusItemProximity?

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(
            rootView: UpcomingPopoverView()
                .environmentObject(model)
                .environmentObject(model.preferences)
                .environmentObject(model.calendarAccess)
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.toolTip = "Nudgebar"
        }

        model.$upcomingEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)

        model.ticker.$tickCount
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)

        refreshTitle()
    }

    func togglePopoverFromShortcut() {
        togglePopover()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if let event, event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu(for: event)
        } else {
            togglePopover()
        }
    }

    private func showMenu(for event: NSEvent) {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        menu.addItem(menuItem("Open Nudgebar", #selector(menuOpen)))
        menu.addItem(menuItem("Settings…", #selector(menuSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Nudgebar", #selector(menuQuit), key: "q"))
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func menuOpen() { togglePopover() }
    @objc private func menuSettings() { model.openSettingsAction?() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        model.refreshUpcoming()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func refreshTitle() {
        guard let button = statusItem.button else { return }
        let title = StatusItemTitleFormatter.title(for: model.nextUpcomingEvent, now: .now)
        button.title = title.text.isEmpty ? "" : " \(title.text)"
        if lastProximity != title.proximity {
            button.image = Self.glyph(for: title.proximity)
            lastProximity = title.proximity
        }
    }

    private static func glyph(for proximity: StatusItemProximity) -> NSImage? {
        let state: RingState
        switch proximity {
        case .none:
            state = .idle
        case .default, .warning:
            state = .active
        case .urgent:
            state = .urgent
        }
        return RingLogo.statusImage(state: state)
    }
}
