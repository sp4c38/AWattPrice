import SwiftUI
import WidgetKit

struct PricesWidget: Widget {
    let kind: String = pricesWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetPriceProvider()) { entry in
            ForecastWidgetView(entry: entry)
        }
        .configurationDisplayName("Price Line")
        .description("Shows all upcoming electricity prices.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview("Medium", as: .systemMedium) {
    PricesWidget()
} timeline: {
    WidgetPriceEntry.preview
}

#Preview("Medium Cached", as: .systemMedium) {
    PricesWidget()
} timeline: {
    WidgetPriceEntry.cachedPreview
}

#Preview("Medium Unavailable", as: .systemMedium) {
    PricesWidget()
} timeline: {
    WidgetPriceEntry.unavailablePreview
}

#Preview("Medium Pro", as: .systemMedium) {
    PricesWidget()
} timeline: {
    WidgetPriceEntry.lockedProPreview
}
