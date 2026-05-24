//
//  Environment.swift
//  AWattPrice
//
//  Created by Léon Becker on 10.01.21.
//

import SwiftUI

enum AppTheme {
    static let accent = Color.orange
    static let success = Color(red: 0.20, green: 0.62, blue: 0.25)
    static let warning = Color.orange
    static let error = Color.red

    static func screenBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(uiColor: .systemBackground) : Color(red: 0.949, green: 0.949, blue: 0.965)
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color(uiColor: .systemBackground)
    }

    static func cardStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    static func subtleFill(_ color: Color, for colorScheme: ColorScheme) -> Color {
        color.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }

    static func fieldBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color(uiColor: .secondarySystemGroupedBackground)
    }
}

private struct SavingStatusOverlayContent: View {
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
                .tint(AppTheme.accent)

            Text("Saving to server".localized())
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppTheme.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(uiColor: .systemBackground), in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.accent, lineWidth: 1)
        )
    }
}

struct SavingStatusWindowOverlay: UIViewRepresentable {
    let isVisible: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.update(isVisible: isVisible, sourceView: view)
        }
    }

    final class Coordinator {
        private var hostingController: UIHostingController<SavingStatusOverlayContent>?

        func update(isVisible: Bool, sourceView: UIView) {
            guard let window = sourceView.window else { return }

            if isVisible {
                show(in: window)
            } else {
                hide()
            }
        }

        private func show(in window: UIWindow) {
            if let hostingController {
                hostingController.view.alpha = 1
                hostingController.view.transform = .identity
                return
            }

            let hostingController = UIHostingController(rootView: SavingStatusOverlayContent())
            hostingController.view.backgroundColor = .clear
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.isUserInteractionEnabled = false
            hostingController.view.alpha = 0
            hostingController.view.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)

            window.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8 + topTabBarOffset(in: window) + (UIDevice.current.userInterfaceIdiom == .pad ? 5 : 0)),
                hostingController.view.centerXAnchor.constraint(equalTo: window.safeAreaLayoutGuide.centerXAnchor)
            ])

            self.hostingController = hostingController

            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                hostingController.view.alpha = 1
                hostingController.view.transform = .identity
            }
        }

        /// Returns the height of the tab bar when it is positioned at the top of the screen on iPad.
        /// On iPhone (tab bar at the bottom) this returns 0.
        private func topTabBarOffset(in window: UIWindow) -> CGFloat {
            guard UIDevice.current.userInterfaceIdiom == .pad else { return 0 }
            guard let tabBar = findTabBar(in: window) else { return 49 }
            // Only compensate when the tab bar lives near the top of the window.
            let approxTopEdge = window.safeAreaInsets.top + tabBar.frame.height
            guard tabBar.frame.maxY <= approxTopEdge + 4 else { return 0 }
            return tabBar.frame.height
        }

        private func findTabBar(in view: UIView) -> UITabBar? {
            if let tabBar = view as? UITabBar { return tabBar }
            for subview in view.subviews {
                if let found = findTabBar(in: subview) { return found }
            }
            return nil
        }

        private func hide() {
            guard let hostingController else { return }

            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                hostingController.view.alpha = 0
                hostingController.view.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            } completion: { _ in
                hostingController.view.removeFromSuperview()
            }

            self.hostingController = nil
        }
    }
}

enum AppPlatform {
    static var isMacCatalyst: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }
}

class DeviceOrientationManager: ObservableObject {
    @Published var deviceOrientation = UIInterfaceOrientation.portrait

    init() {
        deviceOrientation = Self.currentInterfaceOrientation()

        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main,
            using: { _ in
                self.deviceOrientation = Self.currentInterfaceOrientation()
            }
        )
    }

    private static func currentInterfaceOrientation() -> UIInterfaceOrientation {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foregroundScene = scenes.first { $0.activationState == .foregroundActive }
        return (foregroundScene ?? scenes.first)?.effectiveGeometry.interfaceOrientation ?? .portrait
    }
}

struct DeviceOrientationManagerKey: EnvironmentKey {
    static var defaultValue = DeviceOrientationManager()
}

extension EnvironmentValues {
    var networkManager: NetworkManager {
        get {
            self[NetworkManagerKey.self]
        }
        set {}
    }

    var deviceOrientation: DeviceOrientationManager {
        get { self[DeviceOrientationManagerKey.self] }
        set {}
    }

    var deviceType: UIUserInterfaceIdiom {
        get { UIDevice.current.userInterfaceIdiom }
        set {}
    }

    var keyboardObserver: KeyboardObserver {
        get { self[KeyboardObserverKey.self] }
        set {}
    }
}

private struct AppScreenBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.screenBackground(for: colorScheme).ignoresSafeArea())
    }
}

private struct AppCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AppTheme.cardStroke(for: colorScheme), lineWidth: 1)
                    )
            )
    }
}

struct AppCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 18,
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(cornerRadius: cornerRadius, padding: padding)
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackground())
    }

    func appCardStyle(cornerRadius: CGFloat = 20, padding: CGFloat = 18) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
