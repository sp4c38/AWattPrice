//
//  InsightsView.swift
//  AWattPrice
//
//  Created by Codex on 28.04.26.
//

import SwiftUI
import Charts

private let insightsAccent = AppTheme.accent

private struct PriceWindow: Identifiable {
    let id = UUID()
    let title: String
    let startTime: Date
    let endTime: Date
    let averagePrice: Double
}

private struct InsightsModel {
    let prices: [EnergyPricePoint]

    private var now: Date { Date() }

    var currentPrice: EnergyPricePoint? {
        prices.first { $0.startTime <= now && $0.endTime > now } ?? prices.first
    }

    var averagePrice: Double? {
        weightedAverage(for: prices)
    }

    var minPrice: EnergyPricePoint? {
        prices.min(by: EnergyPricePoint.marketpricesAreInIncreasingOrder)
    }

    var maxPrice: EnergyPricePoint? {
        prices.max(by: EnergyPricePoint.marketpricesAreInIncreasingOrder)
    }

    var priceRange: ClosedRange<Double>? {
        guard let minPrice, let maxPrice else { return nil }
        return minPrice.marketprice...maxPrice.marketprice
    }

    var averageTimeRange: (startTime: Date, endTime: Date)? {
        guard let firstPrice = prices.first, let lastPrice = prices.last else { return nil }
        return (firstPrice.startTime, lastPrice.endTime)
    }

    var cheapestWindows: [PriceWindow] {
        [
            priceWindow(duration: 60 * 60, title: "1h usage", prefersLowerAverage: true),
            priceWindow(duration: 2 * 60 * 60, title: "2h usage", prefersLowerAverage: true),
            priceWindow(duration: 4 * 60 * 60, title: "4h usage", prefersLowerAverage: true),
        ]
        .compactMap { $0 }
    }

    var mostExpensiveWindows: [PriceWindow] {
        [
            priceWindow(duration: 60 * 60, title: "1h usage", prefersLowerAverage: false),
            priceWindow(duration: 2 * 60 * 60, title: "2h usage", prefersLowerAverage: false),
            priceWindow(duration: 4 * 60 * 60, title: "4h usage", prefersLowerAverage: false),
        ]
        .compactMap { $0 }
    }

    func rangePosition(for price: Double) -> CGFloat {
        guard
            let priceRange,
            priceRange.upperBound > priceRange.lowerBound
        else {
            return 0.5
        }

        return CGFloat((price - priceRange.lowerBound) / (priceRange.upperBound - priceRange.lowerBound))
    }

    private func priceWindow(duration: TimeInterval, title: String, prefersLowerAverage: Bool) -> PriceWindow? {
        guard prices.isEmpty == false else { return nil }

        var selectedWindow: PriceWindow?

        for startIndex in prices.indices {
            var selectedPrices: [EnergyPricePoint] = []
            var endIndex = startIndex

            while endIndex < prices.endIndex,
                  prices[endIndex].endTime.timeIntervalSince(prices[startIndex].startTime) <= duration {
                selectedPrices.append(prices[endIndex])
                endIndex += 1
            }

            guard
                let firstPrice = selectedPrices.first,
                let lastPrice = selectedPrices.last,
                lastPrice.endTime.timeIntervalSince(firstPrice.startTime) >= duration,
                let averagePrice = weightedAverage(for: selectedPrices)
            else {
                continue
            }

            let window = PriceWindow(
                title: title,
                startTime: firstPrice.startTime,
                endTime: lastPrice.endTime,
                averagePrice: averagePrice
            )

            if selectedWindow == nil ||
                (prefersLowerAverage && window.averagePrice < selectedWindow!.averagePrice) ||
                (!prefersLowerAverage && window.averagePrice > selectedWindow!.averagePrice)
            {
                selectedWindow = window
            }
        }

        return selectedWindow
    }

