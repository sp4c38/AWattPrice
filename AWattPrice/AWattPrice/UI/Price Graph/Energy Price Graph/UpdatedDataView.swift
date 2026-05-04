//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

/// Simillar to the built in RelativeDateTimeFormatter but fitted to the needs of the AWattPrice App.
final class UpdatedDataTimeFormatter {
    func localizedTimeString(for startDate: Date, relativeTo endDate: Date) -> String {
        let timeIntervalBetween = startDate.timeIntervalSince(endDate)

        if timeIntervalBetween < 60 {
            return "Updated just now".localized()
        } else {
            // More than one minute ago
            let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = 0
            let minutesBetweenString = numberFormatter.string(from: NSNumber(value: (timeIntervalBetween / 60).rounded(.down)))
            guard let _ = minutesBetweenString else { return "" }

            var localizableString = ""
            if timeIntervalBetween < 120 {
                localizableString = "updateDataTimeFormatter.moreThanMMAgoSingular"
            } else {
                localizableString = "updateDataTimeFormatter.moreThanMMAgoPlural"
            }

            return String(format: localizableString.localized(), minutesBetweenString!)
        }
    }
}

struct UpdatedDataView: View {
    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var settingsManager: SettingsManager

    private let fillsAvailableWidth: Bool

    @State private var now = Date()
    @State private var lastSuccessfulUpdate: Date?
    @State private var displayedDownloadState = EnergyDataService.DownloadState.idle
    @State private var startedShowingDownloadAt: Date?
    @State private var finishDisplayTask: Task<Void, Never>?

    private let dateFormatter = UpdatedDataTimeFormatter()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let minimumDownloadingDisplayDuration: TimeInterval = 0.8

    init(fillsAvailableWidth: Bool = true) {
        self.fillsAvailableWidth = fillsAvailableWidth
    }

    private var actualDownloadStateKey: Int {
        downloadStateKey(for: energyDataService.downloadState)
    }

    private var displayedDownloadStateKey: Int {
        downloadStateKey(for: displayedDownloadState)
    }

    private func downloadStateKey(for downloadState: EnergyDataService.DownloadState) -> Int {
        switch downloadState {
        case .idle:
            return 0
        case .downloading:
            return 1
        case .finished:
            return 2
        case .failed:
            return 3
        }
    }

    private var statusText: String {
        switch displayedDownloadState {
        case .downloading:
            return "Refreshing".localized()
        case .failed:
            return "Couldn't get new data. Tap to retry.".localized()
        case .finished(let time):
            return dateFormatter.localizedTimeString(for: now, relativeTo: time)
        case .idle:
            if let lastSuccessfulUpdate {
                return dateFormatter.localizedTimeString(for: now, relativeTo: lastSuccessfulUpdate)
            }
            return "Prices loaded".localized()
        }
    }

    private var statusColor: Color {
        switch displayedDownloadState {
        case .downloading:
            return .secondary
        case .failed:
            return AppTheme.error
        case .idle, .finished:
            return .secondary
        }
    }
    
    private var isDownloading: Bool {
        if case .downloading = energyDataService.downloadState {
            return true
        }

        return false
    }

    var body: some View {
        Button(action: refreshData) {
            statusContent
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
        .animation(.easeInOut, value: displayedDownloadStateKey)
        .accessibilityLabel(statusText)
        .onAppear {
            updateLastSuccessfulDownload(from: energyDataService.downloadState)
            applyDownloadState(energyDataService.downloadState)
        }
        .onChange(of: actualDownloadStateKey) { _, _ in
            updateLastSuccessfulDownload(from: energyDataService.downloadState)
            applyDownloadState(energyDataService.downloadState)
        }
        .onReceive(timer) { date in
            now = date
        }
    }

    private var statusContent: some View {
        HStack(spacing: 7) {
            StatusIndicator(downloadState: displayedDownloadState)

            Text(statusText)
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .transition(.opacity)

            if fillsAvailableWidth {
                Spacer()
            }
        }
        .font(.fCaption)
        .fixedSize(horizontal: fillsAvailableWidth == false, vertical: false)
        .contentShape(Rectangle())
    }

    private func refreshData() {
        guard isDownloading == false else { return }
        energyDataService.download(setting: settingsManager.setting)
    }

    private func updateLastSuccessfulDownload(from downloadState: EnergyDataService.DownloadState) {
        if case .finished(let time) = downloadState {
            lastSuccessfulUpdate = time
            now = Date()
        }
    }

    private func applyDownloadState(_ downloadState: EnergyDataService.DownloadState) {
        if case .downloading = downloadState {
            finishDisplayTask?.cancel()
            startedShowingDownloadAt = Date()
            displayedDownloadState = .downloading
            return
        }

        guard case .downloading = displayedDownloadState else {
            displayedDownloadState = downloadState
            return
        }

        let elapsedDisplayTime = Date().timeIntervalSince(startedShowingDownloadAt ?? Date())
        let remainingDisplayTime = max(minimumDownloadingDisplayDuration - elapsedDisplayTime, 0)

        finishDisplayTask?.cancel()
        finishDisplayTask = Task { @MainActor in
            if remainingDisplayTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingDisplayTime * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }
            displayedDownloadState = downloadState
            startedShowingDownloadAt = nil
            updateLastSuccessfulDownload(from: downloadState)
        }
    }
}

private struct StatusIndicator: View {
    let downloadState: EnergyDataService.DownloadState

    var body: some View {
        Group {
            switch downloadState {
            case .downloading:
                ProgressView()
                    .frame(width: 13, height: 13)
                    .scaleEffect(0.7, anchor: .center)
                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(AppTheme.error)
            case .idle, .finished:
                PulsingStatusDot()
            }
        }
        .frame(width: PricesLayout.statusIndicatorWidth, height: PricesLayout.statusIndicatorWidth)
        .accessibilityHidden(true)
    }
}

private struct PulsingStatusDot: View {
    private let pulseDuration: TimeInterval = 2.1

    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: pulseDuration) / pulseDuration

            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.65 * (1 - progress)))
                    .frame(width: 8 + (12 * progress), height: 8 + (12 * progress))

                Circle()
                    .fill(AppTheme.success)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
            .environmentObject(EnergyDataService())
            .environmentObject(SettingsManager.shared)
    }
}
