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

class DeviceOrientationManager: ObservableObject {
    @Published var deviceOrientation = UIInterfaceOrientation.portrait

    init() {
        if let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
            deviceOrientation = orientation
        } else {
            deviceOrientation = UIInterfaceOrientation.portrait
        }

        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main,
            using: { _ in
                if let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
                    self.deviceOrientation = orientation
                } else {
                    self.deviceOrientation = UIInterfaceOrientation.portrait
                }
            }
        )
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
