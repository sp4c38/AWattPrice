//
//  ConsumptionClockView.swift
//  AwattarApp
//
//  Created by Léon Becker on 25.09.20.
//

import SwiftUI

struct ConsumptionClockView: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            let threeHourIndicatorWidth = CGFloat(40)
            let threeHourIndicatorHeight = CGFloat(8)
            let threeHourIndicatorRadius = CGFloat(5)
            
            let circleLineWidth = CGFloat(5)
            
            let middlePointRadius = CGFloat(5)
            
            let center = CGPoint(x: width / 2, y: height / 2)
            
            
            Path { path in
                path.addArc(center: center, radius: (width / 2) - circleLineWidth, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                path.addArc(center: center, radius: width / 2, startAngle: .degrees(360), endAngle: .degrees(0), clockwise: true)
            }
            .foregroundColor(Color.black)
            
            Path { path in
                path.move(to: CGPoint(x: circleLineWidth, y: (height / 2) - (threeHourIndicatorHeight / 2)))
                
                path.addRelativeArc(center: CGPoint(x: threeHourIndicatorWidth - threeHourIndicatorRadius + circleLineWidth, y: (height / 2) - (threeHourIndicatorHeight / 2) + threeHourIndicatorRadius), radius: threeHourIndicatorRadius, startAngle: .degrees(-90), delta: .degrees(90))
                
                path.addRelativeArc(center: CGPoint(x: threeHourIndicatorWidth - threeHourIndicatorRadius + circleLineWidth, y: (height / 2) + (threeHourIndicatorHeight / 2) - threeHourIndicatorRadius), radius: threeHourIndicatorRadius, startAngle: .degrees(0), delta: .degrees(90))
                
                path.addLine(to: CGPoint(x: circleLineWidth, y: (height / 2) + (threeHourIndicatorHeight / 2)))
            }
            .fill(Color.black)
            
            Path { path in
                path.move(to: CGPoint(x: width - circleLineWidth, y: (height / 2) - (threeHourIndicatorHeight / 2)))
                
                path.addRelativeArc(center: CGPoint(x: width - threeHourIndicatorWidth + threeHourIndicatorRadius - circleLineWidth, y: (height / 2) - (threeHourIndicatorHeight / 2) + threeHourIndicatorRadius), radius: threeHourIndicatorRadius, startAngle: .degrees(-90), delta: .degrees(-90))
                
                path.addRelativeArc(center: CGPoint(x: width - threeHourIndicatorWidth + threeHourIndicatorRadius - circleLineWidth, y: (height / 2) + (threeHourIndicatorHeight / 2) - threeHourIndicatorRadius), radius: threeHourIndicatorRadius, startAngle: .degrees(180), delta: .degrees(-90))
                
                path.addLine(to: CGPoint(x: width - circleLineWidth, y: (height / 2) + (threeHourIndicatorHeight / 2)))
            }
            .fill(Color.black)
            
            Path { path in
                path.move(to: CGPoint(x: (width / 2) - (threeHourIndicatorHeight / 2), y: (height / 2) - (width / 2) + circleLineWidth))

                path.addRelativeArc(center: CGPoint(x: (width / 2) - (threeHourIndicatorHeight / 2) + threeHourIndicatorRadius, y: (height / 2) - (width / 2) + threeHourIndicatorWidth - threeHourIndicatorRadius + circleLineWidth), radius: threeHourIndicatorRadius, startAngle: .degrees(180), delta: .degrees(-90))

                path.addRelativeArc(center: CGPoint(x: (width / 2) + (threeHourIndicatorHeight / 2) - threeHourIndicatorRadius, y: (height / 2) - (width / 2) + threeHourIndicatorWidth - threeHourIndicatorRadius + circleLineWidth), radius: threeHourIndicatorRadius, startAngle: .degrees(90), delta: .degrees(-90))

                path.addLine(to: CGPoint(x: (width / 2) + (threeHourIndicatorHeight / 2), y: (height / 2) - (width / 2) + circleLineWidth))
            }
            .fill(Color.black)
//
            Path { path in
                path.move(to: CGPoint(x: (width / 2) - (threeHourIndicatorHeight / 2), y: (height / 2) + (width / 2) - circleLineWidth))

                path.addRelativeArc(center: CGPoint(x: (width / 2) - (threeHourIndicatorHeight / 2) + threeHourIndicatorRadius, y: (height / 2) + (width / 2) - threeHourIndicatorWidth + threeHourIndicatorRadius - circleLineWidth), radius: threeHourIndicatorRadius, startAngle: .degrees(180), delta: .degrees(90))

                path.addRelativeArc(center: CGPoint(x: (width / 2) + (threeHourIndicatorHeight / 2) - threeHourIndicatorRadius, y: (height / 2) + (width / 2) - threeHourIndicatorWidth + threeHourIndicatorRadius - circleLineWidth), radius: threeHourIndicatorRadius, startAngle: .degrees(270), delta: .degrees(90))

                path.addLine(to: CGPoint(x: (width / 2) + (threeHourIndicatorHeight / 2), y: (height / 2) + (width / 2) - circleLineWidth))
            }
            .fill(Color.black)
            
            Path { path in
                path.addArc(center: center, radius: middlePointRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
            }
            .fill(Color.black)
        }
        .frame(maxWidth: 300)
    }
}

struct ConsumptionClockView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionClockView()
    }
}
