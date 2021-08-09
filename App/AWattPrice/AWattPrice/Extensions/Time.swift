//
//  Time.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.02.21.
//

import Foundation

enum SingleDateComponents {
    case year, month, day
    case hour, minute, second
}

/** Set the components of the current time in the specified time zone to the parsed components.
 The value of components not included in the parsed list are retained.
 
 Example of functionality:
    Get current time -> set components which are included in the parsed components list to the specified value ->
    create Date object from components -> return
    So, the returned Date object reflects the timestamp at which the components in the specified timezone would match the parsed components.
 
 - returns: Date object representing the certain time with the set components.
 */
func getTimeBySetting(
    _ components: [SingleDateComponents: Int], inTimeZone timeZone: TimeZone)
-> Date? {
    let now = Date()
    var newComponents = Calendar.current.dateComponents(in: timeZone, from: now)
    
    for comp in components.keys {
        let newValue = components[comp]
        if comp == .second { newComponents.second = newValue }
        if comp == .minute { newComponents.minute = newValue }
        if comp == .hour { newComponents.hour = newValue }
        if comp == .day { newComponents.day = newValue }
        if comp == .month { newComponents.month = newValue }
        if comp == .year { newComponents.year = newValue }
    }
    
    let newDate = Calendar.current.date(from: newComponents)
    return newDate
}

func convertHTTPTimeStringToDate(timeString: String) -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
    
    guard let convertedTime = dateFormatter.date(from: timeString) else { return nil }
    
    return convertedTime
}

func getHTTPCacheControlMaxAgeSeconds(cacheControlString: String) -> TimeInterval? {
    let cacheControlRegex = """
    ^[^\\d]*(\\d*)$
    """
    let regex = NSRegularExpression(cacheControlRegex)
    
    guard let match = regex.firstMatch(in: cacheControlString, options: [], range: cacheControlString.completeNSRange),
          match.numberOfRanges == 2
    else {
        return nil
    }
    
    let nsMatchRange = match.range(at: 1)
    guard let matchRange = Range(nsMatchRange, in: cacheControlString) else { return nil }
    let matchedString = String(cacheControlString[matchRange])
    
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .none
    guard let maxAgeRaw = numberFormatter.number(from: matchedString) else { return nil }
    
    let maxAge = TimeInterval(truncating: maxAgeRaw)
    return maxAge
}
