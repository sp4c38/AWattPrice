import SwiftUI
import WidgetKit

enum WidgetRoute {
    static let prices = URL(string: "awattprice://prices")
    static let insights = URL(string: "awattprice://insights")
    static let cheapestTime = URL(string: "awattprice://cheapest-time")
    static let pro = URL(string: "awattprice://pro")
}

enum WidgetStyle {
    static let accent = Color.orange
    static let low  = Color(red: 0.20, green: 0.70, blue: 0.38)
    static let high = Color(red: 0.86, green: 0.20, blue: 0.16)
    static let neutral = Color.secondary
    static let smallPadding: CGFloat = 15
    static let chartPadding: CGFloat = 14
    static let regularPadding: CGFloat = 18

    static func color(for price: Double, average: Double?) -> Color {
        if price < 0 {
            return low
        }

        guard let average else {
            return accent
        }

        if price <= average * 0.85 {
            return low
        }

        if price >= average * 1.20 {
            return high
        }

        return accent
    }

    /// Returns a fill style for a chart bar. Negative/zero prices use solid green.
    /// Positive prices use a vertical gradient (yellow at the baseline → the bar's
    /// own price color at its top), so every bar shows the same color at the same y-level —
    /// matching how the app's horizontal price graph samples a fixed gradient per bar.
    static func chartBarFill(for price: Double, lowerBound: Double, upperBound: Double) -> AnyShapeStyle {
        if price <= 0 { return AnyShapeStyle(low) }

        let floor = max(lowerBound, 0)
        let range = max(upperBound - floor, 1)
        let t = min(max((price - floor) / range, 0), 1)

        let oy: (Double, Double, Double) = (1.00, 0.74, 0.12)   // yellow (baseline)
        let dr: (Double, Double, Double) = (0.92, 0.14, 0.11)   // dark red (max)

        let bottomColor = Color(red: oy.0, green: oy.1, blue: oy.2)
        let topColor    = lerp(from: oy, to: dr, t: t)

        return AnyShapeStyle(LinearGradient(
            colors: [bottomColor, topColor],
            startPoint: .bottom,
            endPoint: .top
        ))
    }

    private static func lerp(
        from c1: (Double, Double, Double),
        to   c2: (Double, Double, Double),
        t: Double
    ) -> Color {
        Color(
            red:   c1.0 + (c2.0 - c1.0) * t,
            green: c1.1 + (c2.1 - c1.1) * t,
            blue:  c1.2 + (c2.2 - c1.2) * t
        )
    }
}

enum WidgetText {
    static func priceValue(_ price: Double?) -> String {
        guard let price else { return "-" }
        return price.priceString.flatMap { $0.isEmpty ? "0.00" : $0 } ?? "0.00"
    }

    static func price(_ price: Double?) -> String {
        "\(priceValue(price)) ct"
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func hourLabel(_ date: Date) -> String {
        String(format: "%02d", Calendar.current.component(.hour, from: date))
    }

    static func timeRange(from startTime: Date, to endTime: Date) -> String {
        "\(time(startTime))-\(time(endTime))"
    }

    static func duration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        return String(format: NSLocalizedString("%@h", comment: ""), String(hours))
    }

    static func usageDuration(_ timeInterval: TimeInterval) -> String {
        String(format: NSLocalizedString("%@ usage", comment: ""), duration(timeInterval))
    }

    static func updated(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func percent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(0)))
    }

    static func megawatt(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) MW"
    }
}

struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.containerBackground(.fill.tertiary, for: .widget)
    }
}

extension View {
    func awattWidgetBackground() -> some View {
        modifier(WidgetBackgroundModifier())
    }
}

struct WidgetUnavailableView: View {
    let snapshot: WidgetPriceSnapshot
    let route: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "bolt.slash.fill")
                .font(.title3)
                .foregroundStyle(WidgetStyle.accent)

            Text("Prices unavailable")
                .font(.headline)
                .lineLimit(2)

            Text(snapshot.marketAreaName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetStyle.smallPadding)
        .awattWidgetBackground()
        .widgetURL(route)
    }
}

struct WidgetProLockedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(WidgetStyle.accent)

            Text("Widgets are Pro")
                .font(.headline)
                .lineLimit(2)

            Text("Open AWattPrice to unlock widgets.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetStyle.smallPadding)
        .awattWidgetBackground()
        .widgetURL(WidgetRoute.pro)
    }
}

