import SwiftUI
import WidgetKit

struct CurrentPriceWidget: Widget {
    let kind: String = currentPriceWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetPriceProvider()) { entry in
            CurrentPriceWidgetView(entry: entry)
        }
        .configurationDisplayName("Current Price")
        .description("Shows the current electricity price.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    CurrentPriceWidget()
} timeline: {
    WidgetPriceEntry.preview
}

#Preview(as: .accessoryCircular) {
    CurrentPriceWidget()
} timeline: {
    WidgetPriceEntry.preview
}

#Preview(as: .accessoryRectangular) {
    CurrentPriceWidget()
} timeline: {
    WidgetPriceEntry.preview
}
