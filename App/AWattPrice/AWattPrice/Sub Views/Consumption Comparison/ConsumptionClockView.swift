//
//  ConsumptionClockView.swift
//  AwattarApp
//
//  Created by Léon Becker on 25.09.20.
//

import SwiftUI

/// A clock which job it is to visually present the cheapest hours for the consumption so that these informations can be immediately and fastly processed by the user.
struct ConsumptionClockView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var currentLevel = 0
    @State var now = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let calendar = Calendar.current
    var timeIsAM: Bool = true // Default value will be changed if needed
    var startDateString: (String, String?) = ("", nil)
    var endDateString: (String, String)? = nil

    var hourDegree = (0, 0)

    init(_ cheapestHourPair: CheapestHourManager.HourPair) {
        let minItemIndex = 0
        let maxItemIndex = cheapestHourPair.associatedPricePoints.count - 1

        if cheapestHourPair.associatedPricePoints.count >= 1 {
            let startTimeFirstItem = Date(timeIntervalSince1970: TimeInterval(cheapestHourPair.associatedPricePoints[minItemIndex].startTimestamp))
            let startHour = Float(calendar.component(.hour, from: startTimeFirstItem))
            let startMinuteFraction = Float(calendar.component(.minute, from: startTimeFirstItem)) / 60

            let endTimeLastItem = Date(timeIntervalSince1970: TimeInterval(cheapestHourPair.associatedPricePoints[maxItemIndex].endTimestamp))
            let endHour = Float(calendar.component(.hour, from: endTimeLastItem))
            let endMinuteFraction = Float(calendar.component(.minute, from: endTimeLastItem)) / 60

            // Subtract 90 degrees to make the cheapest hour indicator fit with the clocks alignment
            var startDegree = Int(30 * (startHour + startMinuteFraction)) - 90
            var endDegree = Int(30 * (endHour + endMinuteFraction)) - 90

            print(startDegree)
            print(endDegree)
            
            if (startHour + startMinuteFraction) > 12 {
                // Change to PM if in PM section
                timeIsAM = false
                
                startDegree -= 360
            }
            
            if (endHour + endMinuteFraction) > 12 {
                endDegree -= 360
            }
            
            // Add or subtract some degrees to compensate the overlap which occurs because of the lineCap applied to the cheapest hour indicator
            if endDegree - startDegree > 7 {
                startDegree += 3
                if startHour == endHour {
                    if endMinuteFraction - startMinuteFraction >= 0.5 {
                        endDegree -= 3
                    } else {
                        endDegree += 2
                    }
                } else if startHour != endHour {
                    endDegree -= 3
                }
            } else if endDegree - startDegree == 0 {
                startDegree -= 1
            }
//            } else if endDegree - startDegree > 3 {
//                startDegree += 3
//            }

            hourDegree = (startDegree, endDegree)
            
            // Show the dates the cheapest hour indicator crosses
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "dd"
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            
            if calendar.startOfDay(for: startTimeFirstItem) == calendar.startOfDay(for: endTimeLastItem) {
                startDateString = (dayFormatter.string(from: startTimeFirstItem), monthFormatter.string(from: startTimeFirstItem))
            } else {
                if monthFormatter.string(from: startTimeFirstItem) == monthFormatter.string(from: endTimeLastItem) {
                    startDateString = (dayFormatter.string(from: startTimeFirstItem), nil)
                } else {
                    startDateString = (dayFormatter.string(from: startTimeFirstItem), monthFormatter.string(from: startTimeFirstItem))
                }
                endDateString = (dayFormatter.string(from: endTimeLastItem), monthFormatter.string(from: endTimeLastItem))
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            self.makeView(geometry)
        }
        .onReceive(timer) { input in
            // Update the clock to make both markers (hour and minute) point in the correct direction while time progresses
            now = Date()
        }
    }

    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height

        let circleLineWidth = CGFloat(2)
        let hourIndicatorLineWidth = CGFloat(2)
        let middlePointRadius = CGFloat(5)

        let clockWidth = 6.5 * (width / 10)
        let hourBorderIndicatorWidth = CGFloat(4)
        let hourMarkerRadius = CGFloat(0.85 * ((clockWidth / 2) - circleLineWidth))
        let minuteIndicatorWidth = CGFloat((clockWidth / 2) - hourBorderIndicatorWidth - 10)
        let hourIndicatorWidth = CGFloat((2 * ((clockWidth / 2) / 3)) - hourBorderIndicatorWidth  - 10)

        let hourMarkerLineWidth = CGFloat(0.2 * (clockWidth / 2))

        let clockRightSideStartWidth = ((width - clockWidth) / 2)
        let clockStartHeight = (height / 2) - (width / 2) + clockRightSideStartWidth

        let textPaddingToClock = CGFloat(23)

        let center = CGPoint(x: width / 2, y: height / 2)

        let currentMinute = Double(calendar.component(.minute, from: now))
        let currentMinuteXCoord = CGFloat(Double(minuteIndicatorWidth) * sin((6 * currentMinute * Double.pi) / 180)) + clockRightSideStartWidth + (clockWidth / 2)
        let currentMinuteYCoord = CGFloat(Double(minuteIndicatorWidth) * -cos((6 * currentMinute * Double.pi) / 180)) + clockStartHeight + (clockWidth / 2)

        var currentHour = Double(calendar.component(.hour, from: now))
        currentHour += (currentMinute / 60) // Add minutes

        if currentHour > 12 {
            currentHour -= 12
        }
        let currentHourXCoord = CGFloat(Double(hourIndicatorWidth) * sin((30 * currentHour * Double.pi) / 180)) + clockRightSideStartWidth + (clockWidth / 2)
        let currentHourYCoord = CGFloat(Double(hourIndicatorWidth) * -cos((30 * currentHour * Double.pi) / 180)) + clockStartHeight + (clockWidth / 2)

        var hourNamesAndPositions = [(String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)]()
        var currentDegree: Double = -60
        
        // Calculate text and line positions for the hours 1 to 12 which are shown on a normal clock
        for hourName in 1...12 {
            // Calculate the x coord and y coord for the text with the currentDegree and the radius of the circle
            let xCoordTextDiff = CGFloat(Double((clockWidth / 2) + textPaddingToClock) * cos(currentDegree * Double.pi / 180))
            let yCoordTextDiff = CGFloat(Double((clockWidth / 2) + textPaddingToClock) * sin(currentDegree * Double.pi / 180))

            // Define the final text coordinates out of the created values
            let textXCoord = clockRightSideStartWidth + (clockWidth / 2) + xCoordTextDiff
            let textYCoord = clockStartHeight + (clockWidth / 2) + yCoordTextDiff

            // Calculate the start and endposition of the lines around the clock representing the start point of hours
            let lineFirstXCoord = CGFloat(Double(clockWidth / 2 + hourBorderIndicatorWidth) * cos(currentDegree * Double.pi / 180)) + clockRightSideStartWidth + (clockWidth / 2)
            let lineFirstYCoord = CGFloat(Double(clockWidth / 2 + hourBorderIndicatorWidth) * sin(currentDegree * Double.pi / 180)) + clockStartHeight + (clockWidth / 2)

            let lineSecondXCoord = CGFloat(Double(clockWidth / 2 - circleLineWidth) * cos(currentDegree * Double.pi / 180)) + clockRightSideStartWidth + (clockWidth / 2)
            let lineSecondYCoord = CGFloat(Double(clockWidth / 2 - circleLineWidth) * sin(currentDegree * Double.pi / 180)) + clockStartHeight + (clockWidth / 2)

            // Add all values the the hourNamesAndPositions array which will later be used to draw the text and lines
            hourNamesAndPositions.append((String(hourName), textXCoord, textYCoord, lineFirstXCoord, lineFirstYCoord, lineSecondXCoord, lineSecondYCoord))

            currentDegree += 30
        }
        
        return ZStack {
            // Outside circle which holds the clock inside of it
            Circle()
                .foregroundColor(colorScheme == .light ? Color.white : Color.black)
                .frame(width: width, height: height)
                .shadow(color: colorScheme == .light ? Color.gray : Color(red: 0.45, green: 0.45, blue: 0.45), radius: 10)

//            Path { path in
//                path.addArc(center: center, radius: (clockWidth / 2) - circleLineWidth, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
//                path.addArc(center: center, radius: clockWidth / 2, startAngle: .degrees(360), endAngle: .degrees(0), clockwise: true)
//            }
//            .foregroundColor(colorScheme == .light ? Color.black : Color.white)

            
            // A little point in the direct center of the clock at which the hour indicator and the minute indicator originate from
            Path { path in
                path.addArc(center: center, radius: middlePointRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
            }
            .fill(colorScheme == .light ? Color.black : Color.white)

            // A outline of a circle around the inner enclosure of the clock on which later the cheapest hour indicator is drawn ontop. It's just an element to improve the UI experience for the user.
            Path { path in
                path.addArc(center: center, radius: hourMarkerRadius - (hourMarkerLineWidth / 2), startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

                path.addArc(center: center, radius: hourMarkerRadius + (hourMarkerLineWidth / 2), startAngle: .degrees(360), endAngle: .degrees(0), clockwise: true)
            }
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            .opacity(colorScheme == .light ? 0.1 : 0.3)

            // The cheapest hour indicator which is ontop of the outline of the circle around the inner enclosure
            Path { path in
                path.addArc(center: center, radius: hourMarkerRadius, startAngle: .degrees(Double(hourDegree.0)), endAngle: .degrees(Double(hourDegree.1)), clockwise: false)
            }
            .strokedPath(.init(lineWidth: hourMarkerLineWidth, lineCap: .round))
            .foregroundColor(Color(hue: 0.3786, saturation: 0.6959, brightness: 0.8510))

            // The different hour texts (1 to 12) and their lines to indicate when a hour starts and to give some basic orientation on the clock
            ForEach(hourNamesAndPositions, id: \.0) { hour in
                Text(hour.0)
                    .bold()
                    .position(x: hour.1, y: hour.2)

                Path { path in
                    path.move(to: CGPoint(x: hour.3, y: hour.4))
                    path.addLine(to: CGPoint(x: hour.5, y: hour.6))
                }
                .strokedPath(.init(lineWidth: hourIndicatorLineWidth, lineCap: .round))
                .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            }

            // The start date and if needed also the end date which help the user understand from when to when the cheapest hours apply
            HStack(spacing: 10) {
                VStack(spacing: 0) {
                    if endDateString == nil {
                        Text("on")
                            .padding(.bottom, 3)
                    }
                    
                    HStack(spacing: 7) {
                        Text(startDateString.0)
                            .bold()
                            .foregroundColor(Color.red)

                        if startDateString.1 != nil {
                            Text(startDateString.1!)
                                .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                        }
                    }
                }

                if endDateString != nil {
                    Text("to")

                    HStack(spacing: 7) {
                        Text(endDateString!.0)
                            .bold()
                            .foregroundColor(Color.red)

                        Text(endDateString!.1)
                            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                    }
                }
            }
            .font(.headline)
            .position(x: clockRightSideStartWidth + clockWidth / 2,
                      y: endDateString == nil ? clockStartHeight + (clockWidth / 4) + (hourMarkerLineWidth / 2) : clockStartHeight + (clockWidth / 3) + (hourMarkerLineWidth / 2))

            // Indicates if the start hour of the cheapest hours are within the am time or pm time
//            Text(timeIsAM ? "am" : "pm")
//                .font(.title2)
//                .bold()
//                .foregroundColor(colorScheme == .light ? Color.black : Color.white)
//                .position(x: clockRightSideStartWidth + clockWidth / 2, y: clockStartHeight + (3 * clockWidth / 4) - (hourMarkerLineWidth / 2))

            // The minute indicator which indicates which minute currently is
            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(x: currentMinuteXCoord, y: currentMinuteYCoord))
            }
            .strokedPath(.init(lineWidth: 5, lineCap: .round))
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)

            // The hour indicator which indicates which hour currently is
            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(x: currentHourXCoord, y: currentHourYCoord))
            }
            .strokedPath(.init(lineWidth: 5, lineCap: .round))
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
        }
    }
}

struct ConsumptionClockView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionClockView(CheapestHourManager.HourPair(associatedPricePoints: [EnergyPricePoint(startTimestamp: 1603184400, endTimestamp: 1603189800, marketprice: 3)]))
            .preferredColorScheme(.dark)
            .padding(20)
    }
}
