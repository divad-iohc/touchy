import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var actions: [GestureKind: GestureAction]
    @Published private(set) var shortcuts: [GestureKind: KeyboardShortcut]
    @Published private(set) var touchToClickEnabled: Bool
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginDetail: String
    @Published private(set) var statusTitle: String
    @Published private(set) var statusDetail: String
    @Published private(set) var isActive: Bool

    init(actions: [GestureKind: GestureAction], shortcuts: [GestureKind: KeyboardShortcut], touchToClickEnabled: Bool) {
        self.actions = actions
        self.shortcuts = shortcuts
        self.touchToClickEnabled = touchToClickEnabled
        self.launchAtLoginEnabled = false
        self.launchAtLoginDetail = ""
        self.statusTitle = "Needs Access"
        self.statusDetail = "Accessibility access is required before Touchy can remap gestures."
        self.isActive = false
    }

    func action(for gesture: GestureKind) -> GestureAction {
        actions[gesture] ?? .none
    }

    func inheritedAction(for gesture: GestureKind) -> GestureAction {
        action(for: gesture.pairedClickGesture)
    }

    func shortcut(for gesture: GestureKind) -> KeyboardShortcut? {
        shortcuts[gesture]
    }

    func inheritedShortcut(for gesture: GestureKind) -> KeyboardShortcut? {
        shortcut(for: gesture.pairedClickGesture)
    }

    func setAction(_ action: GestureAction, for gesture: GestureKind) {
        actions[gesture] = action
    }

    func setShortcut(_ shortcut: KeyboardShortcut?, for gesture: GestureKind) {
        if let shortcut {
            shortcuts[gesture] = shortcut
        } else {
            shortcuts.removeValue(forKey: gesture)
        }
    }

    func setTouchToClickEnabled(_ enabled: Bool) {
        touchToClickEnabled = enabled
    }

    func updateLaunchAtLogin(enabled: Bool, detail: String) {
        launchAtLoginEnabled = enabled
        launchAtLoginDetail = detail
    }

    func updateStatus(title: String, detail: String, isActive: Bool) {
        statusTitle = title
        statusDetail = detail
        self.isActive = isActive
    }
}

struct TouchySettingsView: View {
    @ObservedObject var model: SettingsViewModel

