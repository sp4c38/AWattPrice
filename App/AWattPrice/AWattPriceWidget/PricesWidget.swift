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
        print("Computing timeline.")
        Task {
            var entries: [EntryType] = []
            
            let now = Date()
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
            let startOfHour = calendar.startOfHour(for: now)
            let beginNextHour = startOfHour.addingTimeInterval(60 * 60)
            let startToday = calendar.startOfDay(for: now)
            let endToday = startToday.addingTimeInterval(24 * 60 * 60)
            
            guard let energyData = await EnergyData.downloadEnergyData(),
                  let lastEntry = energyData.prices.last else { // energyData.prices are sorted by start time.
                entries.append(EntryType(date: Date(), energyData: nil))
                let timeline = Timeline(entries: entries, policy: .after(beginNextHour))
                completion(timeline)
                return
            }

            entries.append(EntryType(date: now, energyData: energyData))
            if lastEntry.startTime > endToday {
                completion(Timeline(entries: entries, policy: .after(beginNextHour)))
                return
            } else {
                let currentHour = calendar.component(.hour, from: now)
                if currentHour < 13 {
                    completion(Timeline(entries: entries, policy: .after(beginNextHour)))
                    return
                } else {
                    // Update each 30 minutes
                    var updatePolicy: TimelineReloadPolicy
                    let currentMinutes = calendar.component(.minute, from: now)
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
    var energyData: EnergyData?
}

struct PricesWidgetEntryView : View {
    var entry: PricesWidgetProvider.Entry
    
    let gradientColorsPositive = [Color(red: 1, green: 0.78, blue: 0.44), Color(red: 1, green: 0.08, blue: 0.06)]
    let gradientColorsNegative = [Color(red: 0, green: 0.69, blue: 0.02), Color(red: 0.56, green: 1, blue: 0.46)]
    
    init(entry: PricesWidgetProvider.Entry) {
        self.entry = entry
        self.entry.energyData?.processCalculatedValues()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Next 24h")
                    .bold()
                Spacer()
                Text("price in ct")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 3)
                
            if let energyData = entry.energyData {
                Chart(energyData.currentPrices.prefix(24), id: \.startTime) { price in
                    BarMark(x: .value("Time", price.startTime ..< price.endTime), y: .value("Price", price.marketprice), width: 9.5)
                        .foregroundStyle(.linearGradient(colors: price.marketprice >= 0 ? gradientColorsPositive : gradientColorsNegative, startPoint: .bottom, endPoint: .top))
                        .alignsMarkStylesWithPlotArea()
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                VStack(alignment: .leading) {
                                    Text(date, format: .dateTime.hour())
                                }
                            }
                        }
                        
                        AxisTick()
                    }
                }
            } else {
                Text("Couldn't download energy data.")
            }
        }
        .padding([.leading, .trailing, .top, .bottom], 13)
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
