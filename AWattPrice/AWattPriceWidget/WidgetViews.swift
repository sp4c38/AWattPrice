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
    static func price(_ price: Double?) -> String {
        guard let price else { return "-" }
        let formatted = price.priceString.flatMap { $0.isEmpty ? "0.00" : $0 } ?? "0.00"
        return "\(formatted) ct"
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func hourLabel(_ date: Date) -> String {
        String(format: "%02dh", Calendar.current.component(.hour, from: date))
    }

    static func timeRange(from startTime: Date, to endTime: Date) -> String {
        "\(time(startTime))-\(time(endTime))"
    }

    static func duration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        return "\(hours)h"
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
        snapshot.endTime < Date().addingTimeInterval(-90 * 60)
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

            VStack(alignment: .leading, spacing: isOutdated ? 2 : 0) {
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

    var body: some View {
        if entry.state == .lockedPro {
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

    private var systemSmallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Text(WidgetText.price(point?.marketprice))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .foregroundStyle(priceColor)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 3) {
                if let point {
                    Text(WidgetText.timeRange(from: point.startTime, to: point.endTime))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }

                Text(contextText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
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

            Text(contextText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill, for: .widget)
        .widgetURL(WidgetRoute.prices)
    }
}

struct ForecastWidgetView: View {
    let entry: WidgetPriceEntry

    private var currentPriceColor: Color {
        WidgetStyle.color(
            for: entry.snapshot.currentPrice?.marketprice ?? 0,
            average: entry.snapshot.hourlyForecastAveragePrice
        )
    }

    var body: some View {
        if entry.state == .lockedPro {
            WidgetProLockedView()
        } else if entry.snapshot.hasPrices == false {
            WidgetUnavailableView(snapshot: entry.snapshot, route: WidgetRoute.prices)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Label("Next 24h", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(currentPriceColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        Text(WidgetText.price(entry.snapshot.currentPrice?.marketprice))
                            .font(.caption.weight(.bold))
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
                    points: entry.snapshot.hourlyForecastPoints
                )
            }
            .padding(WidgetStyle.chartPadding)
            .awattWidgetBackground()
            .widgetURL(WidgetRoute.prices)
        }
    }
}


struct PriceForecastChart: View {
    let points: [WidgetPricePoint]

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let metrics = WidgetChartMetrics(points: points, size: geometry.size, topInset: 20)

                ZStack(alignment: .topLeading) {
                    let maxIdx = points.indices.max(by: { points[$0].marketprice < points[$1].marketprice })
                    let minIdx = points.indices.min(by: { points[$0].marketprice < points[$1].marketprice })

                    // Zero baseline
                    Rectangle()
                        .fill(.secondary.opacity(0.18))
                        .frame(height: 1)
                        .position(x: geometry.size.width / 2, y: metrics.yPosition(for: 0))

                    // Price bars
                    ForEach(Array(points.enumerated()), id: \.element.startTime) { index, point in
                        let frame = metrics.barFrame(for: point.marketprice, index: index)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(WidgetStyle.chartBarFill(for: point.marketprice,
                                                          lowerBound: metrics.lowerBound,
                                                          upperBound: metrics.upperBound))
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                            .opacity(0.88)
                    }

                    // High/low labels above their respective bars
                    if let idx = maxIdx {
                        let frame = metrics.barFrame(for: points[idx].marketprice, index: idx)
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(WidgetStyle.high)
                            Text(axisLabel(points[idx].marketprice))
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(WidgetStyle.high)
                        }
                        .fixedSize()
                        .position(x: frame.midX, y: extremaLabelY(for: frame))
                    }

                    if let idx = minIdx, idx != maxIdx {
                        let frame = metrics.barFrame(for: points[idx].marketprice, index: idx)
                        let lowLabelColor = points[idx].marketprice < 0 ? WidgetStyle.low : WidgetStyle.accent
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(lowLabelColor)
                            Text(axisLabel(points[idx].marketprice))
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(lowLabelColor)
                        }
                        .fixedSize()
                        .position(x: frame.midX, y: extremaLabelY(for: frame))
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

    private func extremaLabelY(for barFrame: CGRect) -> CGFloat {
        max(barFrame.minY - 12, 7)
    }
}

struct ForecastHourAxis: View {
    let points: [WidgetPricePoint]

    private var labelIndexes: [Int] {
        guard points.count > 1 else { return points.isEmpty ? [] : [0] }

        let labelCount = 6
        return (0..<labelCount).map { i in
            Int(round(Double(i) * Double(points.count - 1) / Double(labelCount - 1)))
        }
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
}

struct WidgetChartMetrics {
    let points: [WidgetPricePoint]
    let size: CGSize
    let lowerBound: Double
    let upperBound: Double
    let topInset: CGFloat

    init(points: [WidgetPricePoint], size: CGSize, topInset: CGFloat = 0) {
        self.points = points
        self.size = size
        self.topInset = topInset

        let prices = points.map(\.marketprice)
        let minPrice = min(prices.min() ?? 0, 0)
        let maxPrice = max(prices.max() ?? 1, 0)

        if minPrice == maxPrice {
            lowerBound = minPrice
            upperBound = maxPrice + 1
        } else {
            lowerBound = minPrice
            upperBound = maxPrice
        }
    }

    func yPosition(for price: Double) -> CGFloat {
        guard upperBound > lowerBound else { return size.height }

        let normalized = (price - lowerBound) / (upperBound - lowerBound)
        let drawableHeight = size.height - topInset
        return size.height - CGFloat(normalized) * drawableHeight
    }

    func barFrame(for price: Double, index: Int) -> CGRect {
        let count = max(points.count, 1)
        let spacing: CGFloat = 2
        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
        let barWidth = max((size.width - totalSpacing) / CGFloat(count), 2)
        let x = CGFloat(index) * (barWidth + spacing)
        let baselineY = yPosition(for: 0)
        let valueY = yPosition(for: price)
        let minY = min(baselineY, valueY)
        let height = max(abs(valueY - baselineY), 2)

        return CGRect(x: x, y: minY, width: barWidth, height: height)
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
