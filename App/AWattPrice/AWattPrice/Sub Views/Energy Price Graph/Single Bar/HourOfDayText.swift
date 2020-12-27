//
//  HourOfDayText.swift
//  AWattPrice
//
//  Created by Léon Becker on 27.12.20.
//

import SwiftUI

struct HourOfDayText: View {
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let isSelected: Bool
    let totalWidth: CGFloat
    let startHeight: CGFloat
    let height: CGFloat
    
    var body: some View {
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
                .border(Color.black, width: 1)
                .fill(Color.clear)
                .background(colorScheme == .light ? Color.white : Color(red: 0.21, green: 0.21, blue: 0.21))
                .cornerRadius((isSelected == 1 || isSelected == 2) ? 3 : 2)
                .opacity(0.8)
        )
        .position(x: ((isSelected == 1 || isSelected == 2) ? totalWidth - 20 - fontSize : totalWidth - 20), y: startHeight + (height / 2))
    }
}
