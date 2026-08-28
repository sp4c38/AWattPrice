//
//  DataDownloadAndError.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

struct DataRetrievalLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView("Loading")

            Spacer()
        }
    }
}

struct DataRetrievalError: View {
    @ObservedObject var networkManager: NetworkManager

    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        DataUnavailableStateView(
            content: networkManager.isOffline ? .offline : .downloadFailed,
            retryDisabled: networkManager.isOffline,
            retryAction: retryDownload
        )
    }

    private func retryDownload() {
        energyDataService.download(setting: settingsManager.setting)
    }
}

struct CurrentDataUnavailable: View {
    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        DataUnavailableStateView(
            content: .noData,
            retryAction: retryDownload
        )
    }

    private func retryDownload() {
        energyDataService.download(setting: settingsManager.setting)
    }
}

private struct DataUnavailableContent {
    let iconName: String
    let iconColor: Color
    let title: LocalizedStringKey
    let message: LocalizedStringKey?

    static let offline = DataUnavailableContent(
        iconName: "wifi.slash",
        iconColor: AppTheme.accent,
        title: "dataError.connection.title",
        message: "dataError.connection.message"
    )

    static let downloadFailed = DataUnavailableContent(
        iconName: "exclamationmark.triangle",
        iconColor: AppTheme.warning,
        title: "dataError.download.title",
        message: "dataError.download.message"
    )

    static let noData = DataUnavailableContent(
        iconName: "rectangle.slash.fill",
        iconColor: Color(red: 0.99, green: 0.74, blue: 0.04),
        title: "dataError.noData.title",
        message: "dataError.noData.message"
    )

    static let settingsFailed = DataUnavailableContent(
        iconName: "gear",
        iconColor: AppTheme.warning,
        title: "dataError.settings.title",
        message: nil
    )
}

private struct DataUnavailableStateView: View {
    @Environment(\.colorScheme) private var colorScheme

    let content: DataUnavailableContent
    var retryDisabled = false
    var retryAction: (() -> Void)?

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(content.iconColor.opacity(colorScheme == .light ? 0.14 : 0.22))
                        .frame(width: 92, height: 92)

                    Image(systemName: content.iconName)
                        .foregroundStyle(content.iconColor)
                        .font(.system(size: 42, weight: .semibold))
                }
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(content.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    if let message = content.message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                    }
                }

                if let retryAction {
                    Button(action: retryAction) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppTheme.accent)
                    .disabled(retryDisabled)

                    if retryDisabled {
                        Label("dataError.connection.retryDisabled", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0), radius: 18, x: 0, y: 10)

            Spacer()
        }
    }

    private var borderColor: Color {
        AppTheme.cardStroke(for: colorScheme)
    }
}

/// Classify network errors
struct DataDownloadAndError: View {
    @Environment(\.networkManager) var networkManager
    @EnvironmentObject var energyDataService: EnergyDataService

    @State private var displayedDownloadState = EnergyDataService.DownloadState.idle
    @State private var startedShowingLoadingAt: Date?
    @State private var finishLoadingTask: Task<Void, Never>?

    private let minimumLoadingDisplayDuration: TimeInterval = 0.8

    private var actualDownloadStateKey: Int {
        downloadStateKey(for: energyDataService.downloadState)
    }

    private var displayedDownloadStateKey: Int {
        downloadStateKey(for: displayedDownloadState)
    }

    var body: some View {
        ZStack {
            Group {
                if case .downloading = displayedDownloadState {
                    DataRetrievalLoadingView()
                } else if case .failed = displayedDownloadState {
                    DataRetrievalError(networkManager: networkManager)
                } else if let energyData = energyDataService.energyData, energyData.currentPrices.isEmpty {
                    CurrentDataUnavailable()
                } else if energyDataService.energyData == nil {
                    DataRetrievalLoadingView()
                }
            }
            .id(displayedDownloadStateKey)
            .transition(.opacity)
        }
        .padding()
        .animation(.easeInOut(duration: 0.25), value: displayedDownloadStateKey)
        .onAppear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                applyDownloadState(energyDataService.downloadState)
            }
        }
        .onChange(of: actualDownloadStateKey) { _, _ in
            applyDownloadState(energyDataService.downloadState)
        }
        .onDisappear {
            finishLoadingTask?.cancel()
        }
    }

    private func downloadStateKey(for state: EnergyDataService.DownloadState) -> Int {
        switch state {
        case .idle:
            return 0
        case .downloading:
            return 1
        case .failed:
            return 2
        case .finished:
            return 3
        }
    }

    private func applyDownloadState(_ state: EnergyDataService.DownloadState) {
        if case .downloading = state {
            finishLoadingTask?.cancel()
            startedShowingLoadingAt = Date()
            displayedDownloadState = .downloading
            return
        }

        guard case .downloading = displayedDownloadState else {
            displayedDownloadState = state
            return
        }

        let elapsed = Date().timeIntervalSince(startedShowingLoadingAt ?? Date())
        let remaining = max(minimumLoadingDisplayDuration - elapsed, 0)

        finishLoadingTask?.cancel()
        finishLoadingTask = Task { @MainActor in
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }
            displayedDownloadState = state
            startedShowingLoadingAt = nil
        }
    }
}

struct NetworkConnectionErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DataRetrievalLoadingView()
            DataRetrievalError(networkManager: NetworkManager())
                .preferredColorScheme(.light)
            CurrentDataUnavailable()
        }
    }
}
