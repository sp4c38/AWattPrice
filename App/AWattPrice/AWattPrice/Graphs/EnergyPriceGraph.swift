//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

/// A single bar with a certain length to represent the energy price relative to all other hours
struct BarShape: Shape {
    let isSelected: Bool
    let startWidth: CGFloat
    var startHeight: CGFloat
    let widthOfBar: CGFloat
    var heightOfBar: CGFloat
    
    enum SidesToLook {
        case right
        case left
    }
    
    let lookToSide: SidesToLook
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { return AnimatablePair(startHeight, heightOfBar) }
        set {
            self.startHeight = newValue.first
            self.heightOfBar = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 2
        let barPadding: CGFloat = 1
        let dividerLineWidth: CGFloat = 3
        
        var path = Path()
        
        if lookToSide == .left {
            path.move(to: CGPoint(x: startWidth - (dividerLineWidth / 2), y: startHeight + barPadding))
            path.addLine(to: CGPoint(x: startWidth - (dividerLineWidth / 2), y: startHeight + heightOfBar - barPadding))
            path.addRelativeArc(center: CGPoint(x: widthOfBar + radius, y: startHeight + heightOfBar - radius - barPadding), radius: radius, startAngle: .degrees(90), delta: .degrees(90))
            path.addRelativeArc(center: CGPoint(x: widthOfBar + radius, y: startHeight + barPadding + radius), radius: radius, startAngle: .degrees(180), delta: .degrees(90))
        } else if lookToSide == .right {
            path.move(to: CGPoint(x: startWidth + (dividerLineWidth / 2), y: startHeight + barPadding))
            path.addRelativeArc(center: CGPoint(x: widthOfBar - radius, y: startHeight + barPadding + radius), radius: radius, startAngle: .degrees(270), delta: .degrees(180))
            path.addLine(to: CGPoint(x: widthOfBar, y: startHeight + barPadding + radius))
            path.addRelativeArc(center: CGPoint(x: widthOfBar - radius, y: startHeight + heightOfBar - barPadding - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
            path.addLine(to: CGPoint(x: startWidth + (dividerLineWidth / 2), y: startHeight + heightOfBar - barPadding))
        }

        return path
    }
}

/// A simple line at a certain coordinate which shows the passage from positive energy prices to negative energy prices. It supports animation when the height  of this line is changed.
struct VerticalDividerLineShape: Shape {
    let width: CGFloat
    var height: CGFloat
    let startWidth: CGFloat
    var startHeight: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(startHeight, height) }
        set {
            startHeight = newValue.first
            height = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: startWidth, y: startHeight))
        path.addLine(to: CGPoint(x: startWidth, y: height + startHeight))
        
        path = path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .square))

        return path
    }
}

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
    let height: CGFloat
    var startHeight: CGFloat
    let isSelected: Int16 // 0 if not selected and 1 if main selected and 2 if co-selected (bars around the selected bar)
    let hourDataPoint: EnergyPricePoint

    init(singleBarSettings: SingleBarSettings,
         width: CGFloat,
         height: CGFloat,
         startHeight: CGFloat,
         indexSelected: Int?,
         ownIndex: Int,
         hourDataPoint: EnergyPricePoint) {
        
        self.singleBarSettings = singleBarSettings
        self.width = width
        
        self.startHeight = 0
        if indexSelected != nil {
            if indexSelected == ownIndex {
                self.isSelected = 1
            } else if ownIndex == indexSelected! - 1 || ownIndex == indexSelected! + 1 {
                self.isSelected = 2
            } else {
                self.isSelected = 0
            }

            if ownIndex > indexSelected! {
                if !(self.isSelected == 2) {
                    self.startHeight += 30
                } else {
                    self.startHeight += 20
                }
            } else if ownIndex < indexSelected! {
                if !(self.isSelected == 2) {
                    self.startHeight -= 30
                } else {
                    self.startHeight -= 20
                }
            }
        } else {
            self.isSelected = 0
        }

        if isSelected == 1 {
            self.height = height + 20
            self.startHeight += startHeight - 10 // Must be half of which was added to height
            
            fontSize = 17
            fontWeight = .bold
        } else if isSelected == 2 {
            self.height = height + 10
            self.startHeight += startHeight - 5
            
            fontSize = 9
            fontWeight = .semibold
        } else {
            self.height = height
            self.startHeight += startHeight
            
            fontSize = 7
            fontWeight = .regular
        }
        
        self.hourDataPoint = hourDataPoint
    }

    var body: some View {
        let maximalNegativePriceBarWidth = (
            singleBarSettings.minPrice == 0
                ? 0 : CGFloat(abs(singleBarSettings.minPrice) / (abs(singleBarSettings.minPrice) + abs(singleBarSettings.maxPrice))) * width)

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
            if maximalNegativePriceBarWidth != 0 {
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
            .position(x: ((isSelected == 1) ? 26 + 22 : ((isSelected == 2) ? 26 + 8 : 26 + 3)), y: startHeight + (height / 2)) // 16 is padding
            .shadow(radius: 2)

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
            .position(x: ((isSelected == 1 || isSelected == 2) ? width - 20 - 16 : width - 10 - 16), y: startHeight + (height / 2))
            .shadow(radius: 2)
        }
    }
}

