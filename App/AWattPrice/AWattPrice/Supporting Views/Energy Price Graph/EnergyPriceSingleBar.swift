//
//  EnergyPriceSingleBar.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

/**
 A single bar with a certain length (representing the energy cost for this hour relative to other hours) and text which again shows the energy cost for this hour but helps to also show the energy price information in more legible and more accurate form.
 */
struct EnergyPriceSingleBar: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var currentSetting: CurrentSetting

    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let singleBarSettings: SingleBarSettings
    let width: CGFloat
    let startWidthPadding: CGFloat // Padding to the left side
    var height: CGFloat
    var startHeight: CGFloat
    let isSelected: Int16 // 0 if not selected and 1 if main selected and 2 if co-selected (bars around the selected bar)
    let hourDataPoint: EnergyPricePoint

    init(singleBarSettings: SingleBarSettings,
         width: CGFloat,
         height: CGFloat,
         startHeight: CGFloat,
         indexSelected: Int?,
         ownIndex: Int,
         maxIndex: Int,
         hourDataPoint: EnergyPricePoint) {
        
        self.singleBarSettings = singleBarSettings
        
        if singleBarSettings.minPrice != 0 {
            self.startWidthPadding = 8 // Set padding to the left side
            self.width = width - 16 // Set padding to the right side
        } else {
            self.startWidthPadding = 3
            self.width = width - 19
        }
        
        let barSpacingWhenSelected = 40 / Double(maxIndex - 2)
        self.height = height
        
        self.startHeight = 0
        if indexSelected != nil {
            if indexSelected == ownIndex {
                self.isSelected = 1
            } else if ownIndex == indexSelected! - 1 || ownIndex == indexSelected! + 1 {
                self.isSelected = 2
            } else {
                self.isSelected = 0
            }
            
            if isSelected == 0 {
                self.height -= CGFloat(barSpacingWhenSelected)
                
                if ownIndex > indexSelected! {
                    self.startHeight += CGFloat(barSpacingWhenSelected * Double(maxIndex - (ownIndex - 1)))
                } else if ownIndex < indexSelected! {
                    self.startHeight -= CGFloat(Double(ownIndex) * barSpacingWhenSelected)
                }
            }
            
            if isSelected == 1 {
                self.startHeight += 10
                self.startHeight -= CGFloat(Double(ownIndex - 1) * barSpacingWhenSelected)
            }
            
            if isSelected == 2 {
                if ownIndex > indexSelected! {
                    self.startHeight += 30
                    self.startHeight -= CGFloat(Double(ownIndex - 2) * barSpacingWhenSelected)
                } else {
                    self.startHeight -= CGFloat(Double(ownIndex) * barSpacingWhenSelected)
                }
            }
        } else {
            self.isSelected = 0
        }

        if isSelected == 1 {
            self.height += 20
            self.startHeight += startHeight
            
            fontSize = 17
            fontWeight = .bold
        } else if isSelected == 2 {
            self.height += 10
            self.startHeight += startHeight
            
            fontSize = 9
            fontWeight = .semibold
        } else {
            self.startHeight += startHeight
            fontSize = 7
            fontWeight = .regular
        }
        
        self.hourDataPoint = hourDataPoint
    }

    var body: some View {
        let maximalNegativePriceBarWidth = (
            singleBarSettings.minPrice == 0
                ? startWidthPadding : CGFloat(abs(singleBarSettings.minPrice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width + startWidthPadding)

        let negativePriceBarWidth = (
            singleBarSettings.minPrice != 0
                ? CGFloat(abs(hourDataPoint.marketprice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width : 0)

        let positivePriceBarWidth = (
            singleBarSettings.maxPrice != 0
                ? CGFloat(abs(hourDataPoint.marketprice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width + maximalNegativePriceBarWidth : 0)

        let currentDividerLineWidth: CGFloat = (
            maximalNegativePriceBarWidth == 0 ? 0 : 1
        )

        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .center)) {
            // Draw the bar shape
            if hourDataPoint.marketprice > 0 {
                BarShape(isSelected: (isSelected == 1 ? true : false), startWidth: maximalNegativePriceBarWidth, startHeight: startHeight, widthOfBar: positivePriceBarWidth + currentDividerLineWidth, heightOfBar: height, lookToSide: .right)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059), Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)]), startPoint: .leading, endPoint: .trailing))
            } else if hourDataPoint.marketprice < 0 {
                BarShape(isSelected: (isSelected == 1 ? true : false), startWidth: maximalNegativePriceBarWidth, startHeight: startHeight, widthOfBar: maximalNegativePriceBarWidth - negativePriceBarWidth, heightOfBar: height, lookToSide: .left)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.green, Color.gray]), startPoint: .leading, endPoint: .trailing))
            }

            // If there are negative energy price values a vergtical divider line shape is displayed to mark the point where costs go from positive values to negative values
            if maximalNegativePriceBarWidth - startWidthPadding != 0 {
                VerticalDividerLineShape(width: currentDividerLineWidth, height: height, startWidth: maximalNegativePriceBarWidth, startHeight: startHeight)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            }

            // Show the energy price as text with or without VAT/tax included
            Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * (currentSetting.setting!.pricesWithTaxIncluded ? 1.16 : 1))))!)
            .foregroundColor(Color.black)
            .animatableFont(size: fontSize, weight: fontWeight)
            .padding(1)
            .background(Color.white)
            .cornerRadius((isSelected == 1 || isSelected == 2) ? 3 : 1)
            .position(x: ((isSelected == 1 || isSelected == 2) ? maximalNegativePriceBarWidth + startWidthPadding + 25 + fontSize : maximalNegativePriceBarWidth + startWidthPadding + 20), y: startHeight + (height / 2))

            // Show start to end time of the hour in which the certain energy price applies
            HStack(spacing: 5) {
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.startTimestamp))))
                Text("-")
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.endTimestamp))))
            }
            .foregroundColor(Color.black)
            .animatableFont(size: fontSize + 3, weight: fontWeight)
            .padding(1)
            .background(Color.white)
            .cornerRadius((isSelected == 1 || isSelected == 2) ? 3 : 1)
            .position(x: ((isSelected == 1 || isSelected == 2) ? width - 20 - fontSize : width - 20), y: startHeight + (height / 2))
        }
    }
}
