//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

enum PricesLayout {
    static let graphTrailingPadding: CGFloat = 16
    static let graphTopPadding: CGFloat = 4
    static let graphBottomPadding: CGFloat = 6
    static let graphLeadingPadding: CGFloat = 7
    static let axisLabelSideInset: CGFloat = 8
    static let statusIndicatorWidth: CGFloat = 14
    static let statusTopPadding: CGFloat = 0
    static let statusBottomPadding: CGFloat = 4

    static var statusLeadingPadding: CGFloat {
        graphLeadingPadding + axisLabelSideInset - (statusIndicatorWidth / 2)
    }
}

private enum PricesDataMode: String, CaseIterable, Identifiable {
    case current
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current:
            return "Current".localized()
        case .history:
            return "History".localized()
        }
    }
}

private struct PriceHistoryRequestKey: Hashable {
    let mode: PricesDataMode
    let areaKey: String
    let selectedDate: Date
    let fixedPriceAddOn: Double
    let percentagePriceAddOn: Double
}

struct PricesView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var settingsManager: SettingsManager

    @AppStorage("priceGraphDisplayInterval") private var storedDisplayInterval = PriceGraphDisplayInterval.defaultInterval.rawValue
    @State private var dataMode = PricesDataMode.current
    @State private var selectedHistoryDate = PriceHistoryDateOptions.defaultDate
    @State private var historyData: EnergyData?
    @State private var historyDownloadFailed = false
    @State private var isDownloadingHistory = false
    @State private var showsDisplayIntervalInfo = false

    private var pricingConfiguration: PricingConfiguration {
        settingsManager.setting.pricingConfiguration
    }

    private var visiblePrices: [EnergyPricePoint] {
        switch dataMode {
        case .current:
            return energyDataService.energyData?.currentPrices ?? []
        case .history:
            if historyData == nil, isDownloadingHistory {
                return energyDataService.energyData?.currentPrices ?? []
            }

            return historyData?.currentPrices ?? []
        }
    }

    private var hasVisiblePriceData: Bool {
        visiblePrices.isEmpty == false
    }

    private var hasFifteenMinutePriceIntervals: Bool {
        visiblePrices.contains { pricePoint in
            abs(pricePoint.endTime.timeIntervalSince(pricePoint.startTime) - TimeInterval(15 * 60)) < 1
        }
    }

    private var effectiveDisplayInterval: PriceGraphDisplayInterval {
        hasFifteenMinutePriceIntervals ? displayInterval : .sixtyMinutes
    }

    private var displayInterval: PriceGraphDisplayInterval {
        PriceGraphDisplayInterval(rawValue: storedDisplayInterval) ?? .defaultInterval
    }

    private var displayIntervalBinding: Binding<PriceGraphDisplayInterval> {
        Binding {
            displayInterval
        } set: { newValue in
            storedDisplayInterval = newValue.rawValue
        }
    }

    private var historyDates: [Date] {
        PriceHistoryDateOptions.dates(for: pricingConfiguration.marketArea)
    }

    private var historyRequestKey: PriceHistoryRequestKey {
        PriceHistoryRequestKey(
            mode: dataMode,
            areaKey: pricingConfiguration.marketArea.key,
            selectedDate: selectedHistoryDate,
            fixedPriceAddOn: pricingConfiguration.fixedPriceAddOn,
            percentagePriceAddOn: pricingConfiguration.percentagePriceAddOn
        )
    }

    private var graphIdentity: String {
        switch dataMode {
        case .current:
            return "current"
        case .history:
            return historyData == nil && isDownloadingHistory ? "current" : "history"
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if dataMode == .history {
                    statusRow

                    if hasVisiblePriceData {
                        graph
                    } else {
                        historyUnavailableView
                    }
                } else if hasVisiblePriceData {
                    statusRow

                    graph
                } else {
                    DataDownloadAndError()
                }
            }
            .appScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.22), value: graphIdentity)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task(id: historyRequestKey) {
            await loadHistoryIfNeeded()
        }
    }

    private var graph: some View {
        EnergyPriceGraph(
            prices: visiblePrices,
            displayInterval: effectiveDisplayInterval,
            allowsHourlyExpansion: hasFifteenMinutePriceIntervals
        )
            .id(graphIdentity)
            .transition(.opacity)
            .padding(.leading, PricesLayout.graphLeadingPadding)
            .padding(.trailing, PricesLayout.graphTrailingPadding)
            .padding(.bottom, PricesLayout.graphBottomPadding)
            .padding(.top, PricesLayout.graphTopPadding)
    }

    private var statusRow: some View {
        HStack {
            if dataMode == .current {
                dataSelectionMenu
                    .padding(.leading, 2)
            } else {
                historyControls
            }
            
            Spacer(minLength: 8)

            if hasFifteenMinutePriceIntervals {
                intervalPicker

                Button {
                    showsDisplayIntervalInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Price graph interval info")
            }
        }
        .padding(.leading, PricesLayout.statusLeadingPadding)
        .padding(.trailing, PricesLayout.graphTrailingPadding)
        .padding(.top, PricesLayout.statusTopPadding)
        .padding(.bottom, PricesLayout.statusBottomPadding)
        .alert("", isPresented: $showsDisplayIntervalInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("60m (recommended): Better readability showing the hourly averages. Tap an hour for 15-min prices.\n\n15m: See all price points directly.")
        }
    }

    private var historyControls: some View {
        historySelectionMenu {
            HStack(spacing: 4) {
                historyModeIcon

                selectedHistoryDateLabel
            }
            .padding(.vertical, 8)
            .padding(.trailing, 10)
            .contentShape(Rectangle())
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(historyDownloadFailed ? AppTheme.error : .secondary)
            .accessibilityLabel("Select history date")
        .font(.fCaption)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var selectedHistoryDateLabel: some View {
        ZStack(alignment: .leading) {
            Text(widestHistoryDateTitle)
                .font(.fCaption)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .hidden()

            Text(selectedHistoryDateTitle)
                .font(.fCaption)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    private var historyModeIcon: some View {
        if isDownloadingHistory {
            ProgressView()
                .frame(width: PricesLayout.statusIndicatorWidth, height: PricesLayout.statusIndicatorWidth)
                .scaleEffect(0.7, anchor: .center)
                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
        } else if historyDownloadFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .imageScale(.medium)
                .frame(width: PricesLayout.statusIndicatorWidth, height: PricesLayout.statusIndicatorWidth)
        } else {
            Image(systemName: "clock.arrow.circlepath")
                .imageScale(.medium)
                .frame(width: PricesLayout.statusIndicatorWidth, height: PricesLayout.statusIndicatorWidth)
        }
    }

    private var dataSelectionMenu: some View {
        Menu {
            Button {
                energyDataService.download(setting: settingsManager.setting)
            } label: {
                Label("Refresh".localized(), systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                isDownloadingHistory = false
                dataMode = .current
            } label: {
                Label("Current".localized(), systemImage: "bolt")
            }

            Divider()

            ForEach(historyDates, id: \.self) { date in
                Button {
                    if dataMode == .current {
                        historyData = nil
                    }
                    selectedHistoryDate = date
                    isDownloadingHistory = true
                    historyDownloadFailed = false
                    dataMode = .history
                } label: {
                    Label(
                        PriceHistoryDateOptions.title(for: date, marketArea: pricingConfiguration.marketArea),
                        systemImage: "calendar"
                    )
                }
            }
        } label: {
            dataSelectionLabel
                .padding(.vertical, 8)
                .padding(.trailing, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Price data selection")
    }

    private func historySelectionMenu<LabelContent: View>(
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        Menu {
            Button {
                isDownloadingHistory = false
                dataMode = .current
            } label: {
                Label("Current".localized(), systemImage: "bolt")
            }

            Divider()

            ForEach(historyDates, id: \.self) { date in
                Button {
                    selectedHistoryDate = date
                    isDownloadingHistory = true
                    historyDownloadFailed = false
                    dataMode = .history
                } label: {
                    Label(
                        PriceHistoryDateOptions.title(for: date, marketArea: pricingConfiguration.marketArea),
                        systemImage: "calendar"
                    )
                }
            }
        } label: {
            label()
        }
    }

    private var selectedHistoryDateTitle: String {
        PriceHistoryDateOptions.title(for: selectedHistoryDate, marketArea: pricingConfiguration.marketArea)
    }

    private var widestHistoryDateTitle: String {
        historyDates
            .map { PriceHistoryDateOptions.title(for: $0, marketArea: pricingConfiguration.marketArea) }
            .max { $0.count < $1.count } ?? selectedHistoryDateTitle
    }

    @ViewBuilder
    private var dataSelectionLabel: some View {
        switch dataMode {
        case .current:
            UpdatedDataView(
                fillsAvailableWidth: false,
                refreshEnabled: false,
                statusOverride: "Current prices · Tap for history".localized()
            )
        case .history:
            EmptyView()
        }
    }

    private var historyUnavailableView: some View {
        VStack(spacing: 18) {
            Spacer()

            if isDownloadingHistory {
                ProgressView("Loading history".localized())
            } else {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(historyDownloadFailed ? AppTheme.error : AppTheme.accent)

                Text(historyDownloadFailed ? "Couldn't get history".localized() : "No history data available".localized())
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Button {
                    Task { await loadHistory(force: true) }
                } label: {
                    Label("Retry".localized(), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }

            Spacer()
        }
        .padding()
    }

    private var intervalPicker: some View {
        Picker("Price graph interval", selection: displayIntervalBinding) {
            ForEach(PriceGraphDisplayInterval.allCases) { interval in
                Text(interval.title)
                    .tag(interval)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 104)
    }

    @MainActor
    private func loadHistoryIfNeeded() async {
        guard dataMode == .history else { return }
        await loadHistory(force: false)
    }

    @MainActor
    private func loadHistory(force: Bool) async {
        guard dataMode == .history else { return }

        if
            !force,
            var existingHistoryData = historyData,
            existingHistoryData.area == pricingConfiguration.marketArea.key
        {
            let containsSelectedDate = existingHistoryData.currentPrices.contains { pricePoint in
                PriceHistoryDateOptions.isSameDay(
                    pricePoint.startTime,
                    selectedHistoryDate,
                    marketArea: pricingConfiguration.marketArea
                )
            }
            if containsSelectedDate {
                existingHistoryData.computeValues(
                    with: pricingConfiguration,
                    includesPastPrices: true
                )
                historyData = existingHistoryData
                isDownloadingHistory = false
                return
            }
        }

        isDownloadingHistory = true
        historyDownloadFailed = false
        defer {
            isDownloadingHistory = false
        }

        do {
            var downloadedHistoryData = try await EnergyData.downloadHistory(
                marketArea: pricingConfiguration.marketArea,
                date: selectedHistoryDate
            )
            downloadedHistoryData.computeValues(
                with: pricingConfiguration,
                includesPastPrices: true
            )
            historyData = downloadedHistoryData
        } catch {
            guard !Self.isCancellation(error) else { return }
            historyData = nil
            historyDownloadFailed = true
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return (error as NSError).code == NSURLErrorCancelled
    }
}

private enum PriceHistoryDateOptions {
    static var defaultDate: Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(-24 * 60 * 60)
    }

    static func dates(for marketArea: MarketArea) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: marketArea.timezone) ?? .current
        let today = calendar.startOfDay(for: Date())

        return (1...14).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date, marketArea: MarketArea) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: marketArea.timezone) ?? .current
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func title(for date: Date, marketArea: MarketArea) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: marketArea.timezone) ?? .current

        if
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())),
            calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Yesterday".localized()
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        PricesView()
    }
}
