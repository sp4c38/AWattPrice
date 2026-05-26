import SwiftUI
import WidgetKit

struct PricesWidget: Widget {
    let kind: String = pricesWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetPriceProvider()) { entry in
            ForecastWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.forecast.displayName")
        .description("widget.forecast.description")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview("Medium", as: .systemMedium) {
    PricesWidget()
} timeline: {
    WidgetPriceEntry.preview
}

#Preview("Large", as: .systemLarge) {
    PricesWidget()
} timeline: {
    WidgetPriceEntry.preview
}
