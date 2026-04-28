//
//  NotificationSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI

private struct NotificationSettingsBackground: View {
    var body: some View {
        Color(uiColor: .systemGroupedBackground)
        .ignoresSafeArea()
    }
}

private struct NotificationSettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder let content: Content

    private var strokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.24) : Color.black.opacity(0.04)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        )
        .shadow(color: shadowColor, radius: 20, y: 8)
    }
}

private struct NotificationSettingsBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.localized())
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

@MainActor
class NotificationSettingViewModel: ObservableObject {
    var notificationService: NotificationService

    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    func refreshAccessState() async {
        await notificationService.updateAccessStates()
    }
}

struct NotificationSettingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var notificationService: NotificationService
    @StateObject private var viewModel = NotificationSettingViewModel(notificationService: NotificationService())

    private var statusBadge: (String, Color) {
        switch viewModel.notificationService.accessState {
        case .granted:
            return ("Ready", .green)
        case .rejected:
            return ("Notifications Off", .red)
        case .notAsked:
            return ("Not Configured", .orange)
        case .unknown:
            return ("Checking", .secondary)
        }
    }

    var body: some View {
        ZStack {
            NotificationSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NotificationSettingsCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Price Guard")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))

                                NotificationSettingsBadge(text: statusBadge.0, tint: statusBadge.1)
                            }

                            Spacer()
                        }
                    }

                    if viewModel.notificationService.accessState == .rejected {
                        NotificationSettingsCard {
                            NoNotificationAccessView()
                        }
                    } else {
                        NotificationSettingsCard {
                            PriceBelowNotificationView(showHeader: false)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Price Guard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.notificationService = notificationService
            await viewModel.refreshAccessState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refreshAccessState() }
            }
        }
    }
}

struct NoNotificationAccessView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Notifications are disabled.".localized(), systemImage: "bell.slash.fill")
                .font(.headline)

            Button("Open Settings App") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }
}

struct NotificationSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationSettingView()
                .environmentObject(SettingsManager.shared)
                .environmentObject(NotificationService())
        }
    }
}