    private func weightedAverage(for prices: [EnergyPricePoint]) -> Double? {
        guard prices.isEmpty == false else { return nil }

        let totalDuration = prices.reduce(0) { partialResult, pricePoint in
            partialResult + pricePoint.endTime.timeIntervalSince(pricePoint.startTime)
        }

        guard totalDuration > 0 else { return nil }

        let weightedSum = prices.reduce(0) { partialResult, pricePoint in
            let duration = pricePoint.endTime.timeIntervalSince(pricePoint.startTime)
            return partialResult + pricePoint.marketprice * duration
        }

        return weightedSum / totalDuration
    }
}

private struct InsightsCard<Content: View>: View {
    let tint: Color?
    @ViewBuilder let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(cornerRadius: 16, padding: 0)
    }
}

private struct InsightsSectionTitle: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .font(.headline)
    }
}

private struct PriceWindowRow: View {
    let window: PriceWindow
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(tint.opacity(0.75))
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeRangeText(from: window.startTime, to: window.endTime))
                      .font(.subheadline.weight(.semibold))

                Text(window.title)
                      .font(.caption)
                      .bold()
                      .foregroundStyle(.secondary)
              }

            Spacer()

            Text(priceText(window.averagePrice))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct PriceRangeGraph: View {
    let model: InsightsModel

    private let railY: CGFloat = 52
    private let currentLabelY: CGFloat = 27
    private let currentLabelWidth: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.12))
                        .frame(height: 8)
                        .position(x: geometry.size.width / 2, y: railY)

                    if let minPrice = model.minPrice {
                        PriceRangeMarker(
                            label: "Lowest",
                            price: minPrice.marketprice,
                            tint: AppTheme.success
                        )
                        .position(x: markerX(for: minPrice.marketprice, width: geometry.size.width), y: railY)
                    }

                    if let averagePrice = model.averagePrice {
                        PriceRangeMarker(
                            label: "Average",
                            price: averagePrice,
                            tint: Color.secondary
                        )
                        .position(x: markerX(for: averagePrice, width: geometry.size.width), y: railY)
                    }

                    if let maxPrice = model.maxPrice {
                        PriceRangeMarker(
                            label: "Highest",
                            price: maxPrice.marketprice,
                            tint: AppTheme.error
                        )
                        .position(x: markerX(for: maxPrice.marketprice, width: geometry.size.width), y: railY)
                    }

                    if let currentPrice = model.currentPrice {
                        CurrentPriceRangeMarker(
                            price: currentPrice.marketprice,
                            tint: insightsAccent,
                            connectorHeight: 14
                        )
                        .position(
                            x: currentLabelX(for: currentPrice.marketprice, width: geometry.size.width),
                            y: currentLabelY
                        )
                    }
                }
            }
            .frame(height: 68)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rangeAccessibilityLabel)

            HStack(alignment: .top, spacing: 8) {
                RangeValueLabel(
                    title: "Lowest",
                    value: model.minPrice?.marketprice,
                    subtitle: model.minPrice.map { timeRangeText(from: $0.startTime, to: $0.endTime) },
                    alignment: .leading,
                    tint: AppTheme.success
                )
                Spacer()
                RangeValueLabel(
                    title: "Average",
                    value: model.averagePrice,
                    subtitle: nil,
                    alignment: .center,
                    tint: Color.secondary
                )
                Spacer()
                RangeValueLabel(
                    title: "Highest",
                    value: model.maxPrice?.marketprice,
                    subtitle: model.maxPrice.map { timeRangeText(from: $0.startTime, to: $0.endTime) },
                    alignment: .trailing,
                    tint: AppTheme.error
                )
            }
        }
    }

    private var rangeAccessibilityLabel: String {
        String.localizedStringWithFormat(
            NSLocalizedString("Price range from %@ to %@, average %@", comment: "Accessibility label for the insights price range"),
            priceText(model.minPrice?.marketprice),
            priceText(model.maxPrice?.marketprice),
            priceText(model.averagePrice)
        )
    }

    private func markerX(for price: Double, width: CGFloat) -> CGFloat {
        min(max(model.rangePosition(for: price) * width, 8), max(width - 8, 8))
    }

    private func currentLabelX(for price: Double, width: CGFloat) -> CGFloat {
        let halfWidth = currentLabelWidth / 2
        return min(
            max(model.rangePosition(for: price) * width, halfWidth),
            max(width - halfWidth, halfWidth)
        )
    }
}