    let onActionChanged: (GestureKind, GestureAction) -> Void
    let onShortcutChanged: (GestureKind, KeyboardShortcut?) -> Void
    let onTouchToClickChanged: (Bool) -> Void
    let onLaunchAtLoginChanged: (Bool) -> Void
    let onRequestAccessibility: () -> Void
    let onRefreshStatus: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private let gridColumns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14),
    ]

    var body: some View {
        ZStack {
            TouchyPalette.windowBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    appPanel
                    gesturePanel
                }
                .padding(22)
            }
        }
        .frame(minWidth: 540, minHeight: 620)
        .preferredColorScheme(.light)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.statusTitle)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(TouchyPalette.ink)

                if !conciseStatusDetail.isEmpty {
                    Text(conciseStatusDetail)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(TouchyPalette.subtleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    if showsAccessibilityRequest {
                        Button("Grant Access", action: onRequestAccessibility)
                            .buttonStyle(TouchyPrimaryButtonStyle())
                    }

                    if showsAccessibilityRequest {
                        Button("Refresh", action: onRefreshStatus)
                            .buttonStyle(TouchySecondaryButtonStyle())
                    } else {
                        Button("Refresh", action: onRefreshStatus)
                            .buttonStyle(TouchyPrimaryButtonStyle())
                    }
                }
                .padding(.top, 6)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.68), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(TouchyPalette.heroGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: TouchyPalette.shadow.opacity(0.18), radius: 24, x: 0, y: 12)
    }

    private var gesturePanel: some View {
        TouchyPanel(title: "Gesture Mappings", symbolName: "hand.tap.fill") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Touch gestures mirror click gestures")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(TouchyPalette.ink)

                        Text("Keep touch input lightweight by inheriting the paired click action, or turn this off to configure touch gestures separately.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(TouchyPalette.subtleInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Toggle("", isOn: Binding(
                        get: { model.touchToClickEnabled },
                        set: { newValue in
                            onTouchToClickChanged(newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                HStack(spacing: 8) {
                    Image(systemName: model.touchToClickEnabled ? "arrow.triangle.branch" : "slider.horizontal.3")
                        .foregroundStyle(TouchyPalette.primary)

                    Text(model.touchToClickEnabled
                        ? "Touch gestures are inheriting the action from their click counterparts."
                        : "Touch gestures can be assigned independently.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TouchyPalette.ink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TouchyPalette.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 14) {
                    ForEach(GestureKind.visibleOrder, id: \.rawValue) { gesture in
                        GestureTile(
                            gesture: gesture,
                            selectedAction: model.action(for: gesture),
                            inheritedAction: model.inheritedAction(for: gesture),
                            selectedShortcut: model.shortcut(for: gesture),
                            inheritedShortcut: model.inheritedShortcut(for: gesture),
                            isInherited: model.touchToClickEnabled && gesture.isTouchGesture,
                            onActionChanged: { onActionChanged(gesture, $0) },
                            onShortcutChanged: { onShortcutChanged(gesture, $0) }
                        )
                    }
                }
                .animation(accessibilityReduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88), value: model.touchToClickEnabled)
            }
        }
    }

    private var appPanel: some View {
        TouchyPanel(title: "App", symbolName: "power") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch at Login")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(TouchyPalette.ink)

                        Text("Start Touchy automatically after you sign in.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(TouchyPalette.subtleInk)
                    }

                    Spacer(minLength: 12)

                    Toggle("", isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { newValue in
                            onLaunchAtLoginChanged(newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                if !model.launchAtLoginDetail.isEmpty {
                    Text(model.launchAtLoginDetail)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(TouchyPalette.subtleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var showsAccessibilityRequest: Bool {
        model.statusTitle == "Needs Access" || model.statusTitle == "Limited"
    }

    private var conciseStatusDetail: String {
        switch model.statusTitle {
        case "Needs Access":
            return "Accessibility permission is required."
        case "Limited":
            return "Touchy is running with limited access."
        case "Active":
            return ""
        default:
            return model.statusDetail
        }
    }
}

private struct GestureTile: View {
    let gesture: GestureKind
    let selectedAction: GestureAction
    let inheritedAction: GestureAction
    let selectedShortcut: KeyboardShortcut?
    let inheritedShortcut: KeyboardShortcut?
    let isInherited: Bool
    let onActionChanged: (GestureAction) -> Void
    let onShortcutChanged: (KeyboardShortcut?) -> Void

    @State private var isRecordingShortcut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(TouchyPalette.primary.opacity(0.14))

                    Image(systemName: gesture.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TouchyPalette.primary)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(gesture.shortTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(TouchyPalette.ink)

                    Text(gesture.subtitle)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(TouchyPalette.subtleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if isInherited {
                Label("Inherited from \(gesture.pairedClickGesture.shortTitle)", systemImage: "link")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(TouchyPalette.primary)
            } else {
                Text(gesture.interactionLabel)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(TouchyPalette.subtleInk)
                    .textCase(.uppercase)
            }

            Picker("Action", selection: Binding(
                get: { isInherited ? inheritedAction : selectedAction },
                set: { newValue in
                    onActionChanged(newValue)
                }
            )) {
                ForEach(GestureAction.allCases, id: \.self) { action in
                    Text(action.shortTitle).tag(action)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isInherited)

            Text(isInherited ? inheritedAction.subtitle : selectedAction.subtitle)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(TouchyPalette.subtleInk)
                .fixedSize(horizontal: false, vertical: true)

            if effectiveAction == .keyboardShortcut {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Button(effectiveShortcut?.title ?? "Record Shortcut") {
                            if !isInherited {
                                isRecordingShortcut = true
                            }
                        }
                        .buttonStyle(TouchySecondaryButtonStyle())
                        .disabled(isInherited)

                        if !isInherited, selectedShortcut != nil {
                            Button("Clear") {
                                onShortcutChanged(nil)
                            }
                            .buttonStyle(TouchyGhostButtonStyle())
                        }
                    }

                    Text(shortcutHint)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(TouchyPalette.subtleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(TouchyPalette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isInherited ? TouchyPalette.primary.opacity(0.28) : Color.white.opacity(0.65), lineWidth: 1)
        )
        .sheet(isPresented: $isRecordingShortcut) {
            ShortcutCaptureSheet(
                initialShortcut: selectedShortcut,
                onCancel: { isRecordingShortcut = false },
                onClear: {
                    onShortcutChanged(nil)
                    isRecordingShortcut = false
                },
                onCapture: { shortcut in
                    onShortcutChanged(shortcut)
                    isRecordingShortcut = false
                }
            )
            .frame(minWidth: 360, minHeight: 210)
        }
    }

    private var effectiveAction: GestureAction {
        isInherited ? inheritedAction : selectedAction
    }

    private var effectiveShortcut: KeyboardShortcut? {
        isInherited ? inheritedShortcut : selectedShortcut
    }

    private var shortcutHint: String {
        if isInherited {
            return effectiveShortcut.map { "Inherited shortcut: \($0.title)" } ?? "No shortcut is set on the paired click gesture."
        }

        return effectiveShortcut.map { "Current shortcut: \($0.title)" } ?? "No shortcut recorded yet."
    }
}

private struct TouchyPanel<Content: View>: View {
    let title: String
    let symbolName: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(TouchyPalette.primary)

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TouchyPalette.subtleInk)
                    .textCase(.uppercase)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(TouchyPalette.panelMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: TouchyPalette.shadow.opacity(0.06), radius: 16, x: 0, y: 10)
    }
}

private struct TouchyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(TouchyPalette.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct TouchySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(TouchyPalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(TouchyPalette.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TouchyPalette.primary.opacity(0.2), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct TouchyGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(TouchyPalette.subtleInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

private struct ShortcutCaptureSheet: View {
    let initialShortcut: KeyboardShortcut?
    let onCancel: () -> Void
    let onClear: () -> Void
    let onCapture: (KeyboardShortcut) -> Void

    @State private var pendingShortcut: KeyboardShortcut?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Record Shortcut")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TouchyPalette.ink)

            Text("Press the shortcut you want Touchy to trigger. Press Delete to clear it.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(TouchyPalette.subtleInk)
                .fixedSize(horizontal: false, vertical: true)

            ShortcutCaptureView(shortcut: $pendingShortcut)
                .frame(maxWidth: .infinity)
                .frame(height: 86)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(TouchyGhostButtonStyle())

                Button("Clear", action: onClear)
                    .buttonStyle(TouchySecondaryButtonStyle())

                Button("Save") {
                    if let pendingShortcut {
                        onCapture(pendingShortcut)
                    }
                }
                .buttonStyle(TouchyPrimaryButtonStyle())
                .disabled(pendingShortcut == nil)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TouchyPalette.windowBackground)
        .onAppear {
            pendingShortcut = initialShortcut
        }
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut?

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onShortcutCaptured = { captured in
            shortcut = captured
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.onShortcutCaptured = { captured in
            shortcut = captured
        }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ShortcutCaptureNSView: NSView {
    var shortcut: KeyboardShortcut?
    var onShortcutCaptured: ((KeyboardShortcut?) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 20, yRadius: 20)
        NSColor.white.withAlphaComponent(0.72).setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1
        path.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let title = (shortcut?.title ?? "Press Shortcut")
        let subtitle = "Recorder is active"

        title.draw(
            in: NSRect(x: 16, y: bounds.midY - 6, width: bounds.width - 32, height: 26),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
            ]
        )

        subtitle.draw(
            in: NSRect(x: 16, y: bounds.midY - 28, width: bounds.width - 32, height: 20),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph,
            ]
        )
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 {
            shortcut = nil
            onShortcutCaptured?(nil)
            needsDisplay = true
            return
        }

        guard let captured = KeyboardShortcut.from(event: event) else {
            NSSound.beep()
            return
        }

        shortcut = captured
        onShortcutCaptured?(captured)
        needsDisplay = true
    }
}

private enum TouchyPalette {
    static let primary = Color(red: 0.05, green: 0.58, blue: 0.53)
    static let active = Color(red: 0.08, green: 0.68, blue: 0.45)
    static let warning = Color(red: 0.93, green: 0.52, blue: 0.16)
    static let ink = Color(red: 0.08, green: 0.19, blue: 0.23)
    static let subtleInk = Color(red: 0.24, green: 0.37, blue: 0.39)
    static let shadow = Color.black
    static let panelFill = Color.white.opacity(0.92)
    static let panelMaterial = LinearGradient(
        colors: [
            Color.white.opacity(0.92),
            Color(red: 0.93, green: 0.98, blue: 0.97).opacity(0.94),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.48, blue: 0.48),
            Color(red: 0.08, green: 0.71, blue: 0.65),
            Color(red: 0.96, green: 0.59, blue: 0.28),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let windowBackground = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.99, blue: 0.98),
            Color(red: 0.90, green: 0.97, blue: 0.95),
            Color(red: 0.98, green: 0.94, blue: 0.89),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
