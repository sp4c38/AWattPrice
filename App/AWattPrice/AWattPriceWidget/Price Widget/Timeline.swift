//
//  Timeline.swift
//  AWattPriceWidgetExtension
//
//  Created by Léon Becker on 04.02.21.
//

import WidgetKit

//in context: Context, completion: @escaping (Timeline<Entry>
func makeNewPriceTimeline(
    in context: TimelineProviderContext,
    completion: @escaping (Timeline<PriceEntry>) -> ()
) {
    var entries: [PriceEntry] = []
    // Generate a timeline consisting of five entries an hour apart, starting from the current date.
    let currentDate = Date()
    for hourOffset in 0 ..< 5 {
        let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
        let entry = PriceEntry(date: entryDate)
        entries.append(entry)
    }

    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
}
