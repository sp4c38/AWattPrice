import SwiftUI
import WidgetKit

struct PriceBarChartWidget: Widget {
    let kind: String = priceBarChartWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetPriceProvider()) { entry in
            PriceBarChartWidgetView(entry: entry)
        }
        .configurationDisplayName("Price Bars")
        .description("Shows the next 24 hours of electricity prices as bars.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview("Medium", as: .systemMedium) {
    PriceBarChartWidget()
} timeline: {
    WidgetPriceEntry.preview
}

#Preview("Medium Cached", as: .systemMedium) {
    PriceBarChartWidget()
} timeline: {
    WidgetPriceEntry.cachedPreview
}

#Preview("Medium Unavailable", as: .systemMedium) {
    PriceBarChartWidget()
} timeline: {
    WidgetPriceEntry.unavailablePreview
}

#Preview("Medium Pro", as: .systemMedium) {
    PriceBarChartWidget()
} timeline: {
    WidgetPriceEntry.lockedProPreview
}

#Preview("Medium Negative Prices", as: .systemMedium) {
    PriceBarChartWidget()
} timeline: {
    WidgetPriceEntry.negativePricePreview
}
