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

struct CheapestTimesWidget_Previews: PreviewProvider {
    static var previews: some View {
        CheapestTimesWidgetView(entry: .preview)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
