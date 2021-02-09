//
//  TimezoneTime.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.02.21.
//

import Foundation

fileprivate func packNewTimeComponent(comp: String, isLast: Bool) -> String {
    if isLast {
        return comp
    } else {
        return "\(comp):"
    }
}

fileprivate func addNewTimeComponent(
    newComp: String?, original: String, isLast: Bool = false
) -> String {
    if newComp != nil {
        return packNewTimeComponent(comp: newComp!, isLast: isLast)
    } else {
        return packNewTimeComponent(comp: original, isLast: isLast)
    }
}

fileprivate func setLongISOTimeComponents(hour: Int?, minute: Int?, second: Int?, of timeISO: String) -> String {
    let timeComponentFormatter = NumberFormatter()
    timeComponentFormatter.minimumIntegerDigits = 2
    timeComponentFormatter.maximumIntegerDigits = 2
    let hourString: String? = timeComponentFormatter.string(from: NSNumber(value: hour ?? 0))
    let minuteString: String? = timeComponentFormatter.string(from: NSNumber(value: minute ?? 0))
    let secondString: String? = timeComponentFormatter.string(from: NSNumber(value: second ?? 0))
    
    let dateComp = timeISO.part(inRange: 0..<11)
    let timeComp = timeISO.part(inRange: 11..<19)
    let utcOffsetComp = timeISO.part(inRange: 19..<25)
    
    let hourComp = timeComp.part(inRange: 0..<2)
    let minuteComp = timeComp.part(inRange: 3..<5)
    let secondComp = timeComp.part(inRange: 6..<8)
    
    var newTime = ""
    newTime += addNewTimeComponent(newComp: hourString, original: hourComp)
    newTime += addNewTimeComponent(newComp: minuteString, original: minuteComp)
    newTime += addNewTimeComponent(newComp: secondString, original: secondComp, isLast: true)
    
    let newISO = dateComp + newTime + utcOffsetComp
    return newISO
}

func getTimeZoneTimeBySetting(hour: Int?, minute: Int?, second: Int?, usingTimeZone: String) -> Date? {
    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    isoFormatter.timeZone = TimeZone(identifier: "Europe/Berlin")
    let nowTimeZoneISO = isoFormatter.string(from: Date())
    
    let modifiedISO = setLongISOTimeComponents(
        hour: hour, minute: minute, second: second, of: nowTimeZoneISO
    )
    let modifiedTimeZoneDate = isoFormatter.date(from: modifiedISO)

    return modifiedTimeZoneDate
}
