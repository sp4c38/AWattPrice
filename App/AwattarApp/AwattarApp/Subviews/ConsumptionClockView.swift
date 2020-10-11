//
//  ConsumptionClockView.swift
//  AwattarApp
//
//  Created by Léon Becker on 25.09.20.
//

import SwiftUI

struct ConsumptionClockView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var currentLevel = 0
    @State var now = Date()

//    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let calendar = Calendar.current
    var timeIsAM: Bool = true // Default value will be changed if needed
    var startDateString: (String, String) = ("", "")
    var endDateString: (String, String)? = nil

    var hourDegree = (0, 0)

    init(_ cheapestHourPair: CheapestHourCalculator.HourPair) {
        // 15 degrees is the angle for one single hour
        let minItemIndex = 0
        let maxItemIndex = cheapestHourPair.associatedPricePoints.count - 1

        if cheapestHourPair.associatedPricePoints.count >= 2 {
            let startTimeFirstItem = Date(timeIntervalSince1970: TimeInterval(cheapestHourPair.associatedPricePoints[minItemIndex].startTimestamp))
            let startHour = Float(calendar.component(.hour, from: startTimeFirstItem))
            let startMinute = Float(calendar.component(.minute, from: startTimeFirstItem)) / 60
            
            let endTimeLastItem = Date(timeIntervalSince1970: TimeInterval(cheapestHourPair.associatedPricePoints[maxItemIndex].endTimestamp))
            let endHour = Float(calendar.component(.hour, from: endTimeLastItem))
            let endMinute = Float(calendar.component(.minute, from: endTimeLastItem)) / 60

            let startDegree = Int(30 * (startHour + startMinute)) - 90
            let endDegree = Int(30 * (endHour + endMinute)) - 90

            // Subtract 90 degrees to make it fit with the clock alignment

            hourDegree = (startDegree, endDegree)
            
            if startHour > 12 {
                // Chage to PM if in PM section
                timeIsAM = false
            }
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "dd"
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            
            if calendar.startOfDay(for: startTimeFirstItem) == calendar.startOfDay(for: endTimeLastItem) {
                startDateString = (dayFormatter.string(from: startTimeFirstItem), monthFormatter.string(from: startTimeFirstItem))
            } else {
                startDateString = (dayFormatter.string(from: startTimeFirstItem), monthFormatter.string(from: startTimeFirstItem))
                endDateString = (dayFormatter.string(from: endTimeLastItem), monthFormatter.string(from: endTimeLastItem))
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            self.makeView(geometry)
        }
//        .onReceive(timer) { input in
//            now = Date()
//        }
    }

    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height

        let circleLineWidth = CGFloat(2)
        let hourIndicatorLineWidth = CGFloat(2)
        let middlePointRadius = CGFloat(5)

        let clockWidth = 3 * (width / 4)
        let hourBorderIndicatorWidth = CGFloat(4)
        let hourMarkerRadius = CGFloat(0.85 * ((clockWidth / 2) - circleLineWidth))
        let minuteIndicatorWidth = CGFloat((clockWidth / 2) - hourBorderIndicatorWidth - 10)
        let hourIndicatorWidth = CGFloat((2 * ((clockWidth / 2) / 3)) - hourBorderIndicatorWidth  - 10)

        let hourMarkerLineWidth = CGFloat(0.2 * (clockWidth / 2))

        let clockRightSideStartWidth = ((width - clockWidth) / 2)
        let clockStartHeight = (height / 2) - (width / 2) + clockRightSideStartWidth

        let textPaddingToClock = CGFloat(23)
        let threeTextPaddingToClockAddition = CGFloat(0)

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
        
        print(clockStartHeight)
        
        for hourName in 1...12 {
            // Calculate the x coord and y coord for the text with the currentDegree and the radius of the circle
            let xCoordTextDiff = CGFloat(Double((clockWidth / 2) + textPaddingToClock) * cos(currentDegree * Double.pi / 180))
            let yCoordTextDiff = CGFloat(Double((clockWidth / 2) + textPaddingToClock) * sin(currentDegree * Double.pi / 180))

            // Define the final text coordinates out of the created values
            let textXCoord = clockRightSideStartWidth + (clockWidth / 2) + xCoordTextDiff
            let textYCoord = clockStartHeight + (clockWidth / 2) + yCoordTextDiff

            // Calculate the start and endposition of the lines around the clock representing the hours
            let lineFirstXCoord = CGFloat(Double(clockWidth / 2 + hourBorderIndicatorWidth) * cos(currentDegree * Double.pi / 180)) + clockRightSideStartWidth + (clockWidth / 2)
            let lineFirstYCoord = CGFloat(Double(clockWidth / 2 + hourBorderIndicatorWidth) * sin(currentDegree * Double.pi / 180)) + clockStartHeight + (clockWidth / 2)

            let lineSecondXCoord = CGFloat(Double(clockWidth / 2 - circleLineWidth) * cos(currentDegree * Double.pi / 180)) + clockRightSideStartWidth + (clockWidth / 2)
            let lineSecondYCoord = CGFloat(Double(clockWidth / 2 - circleLineWidth) * sin(currentDegree * Double.pi / 180)) + clockStartHeight + (clockWidth / 2)

            // Add all values the the hourNamesAndPositions array which will later be used to draw the text
            hourNamesAndPositions.append((String(hourName), textXCoord, textYCoord, lineFirstXCoord, lineFirstYCoord, lineSecondXCoord, lineSecondYCoord))

            currentDegree += 30
        }
        
        print(hourNamesAndPositions)
        
        return ZStack {
            Circle()
                .foregroundColor(colorScheme == .light ? Color.white : Color.black)
                .frame(width: width)
                .shadow(color: colorScheme == .light ? Color.black : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.3020), radius: 20)

//            Path { path in
//                path.addArc(center: center, radius: (clockWidth / 2) - circleLineWidth, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
//                path.addArc(center: center, radius: clockWidth / 2, startAngle: .degrees(360), endAngle: .degrees(0), clockwise: true)
//            }
//            .foregroundColor(colorScheme == .light ? Color.black : Color.white)

            Path { path in
                path.addArc(center: center, radius: middlePointRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
            }
            .fill(colorScheme == .light ? Color.black : Color.white)

            Path { path in
                path.addArc(center: center, radius: hourMarkerRadius - (hourMarkerLineWidth / 2), startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

                path.addArc(center: center, radius: hourMarkerRadius + (hourMarkerLineWidth / 2), startAngle: .degrees(360), endAngle: .degrees(0), clockwise: true)
            }
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            .opacity(colorScheme == .light ? 0.1 : 0.3)

            Path { path in
                path.addArc(center: center, radius: hourMarkerRadius, startAngle: .degrees(Double(hourDegree.0 + 3)), endAngle: .degrees(Double(hourDegree.1 - 3)), clockwise: false) // Add 3 and -3 to compensate the indicator lineCap
            }
            .strokedPath(.init(lineWidth: hourMarkerLineWidth, lineCap: .round))
            .foregroundColor(Color(hue: 0.3786, saturation: 0.6959, brightness: 0.8510))

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

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Text(startDateString.0)
                        .bold()
                        .foregroundColor(Color.red)

                    Text(startDateString.1)
                        .foregroundColor(colorScheme == .light ? Color.black : Color.white)
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
            .position(x: clockRightSideStartWidth + clockWidth / 2, y: clockStartHeight + (clockWidth / 3) + (hourMarkerLineWidth / 2))

            Text(timeIsAM ? "am" : "pm")
                .font(.title2)
                .bold()
                .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                .position(x: clockRightSideStartWidth + clockWidth / 2, y: clockStartHeight + (3 * clockWidth / 4) - (hourMarkerLineWidth / 2))

            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(x: currentMinuteXCoord, y: currentMinuteYCoord))
            }
            .strokedPath(.init(lineWidth: 5, lineCap: .round))
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)

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
        ConsumptionClockView(CheapestHourCalculator.HourPair(associatedPricePoints: [EnergyPricePoint(startTimestamp: 1602363600, endTimestamp: 1602367200, marketprice: 3), EnergyPricePoint(startTimestamp: 1602367200, endTimestamp: 1602370800, marketprice: 9)]))
            .preferredColorScheme(.dark)
            .padding(20)
    }
}
