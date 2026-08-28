//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

enum PricesLayout {
    static let graphTrailingPadding: CGFloat = 12
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
    let taxEnabled: Bool
    let fixedPriceAddOn: Double
    let percentagePriceAddOn: Double
    let orderedAddOns: [PriceAddOnConfiguration]
}

private struct PriceIntervalKey: Hashable {
    let startTime: Date
    let endTime: Date
}

struct PricesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var proSupporterStore: ProSupporterStore

    let onPresentProPaywall: () -> Void

    @AppStorage("priceGraphDisplayInterval") private var storedDisplayInterval = PriceGraphDisplayInterval.defaultInterval.rawValue
    @AppStorage("enlargeHourlyPricesOnInteraction") private var enlargeHourlyPricesOnInteraction = false
    @State private var dataMode = PricesDataMode.current
    @State private var selectedHistoryDate = PriceHistoryDateOptions.defaultDate
    @State private var historyData: EnergyData?
    @State private var historyDownloadFailed = false
    @State private var isDownloadingHistory = false
    @State private var showsHistoryDatePicker = false
    @State private var datePickerHistoryDate = PriceHistoryDateOptions.defaultDate
    @State private var showsDisplayIntervalInfo = false
    @State private var temporarilyShowsPricesWithoutFees = false

    private var pricingConfiguration: PricingConfiguration {
        settingsManager.setting.pricingConfiguration
    }

    private var hasConfiguredFees: Bool {
        settingsManager.setting.baseFeePrice != 0
            || settingsManager.setting.percentagePriceAddOn != 0
            || settingsManager.setting.monthlyFixedCost != 0
    }

    private var pricingConfigurationWithoutFees: PricingConfiguration {
        PricingConfiguration(
            fixedPriceAddOn: 0,
            percentagePriceAddOn: 0,
            taxEnabled: pricingConfiguration.taxEnabled,
            orderedAddOns: pricingConfiguration.orderedAddOns.filter { $0.kind == .tax },
            marketArea: pricingConfiguration.marketArea
        )
    }

    private var visiblePrices: [EnergyPricePoint] {
        let energyData: EnergyData?

        switch dataMode {
        case .current:
            energyData = energyDataService.energyData
        case .history:
            if historyData == nil, isDownloadingHistory {
                energyData = energyDataService.energyData
            } else {
                energyData = historyData
            }
        }

        guard let energyData else { return [] }
        guard temporarilyShowsPricesWithoutFees else {
            return energyData.currentPrices
        }

        return pricesWithoutFees(from: energyData)
    }

    private func pricesWithoutFees(from energyData: EnergyData) -> [EnergyPricePoint] {
        var rawPricesByInterval: [PriceIntervalKey: EnergyPricePoint] = [:]

        for pricePoint in energyData.prices {
            rawPricesByInterval[
                PriceIntervalKey(startTime: pricePoint.startTime, endTime: pricePoint.endTime)
            ] = pricePoint
        }

        let rawVisiblePrices = energyData.currentPrices.compactMap { pricePoint in
            rawPricesByInterval[
                PriceIntervalKey(startTime: pricePoint.startTime, endTime: pricePoint.endTime)
            ]
        }

        return EnergyData.adjustedPrices(
            rawVisiblePrices,
            with: pricingConfigurationWithoutFees
        )
    }

    private var todayEnergyData: EnergyData? {
        guard var energyData = energyDataService.energyData else { return nil }

        let calendar = PriceHistoryDateOptions.calendar(for: pricingConfiguration.marketArea)
        let today = PriceHistoryDateOptions.today(for: pricingConfiguration.marketArea)
        energyData.currentPrices = EnergyData.adjustedPrices(
            energyData.prices.filter { pricePoint in
                calendar.isDate(pricePoint.startTime, inSameDayAs: today)
            }
            .sorted { $0.startTime < $1.startTime },
            with: pricingConfiguration
        )
        return energyData
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

    private var historyRequestKey: PriceHistoryRequestKey {
        PriceHistoryRequestKey(
            mode: dataMode,
            areaKey: pricingConfiguration.marketArea.key,
            selectedDate: selectedHistoryDate,
            taxEnabled: pricingConfiguration.taxEnabled,
            fixedPriceAddOn: pricingConfiguration.fixedPriceAddOn,
            percentagePriceAddOn: pricingConfiguration.percentagePriceAddOn,
            orderedAddOns: pricingConfiguration.orderedAddOns
        )
    }

    init(onPresentProPaywall: @escaping () -> Void = {}) {
        self.onPresentProPaywall = onPresentProPaywall
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if dataMode == .history || hasVisiblePriceData {
                    statusRow

                    if hasVisiblePriceData {
                        graph
                    } else if dataMode == .history {
                        historyUnavailableView
                    } else {
                        DataDownloadAndError()
                    }
                } else {
                    DataDownloadAndError()
                }
            }
            .animation(.easeInOut, value: hasVisiblePriceData)
            .appScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task(id: historyRequestKey) {
            await loadHistoryIfNeeded()
        }
        .onChange(of: proSupporterStore.hasPro) { _, hasPro in
            guard hasPro == false, dataMode == .history else { return }
            resetToCurrentPrices()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            temporarilyShowsPricesWithoutFees = false
        }
        .onChange(of: hasConfiguredFees) { _, hasFees in
            guard hasFees == false else { return }
            temporarilyShowsPricesWithoutFees = false
        }
        .onDisappear {
            temporarilyShowsPricesWithoutFees = false
        }
    }

    private var graph: some View {
        EnergyPriceGraph(
            prices: visiblePrices,
            displayInterval: effectiveDisplayInterval,
            allowsHourlyExpansion: hasFifteenMinutePriceIntervals,
            enlargesHourlyPricesOnInteraction: enlargeHourlyPricesOnInteraction
        )
            .padding(.leading, PricesLayout.graphLeadingPadding)
            .padding(.trailing, PricesLayout.graphTrailingPadding)
            .padding(.bottom, PricesLayout.graphBottomPadding)
            .padding(.top, PricesLayout.graphTopPadding)
    }

    private var statusRow: some View {
        HStack {
            if dataMode == .current {
                currentControls
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
                        .frame(width: 30, height: 30)
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

    private var currentControls: some View {
        dataSelectionMenu
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
        .foregroundStyle(historyDownloadFailed ? AppTheme.error : .blue)
        .accessibilityLabel("Select history date")
        .font(.fCaption)
        .fixedSize(horizontal: true, vertical: false)
        .popover(isPresented: $showsHistoryDatePicker, arrowEdge: .top) {
            historyDatePickerPopover
        }
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
                Label("Refresh".localized(), systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()

            todayHistoryDateButton

            recentHistoryDateButtons

            Button {
                presentHistoryDatePicker()
            } label: {
                Label("Custom date".localized(), systemImage: proSupporterStore.hasPro ? "calendar.badge.clock" : "lock")
            }

            if hasConfiguredFees {
                Divider()

                Toggle(isOn: $temporarilyShowsPricesWithoutFees) {
                    Label("Temporarily show without fees".localized(), systemImage: "tag.slash")
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
        .popover(isPresented: $showsHistoryDatePicker, arrowEdge: .top) {
            historyDatePickerPopover
        }
    }

    private func historySelectionMenu<LabelContent: View>(
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        Menu {
            Button {
                resetToCurrentPrices()
            } label: {
                Label("Upcoming (default)".localized(), systemImage: "bolt")
            }

            Divider()

            todayHistoryDateButton

            recentHistoryDateButtons

            Button {
                presentHistoryDatePicker()
            } label: {
                Label("Custom date".localized(), systemImage: proSupporterStore.hasPro ? "calendar.badge.clock" : "lock")
            }
        } label: {
            label()
        }
    }

    private var todayHistoryDateButton: some View {
        Button {
            selectToday()
        } label: {
            Label("Today".localized(), systemImage: proSupporterStore.hasPro ? "calendar" : "lock")
        }
    }

    private var recentHistoryDateButtons: some View {
        ForEach(PriceHistoryDateOptions.recentDates(for: pricingConfiguration.marketArea), id: \.self) { date in
            Button {
                selectHistoryDate(date)
            } label: {
                Label(
                    PriceHistoryDateOptions.title(for: date, marketArea: pricingConfiguration.marketArea),
                    systemImage: proSupporterStore.hasPro ? "calendar" : "lock"
                )
            }
        }
    }

    private var selectedHistoryDateTitle: String {
        PriceHistoryDateOptions.title(for: selectedHistoryDate, marketArea: pricingConfiguration.marketArea)
    }

    private var widestHistoryDateTitle: String {
        PriceHistoryDateOptions.widestTitle(for: pricingConfiguration.marketArea)
    }

    @ViewBuilder
    private var dataSelectionLabel: some View {
        switch dataMode {
        case .current:
            UpdatedDataView(
                fillsAvailableWidth: false,
                refreshEnabled: false,
                statusOverride: "Prices up to date · Tap for more".localized()
            )
            .layoutPriority(-1)
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

    private var historyDatePickerPopover: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 20)

                Text("Historical prices".localized())
                    .font(.headline)

                Spacer()
            }
            .padding(.top, 18)
            .padding(.horizontal, 20)

            DatePicker(
                "Date".localized(),
                selection: $datePickerHistoryDate,
                in: PriceHistoryDateOptions.selectableRange(for: pricingConfiguration.marketArea),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AppTheme.accent)
            .frame(height: 330)
            .clipped()
        }
        .padding(.vertical)
        .padding(.horizontal, 8)
        .frame(width: 340, height: 400)
        .transaction { transaction in
            transaction.animation = nil
        }
        .presentationCompactAdaptation(.popover)
        .onChange(of: datePickerHistoryDate) { _, newDate in
            showsHistoryDatePicker = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                selectHistoryDate(newDate)
            }
        }
    }

    @MainActor
    private func loadHistoryIfNeeded() async {
        guard dataMode == .history, proSupporterStore.hasPro else { return }

        if PriceHistoryDateOptions.isSameDay(
            selectedHistoryDate,
            PriceHistoryDateOptions.today(for: pricingConfiguration.marketArea),
            marketArea: pricingConfiguration.marketArea
        ) {
            let todayData = todayEnergyData
            historyData = todayData
            historyDownloadFailed = todayData == nil
            isDownloadingHistory = false
            return
        }

        await loadHistory(force: false)
    }

    @MainActor
    private func loadHistory(force: Bool) async {
        guard dataMode == .history, proSupporterStore.hasPro else { return }

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

    private func selectHistoryDate(_ date: Date) {
        guard proSupporterStore.hasPro else {
            onPresentProPaywall()
            return
        }

        temporarilyShowsPricesWithoutFees = false

        if dataMode == .current {
            historyData = nil
        }

        selectedHistoryDate = date
        isDownloadingHistory = true
        historyDownloadFailed = false
        dataMode = .history
    }

    private func selectToday() {
        guard proSupporterStore.hasPro else {
            onPresentProPaywall()
            return
        }

        temporarilyShowsPricesWithoutFees = false
        selectedHistoryDate = PriceHistoryDateOptions.today(for: pricingConfiguration.marketArea)
        let todayData = todayEnergyData
        historyData = todayData
        isDownloadingHistory = false
        historyDownloadFailed = todayData == nil
        dataMode = .history
    }

    private func presentHistoryDatePicker() {
        guard proSupporterStore.hasPro else {
            onPresentProPaywall()
            return
        }

        datePickerHistoryDate = selectedHistoryDate
        showsHistoryDatePicker = true
    }

    private func resetToCurrentPrices() {
        temporarilyShowsPricesWithoutFees = false
        isDownloadingHistory = false
        historyDownloadFailed = false
        historyData = nil
        dataMode = .current
    }
}

private enum PriceHistoryDateOptions {
    static var defaultDate: Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(-24 * 60 * 60)
    }

    static func calendar(for marketArea: MarketArea) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: marketArea.timezone) ?? .current
        return calendar
    }

    static func selectableRange(for marketArea: MarketArea) -> ClosedRange<Date> {
        Date.distantPast...latestSelectableDate(for: marketArea)
    }

    static func recentDates(for marketArea: MarketArea) -> [Date] {
        let calendar = calendar(for: marketArea)
        let today = today(for: marketArea)

        return (1...4).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }
    }

    static func today(for marketArea: MarketArea) -> Date {
        calendar(for: marketArea).startOfDay(for: Date())
    }

    static func latestSelectableDate(for marketArea: MarketArea) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: marketArea.timezone) ?? .current
        let today = calendar.startOfDay(for: Date())

        return calendar.date(byAdding: .day, value: -1, to: today) ?? defaultDate
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date, marketArea: MarketArea) -> Bool {
        let calendar = calendar(for: marketArea)
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func title(for date: Date, marketArea: MarketArea) -> String {
        let calendar = calendar(for: marketArea)

        if calendar.isDateInToday(date) {
            return "Today".localized()
        }

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

    static func widestTitle(for marketArea: MarketArea) -> String {
        let sampleDate = Date(timeIntervalSinceReferenceDate: 0)
        let sampleTitle = title(for: sampleDate, marketArea: marketArea)
        return sampleTitle.count > "Yesterday".localized().count ? sampleTitle : "Yesterday".localized()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        PricesView()
            .environmentObject(EnergyDataService())
            .environmentObject(SettingsManager.shared)
            .environmentObject(ProSupporterStore.preview(hasPro: false))
    }
}
