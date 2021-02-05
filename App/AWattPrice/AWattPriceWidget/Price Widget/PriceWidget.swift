//
//  PriceWidget.swift
//  PriceWidget
//
//  Created by Léon Becker on 30.01.21.
//

import os
import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PriceEntry {
        PriceEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> ()) {
        let entry = PriceEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        makeNewPriceTimeline(
            in: context,
            completion: completion
        )
    }
}

struct PriceEntry: TimelineEntry {
    let date: Date
}

struct PriceWidgetEntryView : View {
    @Environment(\.appGroupManager) var appGroupManager
    // @Environment(\.widgetFamily) var widgetFamily
    
    var entry: Provider.Entry
    var energyData: EnergyData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
    
    func getEnergyData() -> EnergyData {
        let noEnergyData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
        guard appGroupManager.setGroup(AppGroups.awattpriceGroup) == true else { return noEnergyData }
        guard let energyData = appGroupManager.readEnergyDataFromGroup() else { return noEnergyData }
        return energyData
    }
    
    init(entry: PriceEntry, _ customEnergyData: EnergyData? = nil) {
        self.entry = entry
        if customEnergyData != nil {
            energyData = customEnergyData!
        } else {
            self.energyData = getEnergyData()
        }
    }
    
    var body: some View {
        HStack {
            Graph(energyData)
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

public let logger = Logger(subsystem: "me.space8.AWattPrice.PriceWidget", category: "general")

struct PriceWidget_Previews: PreviewProvider {
    static var previews: some View {
        let exampleEnergyData: EnergyData = {
            // Dynamically create some example energy data
            var newEnergyData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
            
            let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
            var currentStartDate = Calendar.current.date(
                bySettingHour: 6, minute: 0, second: 0, of: tomorrow)!
            
            for _ in 0...17 {
                let currentEndDate = currentStartDate.addingTimeInterval(3600)
                let randomMarketprice = Double.random(in: 5...10)
                let newPoint = EnergyPricePoint(
                    startTimestamp: currentStartDate, endTimestamp: currentEndDate,
                    marketprice: randomMarketprice)
                
                if randomMarketprice > newEnergyData.maxPrice {
                    newEnergyData.maxPrice = randomMarketprice
                } else if randomMarketprice < 0, randomMarketprice < newEnergyData.minPrice {
                    newEnergyData.minPrice = randomMarketprice
                }
                
                newEnergyData.prices.append(newPoint)
                currentStartDate = currentEndDate
            }
            
            return newEnergyData
        }()
        
        PriceWidgetEntryView(entry: PriceEntry(date: Date()), exampleEnergyData)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .environment(\.colorScheme, .dark)
    }
}
