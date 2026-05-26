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
    WidgetGenerationMixEntry(
        date: Date(),
        snapshot: WidgetGenerationMixPreviewData.snapshot(),
        state: .cached
    )
}

#Preview("Unavailable", as: .systemSmall) {
    RenewableMixWidget()
} timeline: {
    WidgetGenerationMixEntry(
        date: Date(),
        snapshot: WidgetGenerationMixSnapshot.empty(),
        state: .unavailable
    )
}

#Preview("Pro", as: .systemSmall) {
    RenewableMixWidget()
} timeline: {
    WidgetGenerationMixEntry(
        date: Date(),
        snapshot: WidgetGenerationMixPreviewData.snapshot(),
        state: .lockedPro
    )
}

#Preview(as: .accessoryRectangular) {
    RenewableMixWidget()
} timeline: {
    WidgetGenerationMixEntry.preview
}
