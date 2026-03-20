import AppKit
import ApplicationServices
import CoreFoundation
import Darwin

final class GlobalGestureRemapper {
    var onStatusChange: (@MainActor @Sendable (String) -> Void)?

    private let state: SharedRemapState
    private let multitouchWatcher: MultitouchWatcher?

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?

    init(actions: [GestureKind: GestureAction], touchToClickEnabled: Bool) {
        self.state = SharedRemapState(actions: actions, touchToClickEnabled: touchToClickEnabled)
        self.multitouchWatcher = MultitouchWatcher(state: state)
        self.multitouchWatcher?.onTouchExecution = { [weak self] execution in
            self?.handleTouchExecution(execution)
        }
    }

    deinit {
        stop()
    }

    func start() {
        let accessibilityGranted = AXIsProcessTrusted()
        let multitouchReady = multitouchWatcher?.start() ?? false
        let tapReady = accessibilityGranted && startEventTap()

        if !accessibilityGranted {
            postStatus("Accessibility is not granted. Grant it, then click Recheck Permissions or relaunch the app.")
        } else if multitouchReady && tapReady {
            postStatus("Global remapping is active.")
        } else if !multitouchReady {
            postStatus("Multitouch tracking is unavailable on this macOS build.")
        } else {
            postStatus("Mouse remapping is blocked. Input Monitoring may still be required.")
        }
    }

    func restart() {
        stop()
        start()
    }

    func stop() {
        multitouchWatcher?.stop()

        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    func setAction(_ action: GestureAction, for gesture: GestureKind) {
        state.setAction(action, for: gesture)
        postStatus("\(gesture.title) now maps to \(action.title).")
    }

    func setTouchToClickEnabled(_ enabled: Bool) {
        state.setTouchToClickEnabled(enabled)

        if enabled {
            postStatus("Touch to Click is on. Touch gestures now use the click actions.")
        } else {
            postStatus("Touch to Click is off. Touch gestures use their own actions.")
        }
    }

    private func startEventTap() -> Bool {
        guard eventTap == nil else {
            return true
        }

        let mask =
            (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseDragged.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let remapper = Unmanaged<GlobalGestureRemapper>.fromOpaque(userInfo).takeUnretainedValue()
            return remapper.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        eventTapSource = source
        return true
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            postStatus("The mouse event tap was re-enabled after macOS paused it.")
            return Unmanaged.passUnretained(event)
        case .leftMouseDown:
            guard state.beginRemapIfNeeded() != nil else {
                return Unmanaged.passUnretained(event)
            }

            postMiddleClick(from: event, as: .otherMouseDown)
            return nil
        case .leftMouseDragged:
            guard state.activeRemapGesture() != nil else {
                return Unmanaged.passUnretained(event)
            }

            postMiddleClick(from: event, as: .otherMouseDragged)
            return nil
        case .leftMouseUp:
            guard state.finishRemap() != nil else {
                return Unmanaged.passUnretained(event)
            }

            postMiddleClick(from: event, as: .otherMouseUp)
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func postMiddleClick(from event: CGEvent, as type: CGEventType) {
        guard let middleEvent = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: type,
            mouseCursorPosition: event.location,
            mouseButton: .center
        ) else {
            return
        }

        middleEvent.flags = event.flags
        middleEvent.setIntegerValueField(.mouseEventClickState, value: event.getIntegerValueField(.mouseEventClickState))
        middleEvent.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        middleEvent.post(tap: .cghidEventTap)
    }

    private func handleTouchExecution(_ execution: GestureExecution) {
        switch execution.action {
        case .none:
            return
        case .middleClick:
            postSyntheticMiddleClick()
        }
    }

    private func postSyntheticMiddleClick() {
        let location = currentPointerLocation()
        postMiddleClick(at: location, as: .otherMouseDown)
        postMiddleClick(at: location, as: .otherMouseUp)
    }

    private func postMiddleClick(at location: CGPoint, as type: CGEventType) {
        guard let middleEvent = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: .center
        ) else {
            return
        }

        middleEvent.setIntegerValueField(.mouseEventClickState, value: 1)
        middleEvent.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        middleEvent.post(tap: .cghidEventTap)
    }

    private func currentPointerLocation() -> CGPoint {
        if let currentEvent = CGEvent(source: nil) {
            return currentEvent.location
        }

        return NSEvent.mouseLocation
    }

    private func postStatus(_ status: String) {
        let callback = onStatusChange
        Task { @MainActor in
            callback?(status)
        }
    }
}

private final class MultitouchWatcher {
    private typealias MTDevice = OpaquePointer
    private typealias MTContactFrameCallback = @convention(c) (MTDevice, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias MTDeviceCreateListFunction = @convention(c) () -> Unmanaged<CFArray>
    private typealias MTRegisterContactFrameCallbackFunction = @convention(c) (MTDevice, MTContactFrameCallback) -> Void
    private typealias MTUnregisterContactFrameCallbackFunction = @convention(c) (MTDevice, MTContactFrameCallback) -> Void
    private typealias MTDeviceStartFunction = @convention(c) (MTDevice, Int32) -> Int32
    private typealias MTDeviceStopFunction = @convention(c) (MTDevice) -> Int32

    private let state: SharedRemapState
    var onTouchExecution: ((GestureExecution) -> Void)?
    private let libraryHandle: UnsafeMutableRawPointer?

    private let createDeviceList: MTDeviceCreateListFunction
    private let registerContactFrameCallback: MTRegisterContactFrameCallbackFunction
    private let unregisterContactFrameCallback: MTUnregisterContactFrameCallbackFunction
    private let startDevice: MTDeviceStartFunction
    private let stopDevice: MTDeviceStopFunction

    private var devices: [MTDevice] = []
    private var started = false

    init?(state: SharedRemapState) {
        self.state = state

        let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
            return nil
        }

        self.libraryHandle = handle

        guard
            let createDeviceList = MultitouchWatcher.loadSymbol(handle, named: "MTDeviceCreateList", as: MTDeviceCreateListFunction.self),
            let registerContactFrameCallback = MultitouchWatcher.loadSymbol(handle, named: "MTRegisterContactFrameCallback", as: MTRegisterContactFrameCallbackFunction.self),
            let unregisterContactFrameCallback = MultitouchWatcher.loadSymbol(handle, named: "MTUnregisterContactFrameCallback", as: MTUnregisterContactFrameCallbackFunction.self),
            let startDevice = MultitouchWatcher.loadSymbol(handle, named: "MTDeviceStart", as: MTDeviceStartFunction.self),
            let stopDevice = MultitouchWatcher.loadSymbol(handle, named: "MTDeviceStop", as: MTDeviceStopFunction.self)
        else {
            dlclose(handle)
            return nil
        }

        self.createDeviceList = createDeviceList
        self.registerContactFrameCallback = registerContactFrameCallback
        self.unregisterContactFrameCallback = unregisterContactFrameCallback
        self.startDevice = startDevice
        self.stopDevice = stopDevice
    }

