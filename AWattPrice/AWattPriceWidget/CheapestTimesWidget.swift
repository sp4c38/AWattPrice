import SwiftUI
import WidgetKit

struct CheapestTimesWidget: Widget {
    let kind: String = cheapestTimesWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetPriceProvider()) { entry in
            CheapestTimesWidgetView(entry: entry)
        }
        .configurationDisplayName("Cheapest Times")
        .description("Shows the cheapest upcoming electricity windows.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    CheapestTimesWidget()
} timeline: {
    WidgetPriceEntry.preview
}

#Preview("Cached", as: .systemSmall) {
    CheapestTimesWidget()
} timeline: {
    WidgetPriceEntry.cachedPreview
}

#Preview("Unavailable", as: .systemSmall) {
    CheapestTimesWidget()
} timeline: {
    WidgetPriceEntry.unavailablePreview
}

#Preview("Pro", as: .systemSmall) {
    CheapestTimesWidget()
} timeline: {
    WidgetPriceEntry.lockedProPreview
}
