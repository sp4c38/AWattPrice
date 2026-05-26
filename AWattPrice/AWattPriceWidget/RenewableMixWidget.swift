import SwiftUI
import WidgetKit

struct RenewableMixWidget: Widget {
    let kind: String = renewableMixWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetGenerationMixProvider()) { entry in
            RenewableMixWidgetView(entry: entry)
        }
        .configurationDisplayName("Renewable mix")
        .description("Shows the current renewable energy mix.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    RenewableMixWidget()
} timeline: {
    WidgetGenerationMixEntry.preview
}

#Preview("Cached", as: .systemSmall) {
    RenewableMixWidget()
} timeline: {
    WidgetGenerationMixEntry.cachedPreview
}

#Preview("Unavailable", as: .systemSmall) {
    RenewableMixWidget()
} timeline: {
    WidgetGenerationMixEntry.unavailablePreview
}

#Preview("Pro", as: .systemSmall) {
    RenewableMixWidget()
} timeline: {
    WidgetGenerationMixEntry.lockedProPreview
}

#Preview(as: .accessoryRectangular) {
    RenewableMixWidget()
} timeline: {
    WidgetGenerationMixEntry.preview
}
