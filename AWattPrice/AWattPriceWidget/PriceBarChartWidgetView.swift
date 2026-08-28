import Charts
import SwiftUI
import WidgetKit

struct PriceBarChartWidgetView: View {
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
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top) {
                    Label("Next 24h", systemImage: "bolt.fill")
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
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        WidgetStatusBadge(entry: entry)
                    }
                }

                PriceBarChart(
                    points: entry.snapshot.hourlyForecastPoints,
                    lowerBound: entry.snapshot.hourlyForecastMinPrice?.marketprice ?? 0,
                    upperBound: entry.snapshot.hourlyForecastMaxPrice?.marketprice ?? 0
                )
            }
            .padding(WidgetStyle.chartPadding)
            .awattWidgetBackground()
            .widgetURL(WidgetRoute.prices)
        }
    }
}

private struct PriceBarChart: View {
    let points: [WidgetPricePoint]
    let lowerBound: Double
    let upperBound: Double

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Time", point.startTime ..< point.endTime),
                y: .value("Price", point.marketprice)
            )
            .foregroundStyle(WidgetStyle.chartBarFill(for: point.marketprice, lowerBound: lowerBound, upperBound: upperBound))
        }
        .chartXScale(range: .plotDimension(padding: 10))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisTick()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(WidgetText.hourLabel(date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                if let price = value.as(Double.self) {
                    AxisValueLabel {
                        Text(price, format: .number.precision(.fractionLength(0)))
                            .font(.caption2)
                    }
                }
            }
        }
    }
}
