//
//  ConsumptionClockView.swift
//  AwattarApp
//
//  Created by Léon Becker on 25.09.20.
//

import SwiftUI

struct ConsumptionClockView: View {
    @State var currentLevel = 0
    
    var hourDegree = (0, 0)
    
    init(cheapestHour: CheapestHourCalculator.HourPair) {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")

        // 15 degrees is the angle for one single hour

        let minItemIndex = 0
        let maxItemIndex = cheapestHour.associatedPricePoints.count - 1
        
        if cheapestHour.associatedPricePoints.count >= 2 {
            let startDegree = (30 * calendar.component(.hour, from: Date(timeIntervalSince1970: TimeInterval(cheapestHour.associatedPricePoints[minItemIndex].startTimestamp / 1000)))) - 90
            let endDegree = (30 * calendar.component(.hour, from: Date(timeIntervalSince1970: TimeInterval(cheapestHour.associatedPricePoints[maxItemIndex].endTimestamp / 1000)))) - 90
            
            // Subtract 90 degrees because actual 0 degree is at 90th degree
            
            hourDegree = (startDegree, endDegree)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.makeView(geometry)
        }
    }
    
    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        let clockWidth = 4 * (width / 5)
        let clockLeftSideStartWidth = ((width + clockWidth) / 2)
        let clockRightSideStartWidth = ((width - clockWidth) / 2)
        let clockStartHeight = (height / 2) - (width / 2) + clockRightSideStartWidth
        
        let threeHourIndicatorWidth = CGFloat(20)
        let threeHourIndicatorHeight = CGFloat(8)
        let threeHourIndicatorRadius = CGFloat(5)

        let circleLineWidth = CGFloat(5)

        let middlePointRadius = CGFloat(5)
        
        let hourMarkerRadius = CGFloat(0.6 * (((clockWidth / 2) - circleLineWidth)))

        let center = CGPoint(x: width / 2, y: height / 2)
        
        var hourNamesAndPositions = [(String, CGFloat, CGFloat)]()
        var currentHorizontalLevel: CGFloat = 4
        var currentVerticalLevel: CGFloat = 1
        
        for hourName in 1...12 {
            var horizontalPadding: CGFloat = 0
            var verticalPadding: CGFloat = 0
            
            if [3, 9].contains(hourName) {
                horizontalPadding = ((hourName == 9) ? 40 : -40)
            } else if [12, 6].contains(hourName) {
                verticalPadding = ((hourName == 12) ? 40 : -40)
            }
            
            let currentHeight = currentVerticalLevel * (clockWidth / 6) + clockStartHeight + verticalPadding
            let currentWidth = currentHorizontalLevel * (clockWidth / 6) + horizontalPadding + clockRightSideStartWidth
            
            hourNamesAndPositions.append((String(hourName), currentWidth, currentHeight))
            
            if hourName == 6 {
                currentVerticalLevel = 5
            } else if hourName < 6 {
                currentVerticalLevel += 1
            } else if hourName > 6 {
                currentVerticalLevel -= 1
            }
            
            if hourName == 3 {
                currentHorizontalLevel = 5
            } else if hourName > 3 && hourName < 9 {
                currentHorizontalLevel -= 1
            } else if hourName == 9 {
                currentHorizontalLevel = 1
            } else if hourName < 3 || hourName > 9 {
                currentHorizontalLevel += 1
            }
        }
        
