import AppKit
import Combine
import SwiftUI

/// Owns the `NSStatusItem` (live title + monochrome proximity glyph) and the
/// `NSPopover` hosting the upcoming-events view. Replaces `MenuBarExtra` so the
/// title can be a live-bound string and the popover anchor is a real button.
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
        popover.contentViewController = NSHostingController(
            rootView: UpcomingPopoverView()
                .environmentObject(model)
                .environmentObject(model.preferences)
                .environmentObject(model.calendarAccess)
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.imagePosition = .imageLeading
        }

        // Refresh the title when the upcoming list changes or the countdown ticks.
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

    private func refreshTitle() {
        guard let button = statusItem.button else {
            return
        }

        let title = StatusItemTitleFormatter.title(for: model.nextUpcomingEvent, now: .now)
        // A leading space separates the glyph from the text when a title is present.
        button.title = title.text.isEmpty ? "" : " \(title.text)"

        if lastProximity != title.proximity {
            button.image = StatusItemDotImage.image(for: title.proximity)
            lastProximity = title.proximity
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        model.refreshUpcoming()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
