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
    
    func getPrices() -> [EnergyPricePoint] {
        print("Run")
        guard let energyData = appGroupManager.readEnergyDataFromGroup() else { return [] }
        print(energyData)
        return energyData.prices
    }
    
    init(entry: SimpleEntry) {
        self.entry = entry
    }
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612008000), endTimestamp: Date(timeIntervalSince1970: 1612011600), marketprice: 5.06),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612011600), endTimestamp: Date(timeIntervalSince1970: 1612015200), marketprice: 4.8),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612015200), endTimestamp: Date(timeIntervalSince1970: 1612018800), marketprice: 4.8),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612018800), endTimestamp: Date(timeIntervalSince1970: 1612022400), marketprice: 5.66),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612022400), endTimestamp: Date(timeIntervalSince1970: 1612026000), marketprice: 6.06),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612026000), endTimestamp: Date(timeIntervalSince1970: 1612029600), marketprice: 6.17),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612029600), endTimestamp: Date(timeIntervalSince1970: 1612033200), marketprice: 5.96),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612033200), endTimestamp: Date(timeIntervalSince1970: 1612036800), marketprice: 5.28),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612036800), endTimestamp: Date(timeIntervalSince1970: 1612040400), marketprice: 4.7),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612040400), endTimestamp: Date(timeIntervalSince1970: 1612044000), marketprice: 4.7),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612044000), endTimestamp: Date(timeIntervalSince1970: 1612047600), marketprice: 4.23),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612047600), endTimestamp: Date(timeIntervalSince1970: 1612051200), marketprice: 4.21),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612051200), endTimestamp: Date(timeIntervalSince1970: 1612054800), marketprice: 4.1),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612054800), endTimestamp: Date(timeIntervalSince1970: 1612058400), marketprice: 4.05),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612058400), endTimestamp: Date(timeIntervalSince1970: 1612062000), marketprice: 3.95),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612062000), endTimestamp: Date(timeIntervalSince1970: 1612065600), marketprice: 3.86),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612065600), endTimestamp: Date(timeIntervalSince1970: 1612069200), marketprice: 4.04),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612069200), endTimestamp: Date(timeIntervalSince1970: 1612072800), marketprice: 4.04),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612072800), endTimestamp: Date(timeIntervalSince1970: 1612076400), marketprice: 4.13),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612076400), endTimestamp: Date(timeIntervalSince1970: 1612080000), marketprice: 4.49),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612080000), endTimestamp: Date(timeIntervalSince1970: 1612083600), marketprice: 4.92),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612083600), endTimestamp: Date(timeIntervalSince1970: 1612087200), marketprice: 5.07),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612087200), endTimestamp: Date(timeIntervalSince1970: 1612090800), marketprice: 5.11),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612090800), endTimestamp: Date(timeIntervalSince1970: 1612094400), marketprice: 5.04),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612094400), endTimestamp: Date(timeIntervalSince1970: 1612098000), marketprice: 4.62),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612098000), endTimestamp: Date(timeIntervalSince1970: 1612101600), marketprice: 4.59),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612101600), endTimestamp: Date(timeIntervalSince1970: 1612101600), marketprice: 4.79),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612101600), endTimestamp: Date(timeIntervalSince1970: 1612108800), marketprice: 5.29),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612108800), endTimestamp: Date(timeIntervalSince1970: 1612112400), marketprice: 6.45),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612112400), endTimestamp: Date(timeIntervalSince1970: 1612116000), marketprice: 6.39),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612116000), endTimestamp: Date(timeIntervalSince1970: 1612119600), marketprice: 6.24),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612119600), endTimestamp: Date(timeIntervalSince1970: 1612123200), marketprice: 5.8),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612123200), endTimestamp: Date(timeIntervalSince1970: 1612126800), marketprice: 5.13),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612126800), endTimestamp: Date(timeIntervalSince1970: 1612130400), marketprice: 4.93),
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612130400), endTimestamp: Date(timeIntervalSince1970: 1612134000), marketprice: 4.54)
//    ]

    var body: some View {
        HStack {
            Graph(EnergyData(prices: getPrices(), minPrice: 0, maxPrice: 6.17))
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
