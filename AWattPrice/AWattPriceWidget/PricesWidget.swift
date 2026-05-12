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

struct PricesWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForecastWidgetView(entry: .preview)
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            ForecastWidgetView(entry: .preview)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
