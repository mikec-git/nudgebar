import AppKit
import Combine
import Foundation

enum ShortcutAction: String, CaseIterable, Sendable {
    case snoozeAll
    case dismissAll
    case openPopover

    var title: String {
        switch self {
        case .snoozeAll: return "Snooze All"
        case .dismissAll: return "Dismiss All"
        case .openPopover: return "Open Popover"
        }
    }
}

struct ShortcutBinding: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifierFlags: UInt
    var displayKey: String

    func matches(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        self.keyCode == keyCode && self.modifierFlags == modifiers.rawValue
    }

    var displayString: String {
        let modifiers = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + displayKey
    }

    static func conflicts(
        _ binding: ShortcutBinding,
        in bindings: [String: ShortcutBinding],
        excluding action: ShortcutAction
    ) -> Bool {
        bindings.contains { key, value in
            key != action.rawValue
                && value.keyCode == binding.keyCode
                && value.modifierFlags == binding.modifierFlags
        }
    }
}

/// Registers global + local key monitors for the bound actions. Global monitoring
/// requires Accessibility permission; the local monitor covers in-app key events.
@MainActor
final class GlobalShortcuts {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var bindings: [ShortcutAction: ShortcutBinding] = [:]
    private var handlers: [ShortcutAction: () -> Void] = [:]

    func configure(bindings: [ShortcutAction: ShortcutBinding], handlers: [ShortcutAction: () -> Void]) {
        self.bindings = bindings
        self.handlers = handlers
        restart()
    }

    private func restart() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            (self?.handle(event) ?? false) ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        for (action, binding) in bindings where binding.matches(keyCode: event.keyCode, modifiers: modifiers) {
            handlers[action]?()
            return true
        }
        return false
    }

    private func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}

/// Captures the next modifier+key combination for the Settings shortcut editor.
@MainActor
final class ShortcutRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    private var monitor: Any?
    private var onCapture: ((ShortcutBinding) -> Void)?

    func record(onCapture: @escaping (ShortcutBinding) -> Void) {
        stop()
        self.onCapture = onCapture
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !modifiers.isEmpty else {
                return nil // require at least one modifier; ignore bare keys
            }
            let key = (event.charactersIgnoringModifiers ?? "").uppercased()
            let binding = ShortcutBinding(
                keyCode: event.keyCode,
                modifierFlags: modifiers.rawValue,
                displayKey: key.isEmpty ? "?" : key
            )
            self.onCapture?(binding)
            self.stop()
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        onCapture = nil
        isRecording = false
    }
}
