import AppKit
import Foundation

enum GestureKind: Int, CaseIterable {
    case threeFingerClick = 0
    case fourFingerClick = 1
    case threeFingerTouch = 2
    case fourFingerTouch = 3

    static let visibleOrder: [GestureKind] = [
        .threeFingerClick,
        .fourFingerClick,
        .threeFingerTouch,
        .fourFingerTouch,
    ]

    var title: String {
        switch self {
        case .threeFingerClick:
            return "3-Finger Click"
        case .fourFingerClick:
            return "4-Finger Click"
        case .threeFingerTouch:
            return "3-Finger Touch"
        case .fourFingerTouch:
            return "4-Finger Touch"
        }
    }

    var shortTitle: String {
        switch self {
        case .threeFingerClick:
            return "3-Finger Click"
        case .fourFingerClick:
            return "4-Finger Click"
        case .threeFingerTouch:
            return "3-Finger Touch"
        case .fourFingerTouch:
            return "4-Finger Touch"
        }
    }

    var subtitle: String {
        switch self {
        case .threeFingerClick:
            return "Press three fingers to trigger a remapped click."
        case .fourFingerClick:
            return "Reserve a four-finger press for a secondary shortcut."
        case .threeFingerTouch:
            return "Lightly rest three fingers without clicking."
        case .fourFingerTouch:
            return "Use a four-finger touch as a separate gesture layer."
        }
    }

    var symbolName: String {
        switch self {
        case .threeFingerClick:
            return "cursorarrow.click"
        case .fourFingerClick:
            return "cursorarrow.click.2"
        case .threeFingerTouch:
            return "hand.tap"
        case .fourFingerTouch:
            return "hand.tap.fill"
        }
    }

    var interactionLabel: String {
        isTouchGesture ? "Touch" : "Click"
    }

    var fingerCount: Int {
        switch self {
        case .threeFingerClick:
            return 3
        case .fourFingerClick:
            return 4
        case .threeFingerTouch:
            return 3
        case .fourFingerTouch:
            return 4
        }
    }

    var isTouchGesture: Bool {
        switch self {
        case .threeFingerTouch, .fourFingerTouch:
            return true
        case .threeFingerClick, .fourFingerClick:
            return false
        }
    }

    var pairedClickGesture: GestureKind {
        switch self {
        case .threeFingerClick, .threeFingerTouch:
            return .threeFingerClick
        case .fourFingerClick, .fourFingerTouch:
            return .fourFingerClick
        }
    }

    var defaultsKey: String {
        "gesture.action.\(rawValue)"
    }

    var shortcutDefaultsKey: String {
        "gesture.shortcut.\(rawValue)"
    }
}

enum GestureAction: String, CaseIterable {
    case none
    case middleClick
    case keyboardShortcut

    var title: String {
        switch self {
        case .none:
            return "Do Nothing"
        case .middleClick:
            return "Middle Click"
        case .keyboardShortcut:
            return "Keyboard Shortcut"
        }
    }

    var shortTitle: String {
        switch self {
        case .none:
            return "Off"
        case .middleClick:
            return "Middle Click"
        case .keyboardShortcut:
            return "Shortcut"
        }
    }

    var subtitle: String {
        switch self {
        case .none:
            return "Leave the gesture untouched."
        case .middleClick:
            return "Emit a synthetic middle mouse click."
        case .keyboardShortcut:
            return "Trigger a saved keyboard shortcut."
        }
    }
}

struct KeyboardShortcut: Codable, Hashable {
    let keyCode: UInt16
    let modifiers: UInt64
    let display: String

    init(keyCode: UInt16, modifiers: UInt64, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }

    var title: String {
        display
    }

    var eventFlags: CGEventFlags {
        CGEventFlags(rawValue: modifiers)
    }

    var hasModifiers: Bool {
        modifiers != 0
    }

    static func from(event: NSEvent) -> KeyboardShortcut? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let display = Self.displayString(for: event) else {
            return nil
        }