    deinit {
        stop()

        if let libraryHandle {
            dlclose(libraryHandle)
        }
    }

    func start() -> Bool {
        guard !started else {
            return true
        }

        let deviceArray = createDeviceList().takeRetainedValue()
        var loadedDevices: [MTDevice] = []

        for index in 0..<CFArrayGetCount(deviceArray) {
            let value = CFArrayGetValueAtIndex(deviceArray, index)
            let device = unsafeBitCast(value, to: MTDevice.self)
            registerContactFrameCallback(device, Self.contactFrameCallback)
            _ = startDevice(device, 0)
            loadedDevices.append(device)
        }

        guard !loadedDevices.isEmpty else {
            return false
        }

        devices = loadedDevices
        started = true
        MultitouchWatcherRegistry.shared.setActive(self)
        return true
    }

    func stop() {
        guard started else {
            return
        }

        for device in devices {
            unregisterContactFrameCallback(device, Self.contactFrameCallback)
            _ = stopDevice(device)
        }

        devices.removeAll()
        started = false
        MultitouchWatcherRegistry.shared.setActive(nil)
    }

    private func handleContactFrame(device: MTDevice, fingerCount: Int) {
        // Using the opaque pointer value as the device identity is safer here
        // than calling deeper private API from the callback thread.
        let deviceID = Int(bitPattern: device)
        if let execution = state.updateFingerCount(fingerCount, deviceID: deviceID) {
            onTouchExecution?(execution)
        }
    }

    private static let contactFrameCallback: MTContactFrameCallback = { device, _, fingerCount, _, _ in
        MultitouchWatcherRegistry.shared.activeInstance()?.handleContactFrame(device: device, fingerCount: Int(fingerCount))
        return 0
    }

    private static func loadSymbol<T>(_ handle: UnsafeMutableRawPointer, named name: String, as type: T.Type) -> T? {
        guard let symbol = dlsym(handle, name) else {
            return nil
        }

        return unsafeBitCast(symbol, to: type)
    }
}

private final class MultitouchWatcherRegistry: @unchecked Sendable {
    static let shared = MultitouchWatcherRegistry()

    private let lock = NSLock()
    private weak var watcher: MultitouchWatcher?

    private init() {}

    func setActive(_ watcher: MultitouchWatcher?) {
        lock.withLock {
            self.watcher = watcher
        }
    }

    func activeInstance() -> MultitouchWatcher? {
        lock.withLock {
            watcher
        }
    }
}