private struct PriceRangeMarker: View {
    let label: LocalizedStringKey
    let price: Double
    let tint: Color

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                    .stroke(.background, lineWidth: 3)
            }
            .shadow(color: tint.opacity(0.24), radius: 4, y: 2)
            .accessibilityLabel(label)
            .accessibilityValue(priceText(price))
    }
}

private struct CurrentPriceRangeMarker: View {
    let price: Double
    let tint: Color
    let connectorHeight: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            VStack(alignment: .center, spacing: 3) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)

                    Text("Current")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(priceText(price))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Rectangle()
                .fill(tint.opacity(0.45))
                .frame(width: 2, height: connectorHeight)

            Circle()
                .fill(tint)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .stroke(.background, lineWidth: 3)
                }
                .shadow(color: tint.opacity(0.24), radius: 4, y: 2)
        }
        .frame(width: 112)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current")
        .accessibilityValue(priceText(price))
    }
}

private struct RangeValueLabel: View {
    let title: LocalizedStringKey
    let value: Double?
    let subtitle: String?
    let alignment: HorizontalAlignment
    let tint: Color

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(priceText(value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(textAlignment)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(textAlignment)
            }
        }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }
}

private struct GenerationMixCard: View {
    let generationMix: GenerationMixData

    private var visibleCategories: [GenerationMixCategory] {
        generationMix.visibleCategories
    }

    var body: some View {
        InsightsCard(tint: AppTheme.success) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    InsightsSectionTitle(
                        title: "Renewable mix",
                        systemImage: "leaf.fill",
                        tint: AppTheme.success
                    )

                    Spacer()

                    NavigationLink {
                        GenerationMixHistoryView()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Last 24h")
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(percentText(generationMix.renewableShare))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()

                    Text("renewable")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                GenerationMixBar(categories: visibleCategories)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Generation mix")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], alignment: .leading, spacing: 8) {
                        ForEach(visibleCategories) { category in
                            GenerationMixCategoryLabel(category: category)
                        }
                    }
                }

                Text(generationMixFreshnessText(generationMix.endTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private enum GenerationMixHistoryLoadState {
    case loading
    case loaded(GenerationMixHistoryData)
    case failed
}

private struct GenerationMixHistoryView: View {
       @EnvironmentObject private var energyDataService: EnergyDataService
       @EnvironmentObject private var settingsManager: SettingsManager

    private var marketArea: MarketArea {
        settingsManager.setting.marketArea
        }

    @State private var loadState: GenerationMixHistoryLoadState = .loading

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                         .tint(AppTheme.success)

                    Text("Loading generation mix")
                         .font(.subheadline.weight(.semibold))
                         .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let history):
                GenerationMixHistoryContent(history: history)
            case .failed:
                VStack(spacing: 14) {
                    Image(systemName: "leaf")
                         .font(.largeTitle)
                         .foregroundStyle(AppTheme.success)

                    Text("Generation mix unavailable")
                         .font(.headline)

                    Button("Try Again") {
                        Task { await loadHistory() }
                      }
                      .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                 }
              }
              .appScreenBackground()
              .navigationTitle("Last 24h")
              .navigationBarTitleDisplayMode(.large)
              .task(id: marketArea.key) {
                 await loadHistory()
                }
              }

    private func loadHistory() async {
        loadState = .loading

        if let cached = energyDataService.generationMixHistoryData {
            loadState = .loaded(cached)
          }

        do {
            let history = try await GenerationMixHistoryData.download(marketArea: marketArea)
            energyDataService.generationMixHistoryData = history
            loadState = .loaded(history)
           } catch {
               print("Generation mix history download failed: \(error).")
            }
         }
     }

