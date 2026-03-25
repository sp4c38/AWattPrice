//
//  AWattPriceWidget.swift
//  AWattPriceWidget
//
//  Created by Léon Becker on 25.06.23.
//

import Charts
import SwiftData
import SwiftUI
import WidgetKit

// Constants for time calculations and updates
private enum TimeConstants {
    static let thirtyMinutes = 30 * 60
    static let hourInSeconds = 60 * 60
    static let dayInSeconds = 24 * 60 * 60
    static let afternoonHourThreshold = 13
    static let halfHourMark = 30
}

struct PricesWidgetProvider: TimelineProvider {
    typealias EntryType = PricesWidgetEntry
    
    func placeholder(in context: Context) -> EntryType {
        return EntryType.emptyEntry
    }

    /// Fetches energy data for the current settings
    private func fetchEnergyData(for setting: Setting) async throws -> EnergyData {
        let pricingConfiguration = setting.pricingConfiguration
        var energyData = try await EnergyData.download(marketArea: pricingConfiguration.marketArea)
        energyData.computeValues(with: pricingConfiguration)
        return energyData
    }

    func getSnapshot(in context: Context, completion: @escaping (EntryType) -> ()) {
        // Use WidgetSettingsProvider instead of SettingsManager
        let setting = WidgetSettingsProvider.shared.setting
        
        Task {
            do {
                let energyData = try await fetchEnergyData(for: setting)
                let entry = EntryType(date: Date(), energyData: energyData, setting: setting)
                completion(entry)
            } catch {
                NSLog("Error downloading energy data for widget snapshot: \(error)")
                completion(EntryType.emptyEntry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            var entries: [EntryType] = []
            let setting = WidgetSettingsProvider.shared.setting
            
            let now = Date()
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? TimeZone.current
            let startOfHour = calendar.startOfHour(for: now)
            let beginNextHour = startOfHour.addingTimeInterval(TimeInterval(TimeConstants.hourInSeconds))
            let startToday = calendar.startOfDay(for: now)
            let endToday = startToday.addingTimeInterval(TimeInterval(TimeConstants.dayInSeconds))
            
            do {
                let energyData = try await fetchEnergyData(for: setting)
                
                guard let lastEntry = energyData.prices.last else {
                    entries.append(EntryType(date: Date(), energyData: nil, setting: setting))
                    let timeline = Timeline(entries: entries, policy: .after(beginNextHour))
                    completion(timeline)
                    return
                }

                entries.append(EntryType(date: now, energyData: energyData, setting: setting))
                
                // Determine when to update the widget next
                let updatePolicy: TimelineReloadPolicy
                
                if lastEntry.startTime > endToday {
                    // We have data for tomorrow already
                    updatePolicy = .after(beginNextHour)
                } else {
                    let currentHour = calendar.component(.hour, from: now)
                    if currentHour < TimeConstants.afternoonHourThreshold {
                        // Morning hours - update on the hour
                        updatePolicy = .after(beginNextHour)
                    } else {
                        // Afternoon hours - update every 30 minutes
                        let currentMinutes = calendar.component(.minute, from: now)
                        let nextUpdateTime = currentMinutes < TimeConstants.halfHourMark
                        ? startOfHour.addingTimeInterval(TimeInterval(TimeConstants.thirtyMinutes))
                            : beginNextHour
                        
                        updatePolicy = .after(nextUpdateTime)
                    }
                }
                
                completion(Timeline(entries: entries, policy: updatePolicy))
            } catch {
                NSLog("Error downloading energy data for widget timeline: \(error)")
                entries.append(EntryType(date: Date(), energyData: nil, setting: setting))
                completion(Timeline(entries: entries, policy: .after(beginNextHour)))
            }
        }
    }
}

struct PricesWidgetEntry: TimelineEntry {
    var date: Date
    var energyData: EnergyData?
    let setting: Setting
    
    static let emptyEntry = PricesWidgetEntry(date: Date(), energyData: nil, setting: Setting())
}

struct PricesWidgetEntryView: View {
    var entry: PricesWidgetProvider.Entry
    
    let gradientColorsPositive = [Color(red: 1, green: 0.78, blue: 0.44), Color(red: 1, green: 0.08, blue: 0.06)]
    let gradientColorsNegative = [Color(red: 0, green: 0.69, blue: 0.02), Color(red: 0.56, green: 1, blue: 0.46)]
    
    init(entry: PricesWidgetProvider.Entry) {
        self.entry = entry
        // Setting is now non-optional, so no need for if-let
        // The energyData is already processed during download
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
                Chart(energyData.currentPrices.filter { $0.startTime < Date().addingTimeInterval(TimeInterval(TimeConstants.dayInSeconds)) }, id: \.startTime) { price in
                    BarMark(x: .value("Time", price.startTime ..< price.endTime), y: .value("Price", price.marketprice), width: 9.5)
                        .foregroundStyle(.linearGradient(colors: price.marketprice >= 0 ? gradientColorsPositive : gradientColorsNegative, startPoint: .bottom, endPoint: .top))
                        .alignsMarkStylesWithPlotArea()
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.hour())
                            }
                        }
                        
                        AxisTick()
                    }
                }
            } else {
                Spacer()
                Text("Couldn't download energy data.")
                Spacer()
            }
        }
        .padding([.leading, .trailing, .top, .bottom], 13)
    }
}

struct PricesWidget: Widget {
    let kind: String = pricesWidgetKind
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PricesWidgetProvider()) { entry in
            PricesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Electricity Prices")
        .description("widget.pricesWidget.description")
        .supportedFamilies([.systemMedium])
    }
}

struct AWattPriceWidget_Previews: PreviewProvider {
    static func getPreviewEnergyData() -> EnergyData {
        let decoder = EnergyData.jsonDecoder()
        let dataURL = URL(fileURLWithPath: Bundle.main.path(forResource: "PricesPreviewContent", ofType: "json")!)
        let data = try! Data(contentsOf: dataURL)
        var energyData = try! decoder.decode(EnergyData.self, from: data)
        
        // Process the preview data with settings from widget provider
        energyData.computeValues(with: WidgetSettingsProvider.shared.setting.pricingConfiguration)
        
        return energyData
    }
    
    static var setting: Setting {
        WidgetSettingsProvider.shared.setting
    }
    
    static var previews: some View {
        PricesWidgetEntryView(entry: PricesWidgetEntry(date: Date(), energyData: getPreviewEnergyData(), setting: setting))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
