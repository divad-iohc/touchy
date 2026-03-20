import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configuration = GestureConfigurationStore.shared
    private lazy var settingsModel = SettingsViewModel(
        actions: currentActions(),
        shortcuts: currentShortcuts(),
        touchToClickEnabled: configuration.touchToClickEnabled()
    )
    private lazy var remapper = GlobalGestureRemapper(
        actions: currentActions(),
        shortcuts: currentShortcuts(),
        touchToClickEnabled: configuration.touchToClickEnabled()
    )
    private let launchAtLoginController = LaunchAtLoginController()

    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var latestRemapperStatus: String?

    private let serviceMenuItem = NSMenuItem(title: "Needs Access", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("Touchy should stay resident in the menu bar.")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        configureStatusItem()
        buildWindow()
        wireRemapper()
        refreshLaunchAtLoginStatus()
        refreshPermissionStatus()
        remapper.start()
        if configuration.consumeInitialSettingsPresentation() {
            DispatchQueue.main.async { [weak self] in
                self?.showSettingsWindow(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func showSettingsWindow(_ sender: Any?) {
        guard let window else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        refreshPermissionStatus()
    }

    @objc private func promptForAccessibility(_ sender: Any?) {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.recheckPermissionsAndRestart(nil)
        }
    }

    @objc private func recheckPermissionsAndRestart(_ sender: Any?) {
        refreshPermissionStatus()
        remapper.restart()
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        refreshPermissionStatus()
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func buildWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "Touchy Settings"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .automatic
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentMinSize = NSSize(width: 540, height: 620)

        let rootView = TouchySettingsView(
            model: settingsModel,
            onActionChanged: { [weak self] gesture, action in
                self?.updateAction(action, for: gesture)
            },
            onShortcutChanged: { [weak self] gesture, shortcut in
                self?.updateShortcut(shortcut, for: gesture)
            },
            onTouchToClickChanged: { [weak self] enabled in
                self?.updateTouchToClick(enabled)
            },
            onLaunchAtLoginChanged: { [weak self] enabled in
                self?.updateLaunchAtLogin(enabled)
            },
            onRequestAccessibility: { [weak self] in
                self?.promptForAccessibility(nil)
            },
            onRefreshStatus: { [weak self] in
                self?.recheckPermissionsAndRestart(nil)
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hostingView

        self.window = window
    }

    private func updateAction(_ action: GestureAction, for gesture: GestureKind) {
        configuration.setAction(action, for: gesture)
        settingsModel.setAction(action, for: gesture)
        remapper.setAction(action, for: gesture)
    }

    private func updateShortcut(_ shortcut: KeyboardShortcut?, for gesture: GestureKind) {
        configuration.setShortcut(shortcut, for: gesture)
        settingsModel.setShortcut(shortcut, for: gesture)
        remapper.setShortcut(shortcut, for: gesture)
    }

    private func updateTouchToClick(_ enabled: Bool) {
        configuration.setTouchToClickEnabled(enabled)
        settingsModel.setTouchToClickEnabled(enabled)
        remapper.setTouchToClickEnabled(enabled)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        let result = launchAtLoginController.setEnabled(enabled)
        settingsModel.updateLaunchAtLogin(enabled: result.enabled, detail: result.detail)
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "Touchy") {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "T"
        }
        statusItem.button?.toolTip = "Touchy"

        let menu = NSMenu()
        serviceMenuItem.isEnabled = false

        menu.addItem(serviceMenuItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings...", action: #selector(showSettingsWindow(_:)), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Request Accessibility Access", action: #selector(promptForAccessibility(_:)), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Touchy", action: #selector(quitApp(_:)), keyEquivalent: "q").target = self

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func wireRemapper() {
        remapper.onStatusChange = { [weak self] status in
            guard let self else {
                return
            }

            self.refreshStatusDisplay(from: status)
        }
    }

    private func refreshPermissionStatus() {
        refreshStatusDisplay(from: nil)
    }

    private func refreshLaunchAtLoginStatus() {
        let result = launchAtLoginController.currentState()
        settingsModel.updateLaunchAtLogin(enabled: result.enabled, detail: result.detail)
    }

    private func refreshStatusDisplay(from remapperStatus: String?) {
        if let remapperStatus {
            latestRemapperStatus = remapperStatus
        }

        let accessibilityEnabled = AXIsProcessTrusted()
        let detail = latestRemapperStatus
        let isLimited = detail?.localizedCaseInsensitiveContains("blocked") == true || detail?.localizedCaseInsensitiveContains("unavailable") == true

        let statusTitle: String
        let isActive: Bool

        if !accessibilityEnabled {
            statusTitle = "Needs Access"
            isActive = false
        } else if isLimited {
            statusTitle = "Limited"
            isActive = false
        } else {
            statusTitle = "Active"
            isActive = true
        }

        let statusDetail: String
        if !accessibilityEnabled {
            statusDetail = "Accessibility access is required before Touchy can remap gestures globally."
        } else if let detail {
            statusDetail = detail
        } else {
            statusDetail = "Touchy is ready in the menu bar and listening for configured gestures."
        }

        serviceMenuItem.title = statusTitle
        settingsModel.updateStatus(title: statusTitle, detail: statusDetail, isActive: isActive)
    }

    private func currentActions() -> [GestureKind: GestureAction] {
        Dictionary(uniqueKeysWithValues: GestureKind.allCases.map { gesture in
            (gesture, configuration.action(for: gesture))
        })
    }

    private func currentShortcuts() -> [GestureKind: KeyboardShortcut] {
        Dictionary(uniqueKeysWithValues: GestureKind.allCases.compactMap { gesture in
            configuration.shortcut(for: gesture).map { (gesture, $0) }
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        remapper.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSettingsWindow(nil)
        }
        return true
    }
}

@MainActor
private final class LaunchAtLoginController {
    struct State {
        let enabled: Bool
        let detail: String
    }

    func currentState() -> State {
        guard #available(macOS 13.0, *) else {
            return State(enabled: false, detail: "Launch at login requires macOS 13 or newer.")
        }

        let service = SMAppService.mainApp
        switch service.status {
        case .enabled:
            return State(enabled: true, detail: "")
        case .requiresApproval:
            return State(enabled: false, detail: "Approve Touchy in System Settings > Login Items.")
        case .notFound:
            return State(enabled: false, detail: "Available in the packaged app.")
        case .notRegistered:
            return State(enabled: false, detail: "")
        @unknown default:
            return State(enabled: false, detail: "Launch at login status is unavailable.")
        }
    }

    func setEnabled(_ enabled: Bool) -> State {
        guard #available(macOS 13.0, *) else {
            return State(enabled: false, detail: "Launch at login requires macOS 13 or newer.")
        }

        let service = SMAppService.mainApp

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return currentState()
        } catch {
            let fallback = currentState()
            return State(enabled: fallback.enabled, detail: launchAtLoginErrorDetail(error, fallback: fallback.detail))
        }
    }

    private func launchAtLoginErrorDetail(_ error: Error, fallback: String) -> String {
        _ = error as NSError
        return fallback.isEmpty ? "Touchy could not update launch at login." : fallback
    }
}