private struct GenerationMixHistoryContent: View {
    let history: GenerationMixHistoryData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InsightsCard(tint: AppTheme.success) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Renewable mix")
                            .font(.headline)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(percentText(history.renewableShare))
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .monospacedDigit()

                            Text("renewable")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(historyRangeText(from: history.startTime, to: history.endTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                InsightsCard(tint: AppTheme.success) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generation mix")
                            .font(.headline)

                        GenerationMixBar(categories: history.visibleCategories)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], alignment: .leading, spacing: 8) {
                            ForEach(history.visibleCategories) { category in
                                GenerationMixCategoryLabel(category: category)
                            }
                        }
                    }
                }

                InsightsCard(tint: AppTheme.success) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 24h")
                            .font(.headline)

                        GenerationMixStackedAreaChart(history: history)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .appReadableContent(maxWidth: 980)
        }
    }
}

private struct GenerationMixChartPoint: Identifiable {
    let id: String
    let time: Date
    let category: String
    let generationMW: Double
}

private struct GenerationMixStackedAreaChart: View {
    let history: GenerationMixHistoryData

    private var chartPoints: [GenerationMixChartPoint] {
        history.sortedIntervals.flatMap { interval in
            history.orderedCategories.map { category in
                let intervalCategory = interval.categories.first { $0.category == category.category }
                return GenerationMixChartPoint(
                    id: "\(interval.startTime.timeIntervalSince1970)-\(category.category)",
                    time: interval.startTime,
                    category: category.category,
                    generationMW: intervalCategory?.generationMW ?? 0
                )
            }
        }
    }

    private var categoryDomain: [String] {
        history.orderedCategories.map(\.category)
    }

    private var categoryColors: [Color] {
        categoryDomain.map(generationMixColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(chartPoints) { point in
                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("Generation", point.generationMW),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Category", point.category))
                .interpolationMethod(.linear)
            }
            .chartForegroundStyleScale(domain: categoryDomain, range: categoryColors)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.14))
                    AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.14))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Generation mix")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], alignment: .leading, spacing: 8) {
                ForEach(history.orderedCategories) { category in
                    GenerationMixCompactLegendItem(category: category)
                }
            }
        }
    }
}

private struct GenerationMixCompactLegendItem: View {
    let category: GenerationMixCategory
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(generationMixColor(for: category.category))
                .frame(width: 7, height: 7)

