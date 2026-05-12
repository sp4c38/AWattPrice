import SwiftUI
import WidgetKit

enum WidgetRoute {
    static let prices = URL(string: "awattprice://prices")
    static let insights = URL(string: "awattprice://insights")
    static let cheapestTime = URL(string: "awattprice://cheapest-time")
}

enum WidgetStyle {
    static let accent = Color.orange
    static let low = Color(red: 0.20, green: 0.62, blue: 0.25)
    static let high = Color.red
    static let neutral = Color.secondary
    static let smallPadding: CGFloat = 15
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

    static func timeRange(from startTime: Date, to endTime: Date) -> String {
        "\(time(startTime))-\(time(endTime))"
    }

    static func duration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        return "\(hours)h"
    }

    static func usageDuration(_ timeInterval: TimeInterval) -> String {
        String(format: NSLocalizedString("widget.cheapest.usageDuration", comment: ""), duration(timeInterval))
    }

    static func updated(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
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

            Text("widget.unavailable.title")
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

struct WidgetStatusBadge: View {
    let entry: WidgetPriceEntry

    var body: some View {
        switch entry.state {
        case .fresh:
            EmptyView()
        case .cached:
            Text("widget.cached")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        case .unavailable:
            Text("widget.unavailable.short")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct CurrentPriceWidgetView: View {
    let entry: WidgetPriceEntry

    private var point: WidgetPricePoint? {
        entry.snapshot.currentPrice
    }

    private var contextText: LocalizedStringKey {
        guard let currentPrice = point?.marketprice else {
            return "widget.unavailable.short"
        }

        if currentPrice < 0 {
            return "widget.current.negative"
        }

        guard let average = entry.snapshot.averagePrice else {
            return "widget.current.available"
        }

        return currentPrice <= average ? "widget.current.belowAverage" : "widget.current.aboveAverage"
    }

    var body: some View {
        if entry.snapshot.hasPrices == false {
            WidgetUnavailableView(snapshot: entry.snapshot, route: WidgetRoute.prices)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Label("widget.current.title", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetStyle.accent)
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
                    .foregroundStyle(WidgetStyle.color(for: point?.marketprice ?? 0, average: entry.snapshot.averagePrice))
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
    }
}

struct ForecastWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetPriceEntry

    var body: some View {
        if entry.snapshot.hasPrices == false {
            WidgetUnavailableView(snapshot: entry.snapshot, route: WidgetRoute.prices)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                PriceForecastChart(
                    points: entry.snapshot.hourlyForecastPoints,
                    averagePrice: entry.snapshot.hourlyForecastAveragePrice,
                    currentPrice: entry.snapshot.currentPrice
                )

                if family == .systemLarge {
                    largeSummary
                }
            }
            .padding(WidgetStyle.regularPadding)
            .awattWidgetBackground()
            .widgetURL(WidgetRoute.prices)
        }
    }

    private var largeSummary: some View {
        HStack(spacing: 10) {
            ForecastSummaryItem(title: "widget.forecast.lowest", point: entry.snapshot.hourlyForecastMinPrice, tint: WidgetStyle.low)
            ForecastSummaryItem(title: "widget.forecast.current", point: entry.snapshot.currentHourlyForecastPrice, tint: WidgetStyle.accent)
            ForecastSummaryItem(title: "widget.forecast.highest", point: entry.snapshot.hourlyForecastMaxPrice, tint: WidgetStyle.high)
        }
    }
}

struct ForecastSummaryItem: View {
    let title: LocalizedStringKey
    let value: Double?
    let subtitle: String?
    let tint: Color

    init(title: LocalizedStringKey, point: WidgetPricePoint?, tint: Color) {
        self.title = title
        self.value = point?.marketprice
        self.subtitle = point.map { WidgetText.timeRange(from: $0.startTime, to: $0.endTime) }
        self.tint = tint
    }

    init(title: LocalizedStringKey, value: Double?, tint: Color) {
        self.title = title
        self.value = value
        self.subtitle = nil
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(WidgetText.price(value))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PriceForecastChart: View {
    let points: [WidgetPricePoint]
    let averagePrice: Double?
    let currentPrice: WidgetPricePoint?

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let metrics = WidgetChartMetrics(points: points, size: geometry.size)

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.secondary.opacity(0.18))
                        .frame(height: 1)
                        .position(x: geometry.size.width / 2, y: metrics.yPosition(for: 0))

                    ForEach(Array(points.enumerated()), id: \.element.startTime) { index, point in
                        let frame = metrics.barFrame(for: point.marketprice, index: index)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(WidgetStyle.color(for: point.marketprice, average: averagePrice))
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                            .opacity(isCurrentHour(point) ? 1 : 0.72)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)

            ForecastHourAxis(points: points)
        }
    }

    private func isCurrentHour(_ point: WidgetPricePoint) -> Bool {
        guard let currentPrice else { return false }
        return point.startTime <= currentPrice.startTime && point.endTime > currentPrice.startTime
    }
}

struct ForecastHourAxis: View {
    let points: [WidgetPricePoint]

    private var labelIndexes: [Int] {
        guard points.isEmpty == false else { return [] }

        var indexes = Array(stride(from: 0, to: points.count, by: 6))
        let lastIndex = points.count - 1

        if indexes.contains(lastIndex) == false {
            indexes.append(lastIndex)
        }

        return indexes
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(labelIndexes, id: \.self) { index in
                    if points.indices.contains(index) {
                        Text(WidgetText.time(points[index].startTime))
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

    init(points: [WidgetPricePoint], size: CGSize) {
        self.points = points
        self.size = size

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
        return size.height - CGFloat(normalized) * size.height
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
        if entry.snapshot.hasPrices == false {
            WidgetUnavailableView(snapshot: entry.snapshot, route: WidgetRoute.cheapestTime)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                        Text("widget.cheapest.title")
                    }
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                    Spacer(minLength: 6)
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
                Text("widget.cheapest.noWindow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                let windows = Array(entry.snapshot.cheapestWindows.prefix(3))

                if windows.indices.contains(0) {
                    CheapestWindowCompactRow(window: windows[0])
                }

                if windows.indices.contains(1) {
                    CheapestWindowDivider()
                    CheapestWindowCompactRow(window: windows[1])
                }

                if windows.indices.contains(2) {
                    CheapestWindowDivider()
                    CheapestWindowCompactRow(window: windows[2])
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
