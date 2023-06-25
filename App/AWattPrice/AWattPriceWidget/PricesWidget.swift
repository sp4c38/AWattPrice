//
//  AWattPriceWidget.swift
//  AWattPriceWidget
//
//  Created by Léon Becker on 25.06.23.
//

import Charts
import SwiftUI
import WidgetKit

struct PricesWidgetProvider: TimelineProvider {
    typealias EntryType = PricesWidgetEntry
    
    func placeholder(in context: Context) -> EntryType {
        let energyData = EnergyData(prices: [])
        return EntryType(date: Date(), energyData: energyData)
    }

    func getSnapshot(in context: Context, completion: @escaping (EntryType) -> ()) {
        Task {
            let energyData = await EnergyData.downloadEnergyData()
            let entry = EntryType(date: Date(), energyData: energyData)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            var entries: [EntryType] = []
            guard let energyData = await EnergyData.downloadEnergyData(),
                  let lastEntry = energyData.prices.last else { // energyData.prices are sorted by start time.
                entries = [
                    EntryType(date: Date(), energyData: nil),
                    EntryType(date: Date().addingTimeInterval(3600), energyData: nil)
                ]
                let timeline = Timeline(entries: entries, policy: .atEnd)
                completion(timeline)
                return
            }
            
            let now = Date()
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
            let startToday = calendar.startOfDay(for: now)
            let endToday = startToday.addingTimeInterval(24 * 60 * 60)

            entries.append(EntryType(date: now, energyData: energyData))
            if lastEntry.startTime > endToday {
                let tomorrow13Clock = endToday.addingTimeInterval(13 * 60 * 60)
                completion(Timeline(entries: entries, policy: .after(tomorrow13Clock)))
                return
            } else {
                let currentHour = calendar.component(.hour, from: now)
                if currentHour < 13 {
                    let today13Clock = startToday.addingTimeInterval(13 * 60 * 60)
                    completion(Timeline(entries: entries, policy: .after(today13Clock)))
                    return
                } else {
                    // Update each 30 minutes
                    var updatePolicy: TimelineReloadPolicy
                    let currentMinutes = calendar.component(.minute, from: now)
                    let startOfHour = calendar.startOfHour(for: now)
                    if currentMinutes < 30 {
                        updatePolicy = .after(startOfHour.addingTimeInterval(30 * 60))
                    } else {
                        updatePolicy = .after(startOfHour.addingTimeInterval(60 * 60))
                    }
                    completion(Timeline(entries: entries, policy: updatePolicy))
                }
            }
        }
    }
}

struct PricesWidgetEntry: TimelineEntry {
    var date: Date
    let energyData: EnergyData?
}

struct PricesWidgetEntryView : View {
    var entry: PricesWidgetProvider.Entry
    
    let gradientColorsPositive = [Color(red: 1, green: 0.78, blue: 0.44), Color(red: 1, green: 0.08, blue: 0.06)]
    let gradientColorsNegative = [Color(red: 0, green: 0.69, blue: 0.02), Color(red: 0.56, green: 1, blue: 0.46)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next 24h")
                .bold()
            
            if let energyData = entry.energyData {
                Chart {
                    ForEach(energyData.prices, id: \.startTime) { price in
                        BarMark(x: .value("Time", price.startTime), y: .value("Price", price.marketprice))
                            .foregroundStyle(.linearGradient(colors: price.marketprice >= 0 ? gradientColorsPositive : gradientColorsNegative, startPoint: .bottom, endPoint: .top))
                            .alignsMarkStylesWithPlotArea()
                    }
                }
            } else {
                Text("Couldn't download energy data.")
            }
        }
        .padding([.leading, .trailing, .top, .bottom])
    }
}

struct PricesWidget: Widget {
    let kind: String = "AWattPriceWidget.PricesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PricesWidgetProvider()) { entry in
            PricesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Electricity Prices")
        .description("View electricity prices at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct AWattPriceWidget_Previews: PreviewProvider {
    static func getPreviewEnergyData() -> EnergyData {
        let decoder = EnergyData.jsonDecoder()
        let dataURL = URL(fileURLWithPath: Bundle.main.path(forResource: "PricesPreviewContent", ofType: "json")!)
        let data = try! Data(contentsOf: dataURL)
        return try! decoder.decode(EnergyData.self, from: data)
    }
    
    static var previews: some View {
        PricesWidgetEntryView(entry: PricesWidgetEntry(date: Date(), energyData: getPreviewEnergyData()))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
