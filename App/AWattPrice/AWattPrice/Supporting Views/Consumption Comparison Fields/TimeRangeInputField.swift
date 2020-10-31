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
    
    let errorValues: [Int]
    
    @State var inputDateRange: ClosedRange<Date> = Date()...Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
                    
                    DatePicker(selection: $cheapestHourManager.startDate, in: inputDateRange, displayedComponents: [.date, .hourAndMinute], label: {})
                        .labelsHidden()
                }
                .padding(5)
                .padding([.leading, .trailing], 2)
                .background(
                    colorScheme == .light ?
                        Color(hue: 0.6667, saturation: 0.0083, brightness: 0.9412) :
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.1429)
                )
                .cornerRadius(7)
 
                HStack {
                    Text("to")
                        .bold()
                        .font(.callout)
                        .foregroundColor(colorScheme == .light ? Color(hue: 0.0000, saturation: 0.0000, brightness: 0.4314) : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8311))
                    
                    Spacer()
                    
                    DatePicker(selection: $cheapestHourManager.endDate, in: inputDateRange, displayedComponents: [.date, .hourAndMinute], label: {})
                        .labelsHidden()
                }
                .padding(5)
                .padding([.leading, .trailing], 2)
                .background(
                    colorScheme == .light ?
                        Color(hue: 0.6667, saturation: 0.0083, brightness: 0.9412) :
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.1429)
                )
                .cornerRadius(7)
                
                Button(action: {
                    cheapestHourManager.setTimeIntervalThisNight()
                }) {
                    Text("tonight")
                        .bold()
                }
                .buttonStyle(TimeRangeButtonStyle())
            }
            .padding([.leading, .trailing], 3)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            let maxHourIndex = awattarData.energyData!.prices.count - 1

            if awattarData.energyData!.prices.count > 0 {
                let inputDateRangeStartPoint = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[0].startTimestamp + 1))
                cheapestHourManager.endDate = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[maxHourIndex].endTimestamp - 1))
                inputDateRange = inputDateRangeStartPoint...cheapestHourManager.endDate
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
