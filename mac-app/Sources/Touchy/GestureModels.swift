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
}

enum GestureAction: String, CaseIterable {
    case none
    case middleClick

    var title: String {
        switch self {
        case .none:
            return "Do Nothing"
        case .middleClick:
            return "Middle Click"
        }
    }

    var shortTitle: String {
        switch self {
        case .none:
            return "Off"
        case .middleClick:
            return "Middle Click"
        }
    }

    var subtitle: String {
        switch self {
        case .none:
            return "Leave the gesture untouched."
        case .middleClick:
            return "Emit a synthetic middle mouse click."
        }
    }
}

@MainActor
final class GestureConfigurationStore {
    static let shared = GestureConfigurationStore()

    private let defaults = UserDefaults.standard
    private let touchToClickKey = "gesture.touchToClickEnabled"

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

    func touchToClickEnabled() -> Bool {
        defaults.bool(forKey: touchToClickKey)
    }

    func setTouchToClickEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: touchToClickKey)
    }
}

struct GestureExecution {
    let triggerGesture: GestureKind
    let action: GestureAction
}

final class SharedRemapState: @unchecked Sendable {
    private let lock = NSLock()
    private var fingerCountsByDevice: [Int: Int] = [:]
    private var actions: [GestureKind: GestureAction]
    private var touchToClickEnabled: Bool
    private var activeClickGesture: GestureKind?
    private var suppressedClickGesture: GestureKind?
    private var suppressedClickDeadline: CFAbsoluteTime = 0

    init(actions: [GestureKind: GestureAction], touchToClickEnabled: Bool) {
        self.actions = actions
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
            guard action != .none else {
                return nil
            }

            if touchToClickEnabled {
                suppressedClickGesture = actionSource.pairedClickGesture
                suppressedClickDeadline = CFAbsoluteTimeGetCurrent() + 0.45
            }

            return GestureExecution(triggerGesture: triggerGesture, action: action)
        }
    }

    func setAction(_ action: GestureAction, for gesture: GestureKind) {
        lock.withLock {
            actions[gesture] = action
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

    func beginRemapIfNeeded() -> GestureKind? {
        lock.withLock {
            let currentFingerCount = fingerCountsByDevice.values.max() ?? 0
            guard let gesture = clickGesture(for: currentFingerCount) else {
                activeClickGesture = nil
                return nil
            }

            if suppressedClickGesture == gesture {
                let now = CFAbsoluteTimeGetCurrent()
                if now <= suppressedClickDeadline {
                    activeClickGesture = nil
                    return nil
                }
                suppressedClickGesture = nil
                suppressedClickDeadline = 0
            }

            guard actions[gesture] == .middleClick else {
                activeClickGesture = nil
                return nil
            }

            activeClickGesture = gesture
            return gesture
        }
    }

    func activeRemapGesture() -> GestureKind? {
        lock.withLock {
            activeClickGesture
        }
    }

    func finishRemap() -> GestureKind? {
        lock.withLock {
            defer { activeClickGesture = nil }
            return activeClickGesture
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
