import NudgebarCore
import AppKit
import SwiftUI

@MainActor
final class AlertPresenter: ObservableObject {
    private var windows: [NSWindow] = []

    func present(event: AlertCandidate, fullScreen: Bool) {
        if fullScreen {
            presentFullScreen(event: event)
        } else {
            presentPanel(event: event)
        }
    }

    private func presentPanel(event: AlertCandidate) {
        let alert = NSAlert()
        alert.messageText = event.title
        alert.informativeText = eventSubtitle(for: event)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Dismiss")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentFullScreen(event: AlertCandidate) {
        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens

        for screen in screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.backgroundColor = .windowBackgroundColor
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.level = .screenSaver

            window.contentView = NSHostingView(
                rootView: FullScreenAlertView(event: event) { [weak self, weak window] in
                    guard let window else {
                        return
                    }

                    window.orderOut(nil)
                    window.close()
                    self?.windows.removeAll { $0 === window }
                }
            )

            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func eventSubtitle(for event: AlertCandidate) -> String {
        var parts = [
            event.startDate.formatted(date: .abbreviated, time: .shortened),
            event.calendarTitle
        ]

        if let location = event.location, !location.isEmpty {
            parts.append(location)
        }

        return parts.joined(separator: "\n")
    }
}

private struct FullScreenAlertView: View {
    let event: AlertCandidate
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Calendar Alert")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(event.title)
                    .font(.system(size: 72, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.45)
                    .padding(.horizontal, 56)

                VStack(spacing: 8) {
                    Text(event.startDate.formatted(date: .complete, time: .shortened))
                        .font(.system(size: 30, weight: .medium))

                    Text(event.calendarTitle)
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)

                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Dismiss", action: dismiss)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .padding(.top, 16)
            }
            .padding(48)
        }
    }
}
