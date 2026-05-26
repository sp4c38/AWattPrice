import SwiftUI
import WidgetKit

struct CurrentPriceWidget: Widget {
    let kind: String = currentPriceWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetPriceProvider()) { entry in
            CurrentPriceWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.current.displayName")
        .description("widget.current.description")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    CurrentPriceWidget()
} timeline: {
    WidgetPriceEntry.preview
}
