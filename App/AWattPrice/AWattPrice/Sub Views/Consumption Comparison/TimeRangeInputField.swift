//
//  TimeRangeInputField.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.10.20.
//

import SwiftUI

/// A input field for the time range in the consumption comparison view.
struct TimeRangeInputField: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    @State var inputDateRange: ClosedRange<Date> = Date()...Date()
    @State var setOnlyOnce: Bool = true // Makes sure that the inputDateRange is set only once to default in onAppear
    
    let errorValues: [Int]
    let timeIntervalFormatter: NumberFormatter
    
    init(errorValues: [Int]) {
        self.errorValues = errorValues
        
        timeIntervalFormatter = NumberFormatter()
        timeIntervalFormatter.numberStyle = .decimal
        timeIntervalFormatter.maximumFractionDigits = 2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("timeRange")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("from")
                        .bold()
                        .font(.callout)
                        .foregroundColor(colorScheme == .light ? Color(hue: 0.0000, saturation: 0.0000, brightness: 0.4314) : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8311))
                    
                    Spacer()
                    
                    ComparisonDatePicker(selection: $cheapestHourManager.startDate, in: inputDateRange)
                        .frame(width: 203, height: 40)
                }
                .padding(5)
                .padding([.leading, .trailing], 2)
                .background(
                    colorScheme == .light ?
                        Color(hue: 0.6667, saturation: 0.0083, brightness: 0.9412) :
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.1429)
                )
                .cornerRadius(7)
                .ifTrue(errorValues.contains(5)) { content in
                    content
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.red, lineWidth: 2)
                        )
                }
 
                HStack {
                    Text("to")
                        .bold()
                        .font(.callout)
                        .foregroundColor(colorScheme == .light ? Color(hue: 0.0000, saturation: 0.0000, brightness: 0.4314) : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8311))
                    
                    Spacer()
                    
                    ComparisonDatePicker(selection: $cheapestHourManager.endDate, in: inputDateRange)
                        .frame(width: 203, height: 40)
                }
                .padding(5)
                .padding([.leading, .trailing], 2)
                .background(
                    colorScheme == .light ?
                        Color(hue: 0.6667, saturation: 0.0083, brightness: 0.9412) :
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.1429)
                )
                .cornerRadius(7)
                .ifTrue(errorValues.contains(5)) { content in
                    content
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.red, lineWidth: 2)
                        )
                }
                
                if errorValues.contains(5) {
                    let minTimeRangeNeeded = (cheapestHourManager.timeOfUsage * 100).rounded(.up) / 100
                    
                    Text(String(format: "wrongTimeRangeError".localized(), timeIntervalFormatter.string(from: NSNumber(value: minTimeRangeNeeded))!))
                        .font(.caption)
                        .foregroundColor(Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding([.top, .bottom], 20)
            
            HStack {
                Button(action: {
                    cheapestHourManager.setTimeIntervalThisNight(energyData: awattarData.energyData!)
                }) {
                    Text("tonight")
                        .bold()
                }
                .buttonStyle(TimeRangeButtonStyle())
                
                Button(action: {
                    cheapestHourManager.setTimeInterval(forNextHourAmount: 3, energyData: awattarData.energyData!)
                }) {
                    Text("nextThreeHours")
                        .bold()
                }
                .buttonStyle(TimeRangeButtonStyle())
            }
            .animation(.easeInOut)
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if setOnlyOnce {
                let maxHourIndex = awattarData.energyData!.prices.count - 1

                if awattarData.energyData!.prices.count > 0 {
                    let inputDateRangeStartPoint = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[0].startTimestamp + 1))
                    cheapestHourManager.endDate = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[maxHourIndex].endTimestamp - 1))
                    inputDateRange = inputDateRangeStartPoint...cheapestHourManager.endDate
                }
                setOnlyOnce = false
            }
        }
    }
}

struct TimeRangeInputField_Previews: PreviewProvider {
    static var previews: some View {
        TimeRangeInputField(errorValues: [])
            .environmentObject(CheapestHourManager())
            .padding()
    }
}