        return KeyboardShortcut(
            keyCode: UInt16(event.keyCode),
            modifiers: UInt64(modifiers.rawValue),
            display: display
        )
    }

    private static func displayString(for event: NSEvent) -> String? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifierText = Self.modifierString(for: modifiers)

        if let specialKey = specialKeyNames[event.keyCode] {
            return modifierText + specialKey
        }

        guard let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines), !characters.isEmpty else {
            return nil
        }

        return modifierText + characters.uppercased()
    }

    private static func modifierString(for flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.function) { parts.append("fn") }

        return parts.joined()
    }

    private static let specialKeyNames: [UInt16: String] = [
        36: "↩",
        48: "⇥",
        49: "Space",
        51: "⌫",
        53: "⎋",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        103: "F11",
        105: "F13",
        106: "F16",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "Home",
        116: "Page Up",
        117: "⌦",
        118: "F4",
        119: "End",
        120: "F2",
        121: "Page Down",
        122: "F1",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑",
    ]
}

@MainActor
final class GestureConfigurationStore {
    static let shared = GestureConfigurationStore()

    private let defaults = UserDefaults.standard
    private let touchToClickKey = "gesture.touchToClickEnabled"
    private let hasShownInitialSettingsKey = "app.hasShownInitialSettingsWindow"

    private init() {
        for gesture in GestureKind.allCases {
            if defaults.string(forKey: gesture.defaultsKey) == nil {
                let defaultAction: GestureAction = gesture == .threeFingerClick ? .middleClick : .none
                defaults.set(defaultAction.rawValue, forKey: gesture.defaultsKey)
            }
        }

        if defaults.object(forKey: touchToClickKey) == nil {
            defaults.set(true, forKey: touchToClickKey)
        }

        if defaults.object(forKey: hasShownInitialSettingsKey) == nil {
            defaults.set(false, forKey: hasShownInitialSettingsKey)
        }
    }

    func action(for gesture: GestureKind) -> GestureAction {
        guard
            let rawValue = defaults.string(forKey: gesture.defaultsKey),
            let action = GestureAction(rawValue: rawValue)
        else {
            return gesture == .threeFingerClick ? .middleClick : .none
        }

        return action
    }

    func setAction(_ action: GestureAction, for gesture: GestureKind) {
        defaults.set(action.rawValue, forKey: gesture.defaultsKey)
    }

    func shortcut(for gesture: GestureKind) -> KeyboardShortcut? {
        guard let data = defaults.data(forKey: gesture.shortcutDefaultsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    }

    func setShortcut(_ shortcut: KeyboardShortcut?, for gesture: GestureKind) {
        if let shortcut, let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: gesture.shortcutDefaultsKey)
        } else {
            defaults.removeObject(forKey: gesture.shortcutDefaultsKey)
        }
    }

    func touchToClickEnabled() -> Bool {
        defaults.bool(forKey: touchToClickKey)
    }

    func setTouchToClickEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: touchToClickKey)
    }

    func consumeInitialSettingsPresentation() -> Bool {
        let hasShownInitialSettings = defaults.bool(forKey: hasShownInitialSettingsKey)
        guard !hasShownInitialSettings else {
            return false
        }

        defaults.set(true, forKey: hasShownInitialSettingsKey)
        return true
    }
}

struct GestureExecution {
    let triggerGesture: GestureKind
    let action: GestureAction
    let shortcut: KeyboardShortcut?
}

final class SharedRemapState: @unchecked Sendable {
    private let lock = NSLock()
    private var fingerCountsByDevice: [Int: Int] = [:]
    private var actions: [GestureKind: GestureAction]
    private var shortcuts: [GestureKind: KeyboardShortcut]
    private var touchToClickEnabled: Bool
    private var activeClickExecution: GestureExecution?
    private var suppressingClickSequence = false
    private var suppressedClickGesture: GestureKind?
    private var suppressedClickDeadline: CFAbsoluteTime = 0

    init(actions: [GestureKind: GestureAction], shortcuts: [GestureKind: KeyboardShortcut], touchToClickEnabled: Bool) {
        self.actions = actions
        self.shortcuts = shortcuts
        self.touchToClickEnabled = touchToClickEnabled
    }

