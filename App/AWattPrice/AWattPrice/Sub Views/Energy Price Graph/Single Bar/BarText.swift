//
//  HourOfDayText.swift
//  AWattPrice
//
//  Created by Léon Becker on 27.12.20.
//

import SwiftUI

struct HourOfDayText: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var currentSetting: CurrentSetting
    
    static func getPriceString(marketprice: Double, currentSetting: CurrentSetting) -> String {
        let centFormatter = NumberFormatter()
        centFormatter.numberStyle = .currency
        centFormatter.currencySymbol = "ct"
        centFormatter.maximumFractionDigits = 2
        centFormatter.minimumFractionDigits = 2
        
        if currentSetting.entity!.pricesWithTaxIncluded {
            return centFormatter.string(from: NSNumber(value: marketprice * currentSetting.currentVATToUse)) ?? "NaN"
        } else {
            return centFormatter.string(from: NSNumber(value: marketprice)) ?? "NaN"
        }
    }
    
    let singleBarSettings: SingleBarSettings
    let hourDataPoint: EnergyPricePoint
    
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    
    let isSelected: Int16
    
    let totalWidth: CGFloat
    let startWidthPadding: CGFloat
    let height: CGFloat
    let startHeight: CGFloat
    
    var body: some View {
        ZStack {
            Text(HourOfDayText.getPriceString(marketprice: hourDataPoint.marketprice, currentSetting: currentSetting))
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            .animatableFont(size: fontSize + 1, weight: fontWeight)
            .padding(1)
                .padding([.leading, .trailing], (isSelected == 1 || isSelected == 2) ? 2 : 1)
                .background(
                    RoundedRectangle(cornerRadius: (isSelected == 1 || isSelected == 2) ? 3 : 2)
                        .fill(colorScheme == .light ? Color(red: 0.92, green: 0.91, blue: 0.93) : Color(red: 0.21, green: 0.21, blue: 0.21))
                        .cornerRadius((isSelected == 1 || isSelected == 2) ? 3 : 2)
                        .opacity(0.8)
                )
            .position(x: ((isSelected == 1 || isSelected == 2) ? startWidthPadding + 30 + fontSize : startWidthPadding + fontSize + 20), y: startHeight + (height / 2))
            
            HStack(spacing: 5) {
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.startTimestamp))))
                Text("-")
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.endTimestamp))))
            }
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            .animatableFont(size: fontSize + 2, weight: fontWeight)
            .padding(1)
            .padding([.leading, .trailing], (isSelected == 1 || isSelected == 2) ? 2 : 1)
            .background(
                RoundedRectangle(cornerRadius: (isSelected == 1 || isSelected == 2) ? 3 : 2)
                    .fill(colorScheme == .light ? Color(red: 0.92, green: 0.91, blue: 0.93) : Color(red: 0.21, green: 0.21, blue: 0.21))
                    .cornerRadius((isSelected == 1 || isSelected == 2) ? 3 : 2)
                    .opacity(0.8)        )
            .position(x: ((isSelected == 1 || isSelected == 2) ? totalWidth - 20 - fontSize : totalWidth - 20), y: startHeight + (height / 2))
        }
    }
}
