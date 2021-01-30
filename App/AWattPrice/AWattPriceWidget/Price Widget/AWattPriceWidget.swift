//
//  AWattPriceWidget.swift
//  AWattPriceWidget
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

struct AWattPriceWidgetEntryView : View {
    // @Environment(\.widgetFamily) var widgetFamily
    
    var entry: Provider.Entry
    
    let prices = [
        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612008000), endTimestamp: Date(timeIntervalSince1970: 1612011600), marketprice: 5.06),
        
        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612011600), endTimestamp: Date(timeIntervalSince1970: 1612015200), marketprice: 4.8),

        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612015200), endTimestamp: Date(timeIntervalSince1970: 1612018800), marketprice: 4.8),

        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612018800), endTimestamp: Date(timeIntervalSince1970: 1612022400), marketprice: 5.66),

        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612022400), endTimestamp: Date(timeIntervalSince1970: 1612026000), marketprice: 6.06),

        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612026000), endTimestamp: Date(timeIntervalSince1970: 1612029600), marketprice: 6.17),

        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612029600), endTimestamp: Date(timeIntervalSince1970: 1612033200), marketprice: 5.96),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612033200), endTimestamp: Date(timeIntervalSince1970: 1612036800), marketprice: 5.28),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612036800), endTimestamp: Date(timeIntervalSince1970: 1612040400), marketprice: 4.7),
//
//        EnergyPricePoint(startTimestamp: Date(timeIntervalSince1970: 1612040400), endTimestamp: Date(timeIntervalSince1970: 1612044000), marketprice: 4.7),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-30 22:00:00 +0000, endTimestamp: 2021-01-30 23:00:00 +0000, marketprice: 4.23),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-30 23:00:00 +0000, endTimestamp: 2021-01-31 00:00:00 +0000, marketprice: 4.21),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 00:00:00 +0000, endTimestamp: 2021-01-31 01:00:00 +0000, marketprice: 4.1),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 01:00:00 +0000, endTimestamp: 2021-01-31 02:00:00 +0000, marketprice: 4.05),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 02:00:00 +0000, endTimestamp: 2021-01-31 03:00:00 +0000, marketprice: 3.95),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 03:00:00 +0000, endTimestamp: 2021-01-31 04:00:00 +0000, marketprice: 3.86),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 04:00:00 +0000, endTimestamp: 2021-01-31 05:00:00 +0000, marketprice: 4.04),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 05:00:00 +0000, endTimestamp: 2021-01-31 06:00:00 +0000, marketprice: 4.04),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 06:00:00 +0000, endTimestamp: 2021-01-31 07:00:00 +0000, marketprice: 4.13),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 07:00:00 +0000, endTimestamp: 2021-01-31 08:00:00 +0000, marketprice: 4.49),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 08:00:00 +0000, endTimestamp: 2021-01-31 09:00:00 +0000, marketprice: 4.92),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 09:00:00 +0000, endTimestamp: 2021-01-31 10:00:00 +0000, marketprice: 5.07),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 10:00:00 +0000, endTimestamp: 2021-01-31 11:00:00 +0000, marketprice: 5.11),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 11:00:00 +0000, endTimestamp: 2021-01-31 12:00:00 +0000, marketprice: 5.04),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 12:00:00 +0000, endTimestamp: 2021-01-31 13:00:00 +0000, marketprice: 4.62),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 13:00:00 +0000, endTimestamp: 2021-01-31 14:00:00 +0000, marketprice: 4.59),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 14:00:00 +0000, endTimestamp: 2021-01-31 15:00:00 +0000, marketprice: 4.79),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 15:00:00 +0000, endTimestamp: 2021-01-31 16:00:00 +0000, marketprice: 5.29),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 16:00:00 +0000, endTimestamp: 2021-01-31 17:00:00 +0000, marketprice: 6.45),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 17:00:00 +0000, endTimestamp: 2021-01-31 18:00:00 +0000, marketprice: 6.39),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 18:00:00 +0000, endTimestamp: 2021-01-31 19:00:00 +0000, marketprice: 6.24),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 19:00:00 +0000, endTimestamp: 2021-01-31 20:00:00 +0000, marketprice: 5.8),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 20:00:00 +0000, endTimestamp: 2021-01-31 21:00:00 +0000, marketprice: 5.13),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 21:00:00 +0000, endTimestamp: 2021-01-31 22:00:00 +0000, marketprice: 4.93),
//        AWattPrice.EnergyPricePoint(startTimestamp: 2021-01-31 22:00:00 +0000, endTimestamp: 2021-01-31 23:00:00 +0000, marketprice: 4.54)
    ]

    var body: some View {
        HStack {
            Graph(EnergyData(prices: prices, minPrice: 0, maxPrice: 6.17))
        }
    }
}

struct AWattPriceWidget: Widget {
    let kind: String = "AWattPriceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AWattPriceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("prices.name")
        .description("prices.description")
        .supportedFamilies([.systemMedium])
    }
}

struct AWattPriceWidget_Previews: PreviewProvider {
    static var previews: some View {
        AWattPriceWidgetEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .environment(\.colorScheme, .dark)
    }
}