            Text(shortGenerationMixTitle(for: category.category))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct GenerationMixLoadingCard: View {
    var body: some View {
        InsightsCard(tint: AppTheme.success) {
            VStack(alignment: .leading, spacing: 14) {
                InsightsSectionTitle(
                    title: "Renewable mix",
                    systemImage: "leaf.fill",
                    tint: AppTheme.success
                )

                HStack(spacing: 10) {
                    ProgressView()
                        .tint(AppTheme.success)

                    Text("Loading generation mix")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                GenerationMixPlaceholderBar()
            }
        }
    }
}

private struct GenerationMixUnavailableCard: View {
    var body: some View {
        InsightsCard(tint: AppTheme.success) {
            VStack(alignment: .leading, spacing: 10) {
                InsightsSectionTitle(
                    title: "Renewable mix",
                    systemImage: "leaf.fill",
                    tint: AppTheme.success
                )

                Text("Generation mix unavailable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GenerationMixPlaceholderBar: View {
    var body: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(AppTheme.success.opacity(0.22))
                .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(AppTheme.accent.opacity(0.18))
                .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.secondary.opacity(0.14))
                .frame(maxWidth: .infinity)
        }
        .frame(height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct GenerationMixBar: View {
    let categories: [GenerationMixCategory]
    private let segmentSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - segmentSpacing * CGFloat(max(categories.count - 1, 0)), 0)

            HStack(spacing: segmentSpacing) {
                ForEach(categories) { category in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(generationMixColor(for: category.category))
                        .frame(width: availableWidth * CGFloat(category.share / 100))
                }
            }
        }
        .frame(height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Generation mix")
    }
}

private struct GenerationMixCategoryLabel: View {
    let category: GenerationMixCategory

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(generationMixColor(for: category.category))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(generationMixTitle(for: category.category))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text("\(percentText(category.share)) · \(megawattText(category.generationMW))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(generationMixAccessibilityText(category))
    }
}

struct InsightsView: View {
     @EnvironmentObject private var energyDataService: EnergyDataService
     @EnvironmentObject private var settingsManager: SettingsManager
     @AppStorage("pendingDeepLinkDestination") private var pendingDeepLinkDestination = ""
     @State private var navigateToCheapestTime = false

    private var prices: [EnergyPricePoint] {
        energyDataService.energyData?.currentPrices ?? []
      }

    private var model: InsightsModel {
        InsightsModel(prices: prices)
      }

    private var generationMix: GenerationMixData? {
        energyDataService.generationMixData
      }

    private var cachedHistory: GenerationMixHistoryData? {
        energyDataService.generationMixHistoryData
      }

     @ViewBuilder
    private var generationMixSection: some View {
        if let generationMix {
            GenerationMixCard(generationMix: generationMix)
                 .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
          } else {
            switch energyDataService.generationMixDownloadState {
            case .downloading:
                GenerationMixLoadingCard()
                     .transition(.opacity)
            case .failed:
                GenerationMixUnavailableCard()
                     .transition(.opacity)
            case .idle, .finished:
                EmptyView()
              }
          }
      }

    var body: some View {
        NavigationStack {
            Group {
                if prices.isEmpty {
                    DataDownloadAndError()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            InsightsCard(tint: AppTheme.success) {
                                HStack {
                                    InsightsSectionTitle(
                                        title: "Cheapest times",
                                        systemImage: "timer",
                                        tint: AppTheme.success
                                    )

                                    Spacer()

                                    NavigationLink {
                                        CheapestTimeView()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text("Custom")
                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.bold))
                                        }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.accent)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Open Cheapest Time")
                                }

                                ForEach(model.cheapestWindows) { window in
                                    PriceWindowRow(window: window, tint: AppTheme.success)
                                }
                            }

                            InsightsCard(tint: AppTheme.error) {
                                InsightsSectionTitle(
                                    title: "Most expensive times",
                                    systemImage: "exclamationmark.triangle.fill",
                                    tint: AppTheme.error
                                )

                                ForEach(model.mostExpensiveWindows) { window in
                                    PriceWindowRow(window: window, tint: AppTheme.error)
                                }
                            }
                            
                            InsightsCard(tint: AppTheme.accent) {
                                VStack(alignment: .leading, spacing: 17) {
                                    InsightsSectionTitle(
                                        title: "Price range",
                                        systemImage: "chart.bar.fill",
                                        tint: AppTheme.accent
                                    )
                                    
                                    PriceRangeGraph(model: model)
                                }
                            }

                            generationMixSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .appReadableContent(maxWidth: 980)
                        .animation(.easeInOut(duration: 0.2), value: generationMix != nil)
                        .animation(.easeInOut(duration: 0.2), value: generationMixStateAnimationValue)
                    }
                }
            }
            .appScreenBackground()
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $navigateToCheapestTime) {
                CheapestTimeView()
            }
            .onAppear(perform: handlePendingDeepLink)
            .onChange(of: pendingDeepLinkDestination) {
                handlePendingDeepLink()
            }
        }
    }

    private func handlePendingDeepLink() {
        guard pendingDeepLinkDestination == AppDeepLinkDestination.cheapestTime.rawValue else { return }

        pendingDeepLinkDestination = ""
        navigateToCheapestTime = true
    }

    private var generationMixStateAnimationValue: String {
        switch energyDataService.generationMixDownloadState {
        case .idle:
            return "idle"
        case .downloading:
            return "downloading"
        case .failed:
            return "failed"
        case .finished:
            return "finished"
        }
    }
}