/// Some single bar settings which is used by each bar
class SingleBarSettings: ObservableObject {
    var centFormatter: NumberFormatter
    var hourFormatter: DateFormatter
    
    var minPrice: Float
    var maxPrice: Float
    
    init(minPrice: Float, maxPrice: Float) {
        centFormatter = NumberFormatter()
        centFormatter.numberStyle = .currency
        centFormatter.locale = Locale(identifier: "de_DE")
        centFormatter.currencySymbol = "ct"
        centFormatter.maximumFractionDigits = 2
        centFormatter.minimumFractionDigits = 2
        
        hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "H"
        
        self.minPrice = minPrice
        self.maxPrice = maxPrice
    }
}

/// The interactive graph drawn on the home screen displaying the price for each hour throughout the day
struct EnergyPriceGraph: View {
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var graphHourPointData = [(EnergyPricePoint, CGFloat)]()
    @State var currentPointerIndexSelected: Int? = nil
    @State var singleHeight: CGFloat = 0
    @State var singleBarSettings: SingleBarSettings? = nil

    var body: some View {
        // The drag gesture responsible for making the graph interactive.
        // It gets active when the user presses anywhere on the graph.
        // After that the gesture calculates the bar which the user pressed on. This bar and its
        // associated text is than resized to be larger. This is used to display many
        // bars on one screen and still ensure that they can be easily recognized

        let graphDragGesture = DragGesture(minimumDistance: 0)
            .onChanged { location in
                let locationHeight = location.location.y
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPointerIndexSelected = Int(((locationHeight / singleHeight) - 1).rounded(.up))
                }
            }
            .onEnded {_ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPointerIndexSelected = nil
                }
            }
        
        GeometryReader { geometry in
            ZStack {
                if singleBarSettings != nil {
                    ForEach(0..<graphHourPointData.count, id: \.self) { hourPointIndex -> EnergyPriceSingleBar in
                        EnergyPriceSingleBar(
                            singleBarSettings: singleBarSettings!,
                            width: geometry.size.width,
                            height: singleHeight,
                            startHeight: graphHourPointData[hourPointIndex].1,
                            indexSelected: currentPointerIndexSelected,
                            ownIndex: hourPointIndex,
                            hourDataPoint: graphHourPointData[hourPointIndex].0)
                    }
                }
            }
            .drawingGroup()
            .onAppear {
                singleBarSettings = SingleBarSettings(minPrice: awattarData.energyData!.minPrice, maxPrice: awattarData.energyData!.maxPrice)

                singleHeight = geometry.size.height / CGFloat(awattarData.energyData!.prices.count)

                graphHourPointData = []

                var currentHeight: CGFloat = 0
                for hourPointEntry in awattarData.energyData!.prices {
                    graphHourPointData.append((hourPointEntry, currentHeight))
                    currentHeight += singleHeight
                }
            }
        }
        .ignoresSafeArea(.keyboard) // Ignore the keyboard. In the past without this this had led the graph to be very squeezed together
        .contentShape(Rectangle())
        .gesture(graphDragGesture)
    }
}
