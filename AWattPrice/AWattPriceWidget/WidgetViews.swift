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
    static let smallPadding: CGFloat = 12
    static let regularPadding: CGFloat = 14

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
                header

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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("widget.forecast.title")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 6) {
                    Text(entry.snapshot.marketAreaName)
                        .lineLimit(1)

                    Text("widget.forecast.next24h")
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(WidgetText.price(entry.snapshot.currentPrice?.marketprice))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)

                WidgetStatusBadge(entry: entry)
            }
        }
    }

    private var largeSummary: some View {
        HStack(spacing: 10) {
            ForecastSummaryItem(title: "widget.forecast.lowest", point: entry.snapshot.hourlyForecastMinPrice, tint: WidgetStyle.low)
            ForecastSummaryItem(title: "widget.forecast.average", value: entry.snapshot.hourlyForecastAveragePrice, tint: WidgetStyle.neutral)
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
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func isCurrentHour(_ point: WidgetPricePoint) -> Bool {
        guard let currentPrice else { return false }
        return point.startTime <= currentPrice.startTime && point.endTime > currentPrice.startTime
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
    @Environment(\.widgetFamily) private var family

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
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                    Spacer(minLength: 6)
                    WidgetStatusBadge(entry: entry)
                }

                if family == .systemSmall {
                    bestWindow
                } else {
                    windowsList
                }
            }
            .padding(WidgetStyle.smallPadding)
            .awattWidgetBackground()
            .widgetURL(WidgetRoute.cheapestTime)
        }
    }

    private var bestWindow: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let window = entry.snapshot.cheapestWindows.first {
                Text(WidgetText.duration(window.duration))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(WidgetText.timeRange(from: window.startTime, to: window.endTime))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(WidgetText.price(window.averagePrice))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetStyle.low)
            } else {
                Text("widget.cheapest.noWindow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var windowsList: some View {
        VStack(spacing: 8) {
            ForEach(entry.snapshot.cheapestWindows) { window in
                HStack(spacing: 8) {
                    Text(WidgetText.duration(window.duration))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WidgetStyle.low)
                        .frame(width: 28, alignment: .leading)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(WidgetText.timeRange(from: window.startTime, to: window.endTime))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)

                        Text(WidgetText.price(window.averagePrice))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}