        return ZStack {
            Path { path in
                path.addArc(center: center, radius: (clockWidth / 2) - circleLineWidth, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                path.addArc(center: center, radius: clockWidth / 2, startAngle: .degrees(360), endAngle: .degrees(0), clockwise: true)
            }
            .foregroundColor(Color.black)
        
            Path { path in
                path.move(to: CGPoint(x: clockRightSideStartWidth + circleLineWidth, y: (height / 2) - (threeHourIndicatorHeight / 2)))

                path.addRelativeArc(center: CGPoint(x: clockRightSideStartWidth + threeHourIndicatorWidth - threeHourIndicatorRadius + circleLineWidth, y: (height / 2) - (threeHourIndicatorHeight / 2) + threeHourIndicatorRadius), radius: threeHourIndicatorRadius, startAngle: .degrees(-90), delta: .degrees(90))

                path.addRelativeArc(center: CGPoint(x: clockRightSideStartWidth + threeHourIndicatorWidth - threeHourIndicatorRadius + circleLineWidth, y: (height / 2) + (threeHourIndicatorHeight / 2) - threeHourIndicatorRadius), radius: threeHourIndicatorRadius, startAngle: .degrees(0), delta: .degrees(90))

                path.addLine(to: CGPoint(x: clockRightSideStartWidth + circleLineWidth, y: (height / 2) + (threeHourIndicatorHeight / 2)))
            }
            .fill(Color.black)

            Path { path in
                path.move(to: CGPoint(x: clockLeftSideStartWidth - circleLineWidth, y: (height / 2) - (threeHourIndicatorHeight / 2)))

                path.addRelativeArc(center: CGPoint(x: clockLeftSideStartWidth - threeHourIndicatorWidth + threeHourIndicatorRadius - circleLineWidth, y: (height / 2) - (threeHourIndicatorHeight / 2) + threeHourIndicatorRadius), radius: threeHourIndicatorRadius, startAngle: .degrees(-90), delta: .degrees(-90))

                path.addRelativeArc(center: CGPoint(x: clockLeftSideStartWidth - threeHourIndicatorWidth + threeHourIndicatorRadius - circleLineWidth, y: (height / 2) + (threeHourIndicatorHeight / 2) - threeHourIndicatorRadius), radius: threeHourIndicatorRadius, startAngle: .degrees(180), delta: .degrees(-90))

                path.addLine(to: CGPoint(x: clockLeftSideStartWidth - circleLineWidth, y: (height / 2) + (threeHourIndicatorHeight / 2)))
            }
            .fill(Color.black)

            Path { path in
                path.move(to: CGPoint(x: (width / 2) - (threeHourIndicatorHeight / 2), y: clockStartHeight + circleLineWidth))

                path.addRelativeArc(center: CGPoint(x: (width / 2) - (threeHourIndicatorHeight / 2) + threeHourIndicatorRadius, y: clockStartHeight + threeHourIndicatorWidth - threeHourIndicatorRadius + circleLineWidth), radius: threeHourIndicatorRadius, startAngle: .degrees(180), delta: .degrees(-90))

                path.addRelativeArc(center: CGPoint(x: (width / 2) + (threeHourIndicatorHeight / 2) - threeHourIndicatorRadius, y: clockStartHeight + threeHourIndicatorWidth - threeHourIndicatorRadius + circleLineWidth), radius: threeHourIndicatorRadius, startAngle: .degrees(90), delta: .degrees(-90))

                path.addLine(to: CGPoint(x: (width / 2) + (threeHourIndicatorHeight / 2), y: clockStartHeight + circleLineWidth))
            }
            .fill(Color.black)

            Path { path in
                path.move(to: CGPoint(x: (width / 2) - (threeHourIndicatorHeight / 2), y: clockStartHeight + clockWidth - circleLineWidth))

                path.addRelativeArc(center: CGPoint(x: (width / 2) - (threeHourIndicatorHeight / 2) + threeHourIndicatorRadius, y: clockStartHeight + clockWidth - threeHourIndicatorWidth + threeHourIndicatorRadius - circleLineWidth), radius: threeHourIndicatorRadius, startAngle: .degrees(180), delta: .degrees(90))

                path.addRelativeArc(center: CGPoint(x: (width / 2) + (threeHourIndicatorHeight / 2) - threeHourIndicatorRadius, y: clockStartHeight + clockWidth - threeHourIndicatorWidth + threeHourIndicatorRadius - circleLineWidth), radius: threeHourIndicatorRadius, startAngle: .degrees(270), delta: .degrees(90))

                path.addLine(to: CGPoint(x: (width / 2) + (threeHourIndicatorHeight / 2), y: clockStartHeight + clockWidth - circleLineWidth))
            }
            .fill(Color.black)

            Path { path in
                path.addArc(center: center, radius: middlePointRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
            }
            .fill(Color.black)

            Path { path in
                path.addArc(center: center, radius: hourMarkerRadius, startAngle: .degrees(Double(hourDegree.0)), endAngle: .degrees(Double(hourDegree.1)), clockwise: false)
            }
            .strokedPath(.init(lineWidth: circleLineWidth, lineCap: .round))
            .foregroundColor(Color.green)
            
            ForEach(hourNamesAndPositions, id: \.0) { hour in
                Text(hour.0)
                    .position(x: hour.1, y: hour.2)
            }
        }
    }
}

struct ConsumptionClockView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionClockView(cheapestHour: CheapestHourCalculator.HourPair(associatedPricePoints: [EnergyPricePoint(startTimestamp: 1601082000, endTimestamp: 1601085600, marketprice: 3, unit: ["Eur / MWh", "Eur / kWh"]), EnergyPricePoint(startTimestamp: 1601085600, endTimestamp: 1601089200, marketprice: 9, unit: ["Eur / MWh", "Eur / kWh"]), EnergyPricePoint(startTimestamp: 1601089200, endTimestamp: 1601092800, marketprice: 4, unit: ["Eur / MWh", "Eur / kWh"])]))
    }
}
