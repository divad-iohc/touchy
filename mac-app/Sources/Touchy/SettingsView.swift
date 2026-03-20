import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var actions: [GestureKind: GestureAction]
    @Published private(set) var touchToClickEnabled: Bool
    @Published private(set) var statusTitle: String
    @Published private(set) var statusDetail: String
    @Published private(set) var isActive: Bool

    init(actions: [GestureKind: GestureAction], touchToClickEnabled: Bool) {
        self.actions = actions
        self.touchToClickEnabled = touchToClickEnabled
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

    func setAction(_ action: GestureAction, for gesture: GestureKind) {
        actions[gesture] = action
    }

    func setTouchToClickEnabled(_ enabled: Bool) {
        touchToClickEnabled = enabled
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
    let onTouchToClickChanged: (Bool) -> Void
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
                            isInherited: model.touchToClickEnabled && gesture.isTouchGesture,
                            onActionChanged: { onActionChanged(gesture, $0) }
                        )
                    }
                }
                .animation(accessibilityReduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88), value: model.touchToClickEnabled)
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
    let isInherited: Bool
    let onActionChanged: (GestureAction) -> Void

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
