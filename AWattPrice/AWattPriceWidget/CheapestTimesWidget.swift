import SwiftUI
import WidgetKit

struct CheapestTimesWidget: Widget {
    let kind: String = cheapestTimesWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetPriceProvider()) { entry in
            CheapestTimesWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.cheapest.displayName")
        .description("widget.cheapest.description")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    CheapestTimesWidget()
} timeline: {
    WidgetPriceEntry.preview
}
