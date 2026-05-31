import NudgebarCore
import AppKit
import EventKit
import Foundation

public final class MacOSLifecycleObserver {
    public var onReason: ((LifecycleReconciliationReason) -> Void)?
    private var observers: [NSObjectProtocol] = []

    public init(notificationCenter: NotificationCenter = .default) {
        observers.append(
            notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onReason?(.wake)
            }
        )
        observers.append(
            notificationCenter.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onReason?(.displayConfigurationChanged)
            }
        )
        observers.append(
            notificationCenter.addObserver(
                forName: .EKEventStoreChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onReason?(.eventKitChanged)
            }
        )
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