private func priceText(_ price: Double?) -> String {
    guard let price else { return "-" }
    let formattedPrice = price.priceString.flatMap { $0.isEmpty ? "0.00" : $0 } ?? "0.00"
    return "\(formattedPrice) ct"
}

private func percentText(_ value: Double) -> String {
    (value / 100).formatted(.percent.precision(.fractionLength(0)))
}

private func megawattText(_ value: Double) -> String {
    "\(value.formatted(.number.precision(.fractionLength(0)))) MW"
}

private func timeText(_ date: Date) -> String {
    date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
}

private func generationMixFreshnessText(_ date: Date) -> String {
    String.localizedStringWithFormat(
        NSLocalizedString("Data until %@", comment: "Freshness text for generation mix data"),
        timeText(date)
    )
}

private func historyRangeText(from startTime: Date, to endTime: Date) -> String {
    String.localizedStringWithFormat(
        NSLocalizedString("Data from %@ to %@", comment: "Time range text for generation mix history"),
        timeText(startTime),
        timeText(endTime)
    )
}

private func generationMixAccessibilityText(_ category: GenerationMixCategory) -> String {
    "\(generationMixLocalizedTitle(for: category.category)), \(percentText(category.share)), \(megawattText(category.generationMW))"
}

private func historyIntervalAccessibilityText(_ interval: GenerationMixInterval) -> String {
    String.localizedStringWithFormat(
        NSLocalizedString("%@, renewable mix %@", comment: "Accessibility label for one generation mix history interval"),
        timeRangeText(from: interval.startTime, to: interval.endTime),
        percentText(interval.renewableShare)
    )
}

private func timeRangeText(from startTime: Date, to endTime: Date) -> String {
    let start = startTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    let end = endTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    return "\(start)-\(end)"
}

private func generationMixTitle(for category: String) -> LocalizedStringKey {
    switch category {
    case "solar":
        return "Solar"
    case "wind":
        return "Wind"
    case "hydro":
        return "Hydro"
    case "biomass":
        return "Biomass"
    case "fossil":
        return "Fossil"
    case "nuclear":
        return "Nuclear"
    default:
        return "Other"
    }
}

private func shortGenerationMixTitle(for category: String) -> LocalizedStringKey {
    switch category {
    case "solar":
        return "Solar"
    case "wind":
        return "Wind"
    case "hydro":
        return "Hydro"
    case "biomass":
        return "Bio"
    case "fossil":
        return "Fossil"
    case "nuclear":
        return "Nuclear"
    default:
        return "Other"
    }
}

private func generationMixLocalizedTitle(for category: String) -> String {
    switch category {
    case "solar":
        return NSLocalizedString("Solar", comment: "Generation mix category")
    case "wind":
        return NSLocalizedString("Wind", comment: "Generation mix category")
    case "hydro":
        return NSLocalizedString("Hydro", comment: "Generation mix category")
    case "biomass":
        return NSLocalizedString("Biomass", comment: "Generation mix category")
    case "fossil":
        return NSLocalizedString("Fossil", comment: "Generation mix category")
    case "nuclear":
        return NSLocalizedString("Nuclear", comment: "Generation mix category")
    default:
        return NSLocalizedString("Other", comment: "Generation mix category")
    }
}

private func generationMixColor(for category: String) -> Color {
    switch category {
    case "solar":
        return Color(red: 0.95, green: 0.67, blue: 0.18)
    case "wind":
        return Color(red: 0.28, green: 0.60, blue: 0.86)
    case "hydro":
        return Color(red: 0.12, green: 0.48, blue: 0.78)
    case "biomass":
        return Color(red: 0.30, green: 0.62, blue: 0.28)
    case "fossil":
        return Color(red: 0.50, green: 0.44, blue: 0.39)
    case "nuclear":
        return Color(red: 0.58, green: 0.44, blue: 0.78)
    default:
        return Color.secondary
    }
}