    func updateFingerCount(_ fingerCount: Int, deviceID: Int) -> GestureExecution? {
        lock.withLock {
            let previousFingerCount = fingerCountsByDevice[deviceID] ?? 0
            fingerCountsByDevice[deviceID] = max(fingerCount, 0)

            guard fingerCount != previousFingerCount else {
                return nil
            }

            guard let triggerGesture = touchGesture(for: fingerCount) else {
                return nil
            }

            let actionSource = resolvedActionSource(for: triggerGesture)
            let action = actions[actionSource] ?? .none
            guard let execution = resolvedExecution(triggerGesture: triggerGesture, actionSource: actionSource, action: action) else {
                return nil
            }

            if touchToClickEnabled {
                suppressedClickGesture = actionSource.pairedClickGesture
                suppressedClickDeadline = CFAbsoluteTimeGetCurrent() + 0.45
            }

            return execution
        }
    }

    func setAction(_ action: GestureAction, for gesture: GestureKind) {
        lock.withLock {
            actions[gesture] = action
        }
    }

    func setShortcut(_ shortcut: KeyboardShortcut?, for gesture: GestureKind) {
        lock.withLock {
            if let shortcut {
                shortcuts[gesture] = shortcut
            } else {
                shortcuts.removeValue(forKey: gesture)
            }
        }
    }

    func setTouchToClickEnabled(_ enabled: Bool) {
        lock.withLock {
            touchToClickEnabled = enabled
            if !enabled {
                suppressedClickGesture = nil
                suppressedClickDeadline = 0
            }
        }
    }

    func beginRemapIfNeeded() -> GestureExecution? {
        lock.withLock {
            let currentFingerCount = fingerCountsByDevice.values.max() ?? 0
            guard let gesture = clickGesture(for: currentFingerCount) else {
                activeClickExecution = nil
                suppressingClickSequence = false
                return nil
            }

            if suppressedClickGesture == gesture {
                let now = CFAbsoluteTimeGetCurrent()
                if now <= suppressedClickDeadline {
                    activeClickExecution = nil
                    suppressingClickSequence = false
                    return nil
                }
                suppressedClickGesture = nil
                suppressedClickDeadline = 0
            }

            let action = actions[gesture] ?? .none
            guard let execution = resolvedExecution(triggerGesture: gesture, actionSource: gesture, action: action) else {
                activeClickExecution = nil
                suppressingClickSequence = false
                return nil
            }

            suppressingClickSequence = true
            if execution.action == .middleClick {
                activeClickExecution = execution
            } else {
                activeClickExecution = nil
            }
            return execution
        }
    }

    func activeRemapExecution() -> GestureExecution? {
        lock.withLock {
            activeClickExecution
        }
    }

    func isSuppressingClickSequence() -> Bool {
        lock.withLock {
            suppressingClickSequence
        }
    }

    func finishRemap() -> GestureExecution? {
        lock.withLock {
            defer {
                activeClickExecution = nil
                suppressingClickSequence = false
            }
            return activeClickExecution
        }
    }

    private func resolvedExecution(triggerGesture: GestureKind, actionSource: GestureKind, action: GestureAction) -> GestureExecution? {
        switch action {
        case .none:
            return nil
        case .middleClick:
            return GestureExecution(triggerGesture: triggerGesture, action: action, shortcut: nil)
        case .keyboardShortcut:
            guard let shortcut = shortcuts[actionSource] else {
                return nil
            }
            return GestureExecution(triggerGesture: triggerGesture, action: action, shortcut: shortcut)
        }
    }

    func shortcut(for gesture: GestureKind) -> KeyboardShortcut? {
        lock.withLock {
            shortcuts[gesture]
        }
    }

    private func resolvedActionSource(for gesture: GestureKind) -> GestureKind {
        if gesture.isTouchGesture && touchToClickEnabled {
            return gesture.pairedClickGesture
        }

        return gesture
    }

    private func clickGesture(for fingerCount: Int) -> GestureKind? {
        switch fingerCount {
        case 3:
            return .threeFingerClick
        case 4:
            return .fourFingerClick
        default:
            return nil
        }
    }

    private func touchGesture(for fingerCount: Int) -> GestureKind? {
        switch fingerCount {
        case 3:
            return .threeFingerTouch
        case 4:
            return .fourFingerTouch
        default:
            return nil
        }
    }
}

extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
