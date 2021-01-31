//
//  PriceWidget.swift
//  PriceWidget
//
//  Created by Léon Becker on 30.01.21.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct PriceWidgetEntryView : View {
    @Environment(\.appGroupManager) var appGroupManager
    // @Environment(\.widgetFamily) var widgetFamily
    
    var entry: Provider.Entry
    
    func getEnergyData() -> EnergyData {
        let noEnergyData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
        guard appGroupManager.setGroup(AppGroups.awattpriceGroup) == true else { return noEnergyData }
        guard let energyData = appGroupManager.readEnergyDataFromGroup() else { return noEnergyData }
        return energyData
    }
    
    init(entry: SimpleEntry) {
        self.entry = entry
    }

    var body: some View {
        HStack {
            Graph(getEnergyData())
        }
    }
}

struct PriceWidget: Widget {
    let kind: String = "me.space8.AWattPrice.PriceWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PriceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("prices.name")
        .description("prices.description")
        .supportedFamilies([.systemMedium])
    }
}

struct PriceWidget_Previews: PreviewProvider {
    static var previews: some View {
        PriceWidgetEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .environment(\.colorScheme, .dark)
    }
}