struct WidgetStatusBadge: View {
    let entry: WidgetPriceEntry

    var body: some View {
        switch entry.state {
        case .fresh:
            EmptyView()
        case .cached:
            Text("Cached")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        case .unavailable:
            Text("Unavailable")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        case .lockedPro:
            Text("Pro")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct WidgetGenerationMixStatusBadge: View {
    let entry: WidgetGenerationMixEntry

    var body: some View {
        switch entry.state {
        case .fresh:
            EmptyView()
        case .cached:
            Text("Cached")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        case .unavailable:
            Text("Unavailable")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        case .lockedPro:
            Text("Pro")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct WidgetGenerationMixUnavailableView: View {
    let snapshot: WidgetGenerationMixSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "leaf.slash.fill")
                .font(.title3)
                .foregroundStyle(WidgetStyle.low)

            Text("Renewable mix unavailable")
                .font(.headline)
                .lineLimit(2)

            Text(snapshot.marketAreaName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetStyle.smallPadding)
        .awattWidgetBackground()
        .widgetURL(WidgetRoute.insights)
    }
}

struct RenewableMixWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetGenerationMixEntry

    private var snapshot: WidgetGenerationMixSnapshot {
        entry.snapshot
    }

    private var renewableColor: Color {
        if snapshot.renewableShare >= 70 {
            return WidgetStyle.low
        }

        if snapshot.renewableShare >= 45 {
            return WidgetStyle.accent
        }

        return WidgetStyle.high
    }

    private var isOutdated: Bool {
        snapshot.endTime < Date().addingTimeInterval(-4 * 3600)
    }

    private var isSlightlyStale: Bool {
        let age = -snapshot.endTime.timeIntervalSinceNow
        return age > 120 * 60 && age <= 4 * 3600
    }

    private var dataAgeText: String {
        let hours = max(1, Int((-snapshot.endTime.timeIntervalSinceNow) / 3600))
        return String(format: NSLocalizedString("%dh ago", comment: "Compact data age label for widget"), hours)
    }

    var body: some View {
        if entry.state == .lockedPro {
            WidgetProLockedView()
        } else if snapshot.hasMix == false {
            WidgetGenerationMixUnavailableView(snapshot: snapshot)
        } else {
            switch family {
            case .accessoryRectangular:
                accessoryRectangularBody
            default:
                systemSmallBody
            }
        }
    }

    private var systemSmallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Label("Renewable", systemImage: "leaf.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetStyle.low)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: (isOutdated || isSlightlyStale) ? 2 : 0) {
                Text(WidgetText.percent(snapshot.renewableShare))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(renewableColor)
                    .lineLimit(1)

                if isOutdated {
                    Text("Data may be outdated")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                } else if isSlightlyStale {
                    Text(dataAgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Top sources")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                RenewableMixLeadingSources(categories: Array(snapshot.visibleCategories.prefix(2)))
            }
        }
        .padding(WidgetStyle.smallPadding)
        .awattWidgetBackground()
        .widgetURL(WidgetRoute.insights)
    }

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Renewable", systemImage: "leaf.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(WidgetText.percent(snapshot.renewableShare))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .widgetAccentable()

            Text(accessoryContextText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill, for: .widget)
        .widgetURL(WidgetRoute.insights)
    }

    private var accessoryContextText: String {
        if isOutdated {
            return String(localized: "Data may be outdated")
        }

        if isSlightlyStale {
            return dataAgeText
        }

        let topCategories = Array(snapshot.visibleCategories.prefix(2))
        guard topCategories.isEmpty == false else {
            return snapshot.marketAreaName
        }

        return topCategories
            .map { "\(widgetGenerationMixLocalizedTitle(for: $0.category)) \(WidgetText.percent($0.share))" }
            .joined(separator: ", ")
    }
}

private struct RenewableMixLeadingSources: View {
    let categories: [WidgetGenerationMixCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(categories) { category in
                HStack(spacing: 6) {
                    Circle()
                        .fill(widgetGenerationMixColor(for: category.category))
                        .frame(width: 7, height: 7)

                    Text(widgetGenerationMixTitle(for: category.category))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(WidgetText.percent(category.share))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func widgetGenerationMixTitle(for category: String) -> LocalizedStringKey {
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

func widgetGenerationMixLocalizedTitle(for category: String) -> String {
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

func widgetGenerationMixColor(for category: String) -> Color {
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

struct CurrentPriceWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetPriceEntry

    private var point: WidgetPricePoint? {
        entry.snapshot.currentPrice
    }

    private var priceColor: Color {
        WidgetStyle.color(for: point?.marketprice ?? 0, average: entry.snapshot.averagePrice)
    }

    private var contextText: LocalizedStringKey {
        guard let currentPrice = point?.marketprice else {
            return "Unavailable"
        }

        if currentPrice < 0 {
            return "Price is sub-zero"
        }

        guard let average = entry.snapshot.averagePrice else {
            return "Current electricity price"
        }

        if currentPrice <= average * 0.85 {
            return "Good time to use energy!"
        }

        if currentPrice >= average * 1.20 {
            return "Pricier right now"
        }

        return "Around average"
    }

    private var trend: WidgetPriceTrend? {
        entry.snapshot.nextThreeHourTrend
    }

    private var gaugeRange: ClosedRange<Double> {
        let currentPrice = point?.marketprice ?? 0
        let lowerBound = min(entry.snapshot.minPrice?.marketprice ?? currentPrice, currentPrice)
        let upperBound = max(entry.snapshot.maxPrice?.marketprice ?? currentPrice, currentPrice)

        guard lowerBound < upperBound else {
            let padding = max(abs(currentPrice) * 0.1, 1)
            return (currentPrice - padding)...(currentPrice + padding)
        }

        return lowerBound...upperBound
    }

    var body: some View {
        if family == .accessoryCircular {
            accessoryCircularBody
        } else if entry.state == .lockedPro {
            WidgetProLockedView()
        } else if entry.snapshot.hasPrices == false {
            WidgetUnavailableView(snapshot: entry.snapshot, route: WidgetRoute.prices)
        } else {
            switch family {
            case .accessoryRectangular:
                accessoryRectangularBody
            default:
                systemSmallBody
            }
        }
    }

    @ViewBuilder
    private var accessoryCircularBody: some View {
        Group {
            switch entry.state {
            case .lockedPro:
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .widgetAccentable()

            case .unavailable:
                Image(systemName: "bolt.slash.fill")
                    .font(.title2)
                    .widgetAccentable()

            case .fresh, .cached:
                if let point {
                    Gauge(value: point.marketprice, in: gaugeRange) {
                        Text("Current Price")
                    } currentValueLabel: {
                        VStack(spacing: -2) {
                            Text(WidgetText.priceValue(point.marketprice))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.55)
                                .lineLimit(1)

                            Text(verbatim: "ct")
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                        }
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(priceColor)
                    .widgetAccentable()
                    .accessibilityValue(WidgetText.price(point.marketprice))
                } else {
                    Image(systemName: "bolt.slash.fill")
                        .font(.title2)
                        .widgetAccentable()
                }
            }
        }
        .containerBackground(.fill, for: .widget)
        .widgetURL(entry.state == .lockedPro ? WidgetRoute.pro : WidgetRoute.prices)
    }

    private var systemSmallBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Label("Now", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(priceColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)
                WidgetStatusBadge(entry: entry)
            }

            Spacer(minLength: 0)

            if let point {
                Text(WidgetText.timeRange(from: point.startTime, to: point.endTime))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            
            Text(WidgetText.price(point?.marketprice))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .foregroundStyle(priceColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 3) {
                if let trend {
                    WidgetPriceTrendLabel(trend: trend)
                } else {
                    Text(contextText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
            }
        }
        .padding(WidgetStyle.smallPadding)
        .awattWidgetBackground()
        .widgetURL(WidgetRoute.prices)
    }

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Now", systemImage: "bolt.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(WidgetText.price(point?.marketprice))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .widgetAccentable()

            if let trend {
                WidgetPriceTrendLabel(trend: trend)
            } else {
                Text(contextText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill, for: .widget)
        .widgetURL(WidgetRoute.prices)
    }
}

private struct WidgetPriceTrendLabel: View {
    let trend: WidgetPriceTrend

    private var title: LocalizedStringKey {
        switch trend {
        case .rising:
            return "Next 3h rising"
        case .falling:
            return "Next 3h falling"
        case .stable:
            return "Next 3h stable"
        }
    }

    private var systemImage: String {
        switch trend {
        case .rising:
            return "arrow.up.right"
        case .falling:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        }
    }

    private var color: Color {
        switch trend {
        case .rising:
            return WidgetStyle.high
        case .falling:
            return WidgetStyle.low
        case .stable:
            return .secondary
        }
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}

struct ForecastWidgetView: View {
    let entry: WidgetPriceEntry

    private var currentPriceColor: Color {
        WidgetStyle.color(
            for: entry.snapshot.currentPrice?.marketprice ?? 0,
            average: entry.snapshot.upcomingForecastAveragePrice
        )
    }

    var body: some View {
        if entry.state == .lockedPro {
            WidgetProLockedView()
        } else if entry.snapshot.hasPrices == false {
            WidgetUnavailableView(snapshot: entry.snapshot, route: WidgetRoute.prices)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top) {
                    Label("Upcoming", systemImage: "bolt.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(currentPriceColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(WidgetText.price(entry.snapshot.currentPrice?.marketprice))
                            .font(.callout.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(currentPriceColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text("now")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(currentPriceColor)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        WidgetStatusBadge(entry: entry)
                    }
                }

                PriceForecastChart(
                    points: entry.snapshot.upcomingForecastPoints
                )
            }
            .padding(WidgetStyle.chartPadding)
            .awattWidgetBackground()
            .widgetURL(WidgetRoute.prices)
        }
    }
}


struct PriceForecastChart: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let points: [WidgetPricePoint]

    private var chartPoints: [WidgetPricePoint] {
        movingAveragePoints(points)
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let metrics = WidgetChartMetrics(points: chartPoints, size: geometry.size, topInset: 18, bottomInset: 8)

                ZStack(alignment: .topLeading) {
                    let maxIdx = chartPoints.indices.max(by: { chartPoints[$0].marketprice < chartPoints[$1].marketprice })
                    let minIdx = chartPoints.indices.min(by: { chartPoints[$0].marketprice < chartPoints[$1].marketprice })
                    let callouts = extremaCallouts(maxIdx: maxIdx, minIdx: minIdx, metrics: metrics)

                    if metrics.crossesZero {
                        Rectangle()
                            .fill(.secondary.opacity(0.18))
                            .frame(height: 1)
                            .position(x: geometry.size.width / 2, y: metrics.yPosition(for: 0))
                    }

                    smoothedLinePath(metrics: metrics)
                    .stroke(
                        LinearGradient(
                            colors: [
                                WidgetStyle.low,
                                WidgetStyle.accent,
                                WidgetStyle.high
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
                    )

                    ForEach(Array(chartPoints.enumerated()), id: \.element.startTime) { index, point in
                        let isExtreme = (maxIdx.map { $0 == index } ?? false) || (minIdx.map { $0 == index } ?? false)
                        let pointColor = (maxIdx.map { $0 == index } ?? false)
                            ? WidgetStyle.high
                            : (point.marketprice < 0 ? WidgetStyle.low : WidgetStyle.accent)

                        ZStack {
                            Circle()
                                .fill(renderingMode == .fullColor ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color.clear))
                                .frame(width: 9, height: 9)

                            Circle()
                                .fill(pointColor)
                                .frame(width: 6, height: 6)
                        }
                        .position(metrics.pointPosition(for: index))
                        .opacity(isExtreme ? 1 : 0)
                    }

                    ForEach(callouts) { callout in
                        Path { path in
                            path.move(to: callout.connectorStart)
                            path.addLine(to: callout.connectorEnd)
                        }
                        .stroke(callout.color.opacity(0.45), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    }

                    ForEach(callouts) { callout in
                        PriceForecastExtremaLabel(
                            systemImage: callout.systemImage,
                            price: callout.price,
                            color: callout.color
                        )
                        .position(callout.labelPosition)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)

            ForecastHourAxis(points: points)
        }
    }

    private func axisLabel(_ price: Double) -> String {
        "\(Int(price.rounded())) ct"
    }

    private func extremaCallouts(maxIdx: Int?, minIdx: Int?, metrics: WidgetChartMetrics) -> [ForecastExtremaCallout] {
        var specs: [(index: Int, isHigh: Bool)] = []

        if let maxIdx {
            specs.append((index: maxIdx, isHigh: true))
        }

        if let minIdx, maxIdx.map({ $0 != minIdx }) ?? true {
            specs.append((index: minIdx, isHigh: false))
        }

        guard specs.count == 2 else {
            return specs.map { spec in
                let candidate = calloutCandidates(for: spec.index, metrics: metrics).first
                return callout(index: spec.index, isHigh: spec.isHigh, labelPosition: candidate?.position, metrics: metrics)
            }
        }

        let firstSpec = specs[0]
        let secondSpec = specs[1]
        let firstCandidates = calloutCandidates(for: firstSpec.index, metrics: metrics)
        let secondCandidates = calloutCandidates(for: secondSpec.index, metrics: metrics)
        var bestPair: (first: ForecastCalloutCandidate, second: ForecastCalloutCandidate, score: CGFloat)?

        for first in firstCandidates {
            for second in secondCandidates {
                let overlapPenalty: CGFloat = first.rect.intersects(second.rect) ? 6_000 : 0
                let score = first.score + second.score + overlapPenalty

                if bestPair == nil || score < bestPair!.score {
                    bestPair = (first: first, second: second, score: score)
                }
            }
        }

        return [
            callout(index: firstSpec.index, isHigh: firstSpec.isHigh, labelPosition: bestPair?.first.position, metrics: metrics),
            callout(index: secondSpec.index, isHigh: secondSpec.isHigh, labelPosition: bestPair?.second.position, metrics: metrics),
        ]
    }

    private func callout(index: Int, isHigh: Bool, labelPosition: CGPoint?, metrics: WidgetChartMetrics) -> ForecastExtremaCallout {
        let point = metrics.pointPosition(for: index)
        let price = chartPoints[index].marketprice
        let color = isHigh ? WidgetStyle.high : (price < 0 ? WidgetStyle.low : WidgetStyle.accent)

        return ForecastExtremaCallout(
            kind: isHigh ? .high : .low,
            labelPosition: labelPosition ?? metrics.clampedLabelPosition(x: point.x, y: point.y),
            pointPosition: point,
            systemImage: isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
            price: axisLabel(price),
            color: color
        )
    }

    private func preferredHorizontalSide(for index: Int, metrics: WidgetChartMetrics) -> CGFloat {
        guard chartPoints.count > 1 else { return 1 }

        let point = metrics.pointPosition(for: index)

        if point.x < metrics.size.width * 0.32 {
            return 1
        }

        if point.x > metrics.size.width * 0.68 {
            return -1
        }

        let previous = metrics.pointPosition(for: max(index - 1, 0))
        let next = metrics.pointPosition(for: min(index + 1, chartPoints.count - 1))
        let localDirection = next.x == previous.x ? 0 : (next.y - previous.y) / (next.x - previous.x)

        return localDirection >= 0 ? -1 : 1
    }

    private func calloutCandidates(for index: Int, metrics: WidgetChartMetrics) -> [ForecastCalloutCandidate] {
        let point = metrics.pointPosition(for: index)
        let linePositions = chartPoints.indices.map { metrics.pointPosition(for: $0) }
        let primaryDirection: CGFloat = -1
        let secondaryDirection = -primaryDirection
        let preferredSide = preferredHorizontalSide(for: index, metrics: metrics)
        let secondarySide = -preferredSide
        let verticalOffsets: [CGFloat] = [24, 32, 40]
        let diagonalOffset: CGFloat = 54
        var rawPositions: [CGPoint] = []

        for offset in verticalOffsets {
            rawPositions.append(CGPoint(x: point.x, y: point.y + primaryDirection * offset))
        }

        for offset in verticalOffsets.prefix(2) {
            rawPositions.append(CGPoint(x: point.x + preferredSide * diagonalOffset, y: point.y + primaryDirection * offset))
            rawPositions.append(CGPoint(x: point.x + secondarySide * diagonalOffset, y: point.y + primaryDirection * offset))
        }

        for offset in verticalOffsets.prefix(2) {
            rawPositions.append(CGPoint(x: point.x, y: point.y + secondaryDirection * offset))
            rawPositions.append(CGPoint(x: point.x + preferredSide * diagonalOffset, y: point.y + secondaryDirection * offset))
            rawPositions.append(CGPoint(x: point.x + secondarySide * diagonalOffset, y: point.y + secondaryDirection * offset))
        }

        var seenPositions: [CGPoint] = []

        return rawPositions.enumerated().compactMap { order, rawPosition in
            let position = metrics.clampedLabelPosition(x: rawPosition.x, y: rawPosition.y)

            guard seenPositions.contains(where: { hypot($0.x - position.x, $0.y - position.y) < 1 }) == false else {
                return nil
            }

            seenPositions.append(position)
            return calloutCandidate(position: position, point: point, linePositions: linePositions, order: order)
        }
        .sorted { $0.score < $1.score }
    }

    private func calloutCandidate(position: CGPoint, point: CGPoint, linePositions: [CGPoint], order: Int) -> ForecastCalloutCandidate {
        let labelRect = calloutLabelRect(centeredAt: position)
        let dangerRect = labelRect.insetBy(dx: -6, dy: -6)
        let linePenalty = lineIntersections(with: dangerRect, positions: linePositions) * 18
        let pointPenalty: CGFloat = labelRect.contains(point) ? 2_000 : 0
        let lowerThanPointPenalty: CGFloat = position.y > point.y ? 700 : 0
        let distance = hypot(position.x - point.x, position.y - point.y)
        let horizontalOffsetPenalty = abs(position.x - point.x) * 7
        let orderPenalty = CGFloat(order) * 4
        let score = CGFloat(linePenalty) + pointPenalty + lowerThanPointPenalty + distance + horizontalOffsetPenalty + orderPenalty

        return ForecastCalloutCandidate(position: position, rect: labelRect, score: score)
    }

    private func calloutLabelRect(centeredAt position: CGPoint) -> CGRect {
        let labelSize = CGSize(width: 68, height: 20)
        return CGRect(
            x: position.x - labelSize.width / 2,
            y: position.y - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        ).insetBy(dx: -3, dy: -3)
    }

    private func lineIntersections(with rect: CGRect, positions: [CGPoint]) -> Int {
        guard positions.count > 1 else { return 0 }

        var intersections = 0

        for index in 0..<(positions.count - 1) {
            if rect.intersectsLineSegment(from: positions[index], to: positions[index + 1]) {
                intersections += 1
            }
        }

        return intersections
    }

    private func smoothedLinePath(metrics: WidgetChartMetrics) -> Path {
        let positions = chartPoints.indices.map { metrics.pointPosition(for: $0) }

        return Path { path in
            guard let first = positions.first else { return }
            path.move(to: first)

            guard positions.count > 2 else {
                for point in positions.dropFirst() {
                    path.addLine(to: point)
                }
                return
            }

            for index in 0..<(positions.count - 1) {
                let previous = positions[max(index - 1, 0)]
                let current = positions[index]
                let next = positions[index + 1]
                let following = positions[min(index + 2, positions.count - 1)]
                let smoothness: CGFloat = 4.2

                let control1 = CGPoint(
                    x: current.x + (next.x - previous.x) / smoothness,
                    y: current.y + (next.y - previous.y) / smoothness
                )
                let control2 = CGPoint(
                    x: next.x - (following.x - current.x) / smoothness,
                    y: next.y - (following.y - current.y) / smoothness
                )

                path.addCurve(to: next, control1: control1, control2: control2)
            }
        }
    }

    private func movingAveragePoints(_ sourcePoints: [WidgetPricePoint]) -> [WidgetPricePoint] {
        let weights: [(offset: Int, weight: Double)] = [
            (-2, 0.10),
            (-1, 0.20),
            (0, 0.40),
            (1, 0.20),
            (2, 0.10),
        ]

        return sourcePoints.indices.map { index in
            var weightedSum = 0.0
            var totalWeight = 0.0

            for item in weights {
                let sourceIndex = index + item.offset

                guard sourcePoints.indices.contains(sourceIndex) else {
                    continue
                }

                weightedSum += sourcePoints[sourceIndex].marketprice * item.weight
                totalWeight += item.weight
            }

            let smoothedPrice = totalWeight > 0 ? weightedSum / totalWeight : sourcePoints[index].marketprice

            return WidgetPricePoint(
                startTime: sourcePoints[index].startTime,
                endTime: sourcePoints[index].endTime,
                marketprice: smoothedPrice
            )
        }
    }
}

private struct ForecastExtremaCallout: Identifiable {
    enum Kind: String {
        case high
        case low
    }

    let kind: Kind
    let labelPosition: CGPoint
    let pointPosition: CGPoint
    let systemImage: String
    let price: String
    let color: Color

    var id: String { kind.rawValue }

    var connectorStart: CGPoint {
        let dx = labelPosition.x - pointPosition.x
        let dy = labelPosition.y - pointPosition.y
        let distance = max((dx * dx + dy * dy).squareRoot(), 1)
        let pointGap: CGFloat = 5

        return CGPoint(
            x: pointPosition.x + dx / distance * pointGap,
            y: pointPosition.y + dy / distance * pointGap
        )
    }

    var connectorEnd: CGPoint {
        let dx = pointPosition.x - labelPosition.x
        let dy = pointPosition.y - labelPosition.y
        let distance = max((dx * dx + dy * dy).squareRoot(), 1)
        let labelGap: CGFloat = 12

        return CGPoint(
            x: labelPosition.x + dx / distance * labelGap,
            y: labelPosition.y + dy / distance * labelGap
        )
    }

}

private struct ForecastCalloutCandidate {
    let position: CGPoint
    let rect: CGRect
    let score: CGFloat
}

private extension CGRect {
    func intersectsLineSegment(from start: CGPoint, to end: CGPoint) -> Bool {
        if contains(start) || contains(end) {
            return true
        }

        let topLeft = CGPoint(x: minX, y: minY)
        let topRight = CGPoint(x: maxX, y: minY)
        let bottomLeft = CGPoint(x: minX, y: maxY)
        let bottomRight = CGPoint(x: maxX, y: maxY)

        return lineSegmentsIntersect(start, end, topLeft, topRight) ||
            lineSegmentsIntersect(start, end, topRight, bottomRight) ||
            lineSegmentsIntersect(start, end, bottomRight, bottomLeft) ||
            lineSegmentsIntersect(start, end, bottomLeft, topLeft)
    }

    private func lineSegmentsIntersect(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        let direction1 = direction(from: c, to: d, point: a)
        let direction2 = direction(from: c, to: d, point: b)
        let direction3 = direction(from: a, to: b, point: c)
        let direction4 = direction(from: a, to: b, point: d)

        return ((direction1 > 0 && direction2 < 0) || (direction1 < 0 && direction2 > 0)) &&
            ((direction3 > 0 && direction4 < 0) || (direction3 < 0 && direction4 > 0))
    }

    private func direction(from start: CGPoint, to end: CGPoint, point: CGPoint) -> CGFloat {
        (point.x - start.x) * (end.y - start.y) - (end.x - start.x) * (point.y - start.y)
    }
}

private struct PriceForecastExtremaLabel: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let systemImage: String
    let price: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))

            Text(price)
                .font(.caption2.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .fixedSize()
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background {
            if renderingMode == .fullColor {
                Capsule()
                    .fill(.regularMaterial)
            } else {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(color, lineWidth: 1.2)
                    )
            }
        }
    }
}

struct ForecastHourAxis: View {
    let points: [WidgetPricePoint]

    private var labelIndexes: [Int] {
        guard points.count > 1 else { return points.isEmpty ? [] : [0] }

        let calendar = Calendar.autoupdatingCurrent
        let stride = axisHourStride()
        let firstHour = calendar.startOfHour(for: points[0].startTime)
        let firstTick = firstHour < points[0].startTime
            ? firstHour.addingTimeInterval(60 * 60)
            : firstHour
        let firstTickHour = calendar.component(.hour, from: firstTick)
        let hourOffset = (stride - (firstTickHour % stride)) % stride
        var tickDate = firstTick.addingTimeInterval(TimeInterval(hourOffset * 60 * 60))
        var indexes: [Int] = []

        while tickDate <= points[points.count - 1].startTime {
            if let index = points.firstIndex(where: { calendar.startOfHour(for: $0.startTime) == tickDate }) {
                indexes.append(index)
            }

            tickDate = tickDate.addingTimeInterval(TimeInterval(stride * 60 * 60))
        }

        if indexes.isEmpty {
            return [0]
        }

        return indexes
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(labelIndexes, id: \.self) { index in
                    if points.indices.contains(index) {
                        Text(WidgetText.hourLabel(points[index].startTime))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                            .position(
                                x: xPosition(for: index, width: geometry.size.width),
                                y: 7
                            )
                    }
                }
            }
        }
        .frame(height: 14)
    }

    private func xPosition(for index: Int, width: CGFloat) -> CGFloat {
        guard points.count > 1 else { return width / 2 }

        let fraction = CGFloat(index) / CGFloat(points.count - 1)
        let inset: CGFloat = 16
        return min(max(width * fraction, inset), max(width - inset, inset))
    }

    private func axisHourStride() -> Int {
        guard let first = points.first?.startTime, let last = points.last?.startTime else {
            return 1
        }

        let spanHours = max(last.timeIntervalSince(first) / (60 * 60), 1)

        if spanHours > 30 { return 4 }
        if spanHours > 16 { return 3 }
        if spanHours > 6 { return 2 }
        return 1
    }
}

struct WidgetChartMetrics {
    let points: [WidgetPricePoint]
    let size: CGSize
    let lowerBound: Double
    let upperBound: Double
    let topInset: CGFloat
    let bottomInset: CGFloat
    let horizontalInset: CGFloat = 16

    init(points: [WidgetPricePoint], size: CGSize, topInset: CGFloat = 0, bottomInset: CGFloat = 2) {
        self.points = points
        self.size = size
        self.topInset = topInset
        self.bottomInset = bottomInset

        let prices = points.map(\.marketprice)
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 1

        if minPrice == maxPrice {
            lowerBound = minPrice - 1
            upperBound = maxPrice + 1
        } else {
            let padding = max((maxPrice - minPrice) * 0.24, 1)
            lowerBound = minPrice >= 0 ? max(0, minPrice - padding) : minPrice - padding
            upperBound = maxPrice + padding
        }
    }

    var crossesZero: Bool {
        lowerBound < 0 && upperBound > 0
    }

    func yPosition(for price: Double) -> CGFloat {
        guard upperBound > lowerBound else { return size.height }

        let normalized = (price - lowerBound) / (upperBound - lowerBound)
        let drawableHeight = max(size.height - topInset - bottomInset, 1)
        return size.height - bottomInset - CGFloat(normalized) * drawableHeight
    }

    func xPosition(for index: Int) -> CGFloat {
        guard points.count > 1 else { return size.width / 2 }

        let drawableWidth = max(size.width - horizontalInset * 2, 1)
        let fraction = CGFloat(index) / CGFloat(points.count - 1)
        return horizontalInset + drawableWidth * fraction
    }

    func pointPosition(for index: Int) -> CGPoint {
        let price = points.indices.contains(index) ? points[index].marketprice : 0
        return CGPoint(x: xPosition(for: index), y: yPosition(for: price))
    }

    func clampedLabelPosition(x: CGFloat, y: CGFloat) -> CGPoint {
        let labelHalfWidth: CGFloat = 37
        let labelHalfHeight: CGFloat = 9
        let clampedX = min(max(x, labelHalfWidth), max(size.width - labelHalfWidth, labelHalfWidth))
        let clampedY = min(max(y, labelHalfHeight), max(size.height - labelHalfHeight, labelHalfHeight))

        return CGPoint(x: clampedX, y: clampedY)
    }

}

struct CheapestTimesWidgetView: View {
    let entry: WidgetPriceEntry

    var body: some View {
        if entry.state == .lockedPro {
            WidgetProLockedView()
        } else if entry.snapshot.hasPrices == false {
            WidgetUnavailableView(snapshot: entry.snapshot, route: WidgetRoute.cheapestTime)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Label("Cheapest", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetStyle.low)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 4)
                    WidgetStatusBadge(entry: entry)
                }

                cheapestWindowsList
            }
            .padding(WidgetStyle.smallPadding)
            .awattWidgetBackground()
            .widgetURL(WidgetRoute.cheapestTime)
        }
    }

    private var cheapestWindowsList: some View {
        VStack(spacing: 2) {
            if entry.snapshot.cheapestWindows.isEmpty {
                Text("No full time window available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                let windows = Array(entry.snapshot.cheapestWindows.prefix(3))

                ForEach(Array(windows.enumerated()), id: \.offset) { index, window in
                    if index > 0 { CheapestWindowDivider() }
                    CheapestWindowCompactRow(window: window)
                }
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct CheapestWindowDivider: View {
    var body: some View {
        Rectangle()
            .fill(.secondary.opacity(0.24))
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CheapestWindowCompactRow: View {
    let window: WidgetPriceWindow

    var body: some View {
        HStack(spacing: 5) {
            VStack(alignment: .leading, spacing: 0) {
                Text(WidgetText.duration(window.duration))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)

                Text(WidgetText.timeRange(from: window.startTime, to: window.endTime))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(WidgetText.price(window.averagePrice))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WidgetStyle.low)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 36)
    }
}
