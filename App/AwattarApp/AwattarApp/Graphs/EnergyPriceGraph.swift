//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

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
        let barPadding: CGFloat = 3
        let dividerLineWidth: CGFloat = 3
        
        var path = Path()
        
        if lookToSide == .left {
            path.move(to: CGPoint(x: startWidth - (dividerLineWidth / 2), y: startHeight + barPadding))
            path.addLine(to: CGPoint(x: startWidth - (dividerLineWidth / 2), y: startHeight + heightOfBar - barPadding))
            path.addRelativeArc(center: CGPoint(x: widthOfBar + radius, y: startHeight + heightOfBar - radius - barPadding), radius: radius, startAngle: .degrees(90), delta: .degrees(90))
            path.addRelativeArc(center: CGPoint(x: widthOfBar + radius, y: startHeight + barPadding + radius), radius: radius, startAngle: .degrees(180), delta: .degrees(90))
        } else if lookToSide == .right {
            path.move(to: CGPoint(x: startWidth + (dividerLineWidth / 2), y: startHeight + barPadding))
//            path.addLine(to: CGPoint(x: widthOfBar - radius, y: startHeight + barPadding))
//            path = path.strokedPath(StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            path.addRelativeArc(center: CGPoint(x: widthOfBar - radius, y: startHeight + barPadding + radius), radius: radius, startAngle: .degrees(270), delta: .degrees(180))
            path.addLine(to: CGPoint(x: widthOfBar, y: startHeight + barPadding + radius))
            path.addRelativeArc(center: CGPoint(x: widthOfBar - radius, y: startHeight + heightOfBar - barPadding - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
            path.addLine(to: CGPoint(x: startWidth + (dividerLineWidth / 2), y: startHeight + heightOfBar - barPadding))
        }

        return path
    }
}

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

struct AnimatableCustomFontModifier: AnimatableModifier {
    var size: CGFloat
    
    var animatableData: CGFloat {
        get { size }
        set { size = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
    }
}

extension View {
    func animatableFont(size: CGFloat) -> some View {
        self.modifier(AnimatableCustomFontModifier(size: size))
    }

}

struct EnergyPriceSingleBar: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var currentSetting: CurrentSetting

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
        self.startHeight = startHeight

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
        } else if isSelected == 2 {
            self.height = height + 5
            self.startHeight += startHeight - 2.5
        } else {
            self.height = height
            self.startHeight += startHeight
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
            maximalNegativePriceBarWidth == 0 ? 0 : 3
        )
        
        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .center)) {
            if hourDataPoint.marketprice > 0 {
                BarShape(isSelected: (isSelected == 1 ? true : false), startWidth: maximalNegativePriceBarWidth, startHeight: startHeight, widthOfBar: positivePriceBarWidth + currentDividerLineWidth, heightOfBar: height, lookToSide: .right)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color(hue: 0.0849, saturation: 0.6797, brightness: 0.9059), Color(hue: 0.9978, saturation: 0.7163, brightness: 0.8431)]), startPoint: .leading, endPoint: .trailing))
            } else if hourDataPoint.marketprice < 0 {
                BarShape(isSelected: (isSelected == 1 ? true : false), startWidth: maximalNegativePriceBarWidth, startHeight: startHeight, widthOfBar: maximalNegativePriceBarWidth - negativePriceBarWidth, heightOfBar: height, lookToSide: .left)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.green, Color.gray]), startPoint: .leading, endPoint: .trailing))
            }

            if maximalNegativePriceBarWidth != 0 {
                VerticalDividerLineShape(width: currentDividerLineWidth, height: height, startWidth: maximalNegativePriceBarWidth, startHeight: startHeight)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            }

            VStack {
                if currentSetting.setting!.pricesWithTaxIncluded {
                    // With tax
                    Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001 * 1.16)))!)
                        .fontWeight((isSelected == 1) ? .bold : ((isSelected == 2 ) ? .medium : .regular))
                } else if !currentSetting.setting!.pricesWithTaxIncluded {
                    // Without tax
                    Text(singleBarSettings.centFormatter.string(from: NSNumber(value: (hourDataPoint.marketprice * 100 * 0.001)))!)
                        .fontWeight((isSelected == 1) ? .bold : ((isSelected == 2 ) ? .medium : .regular))
                }
            }
            .foregroundColor(Color.black)
            .padding(1)
            .background(Color.white)
            .cornerRadius((isSelected == 1 || isSelected == 2) ? 3 : 1)
            .animatableFont(size: ((isSelected == 1) ? 17 : ((isSelected == 2) ? 9 : 7)))
            .position(x: ((isSelected == 1) ? maximalNegativePriceBarWidth + 16 + 22 : ((isSelected == 2) ? maximalNegativePriceBarWidth + 16 + 8 : maximalNegativePriceBarWidth + 16 + 3)), y: startHeight + (height / 2)) // 16 is padding

            HStack(spacing: 5) {
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.startTimestamp))))
                Text("-")
                Text(singleBarSettings.hourFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(hourDataPoint.endTimestamp))))
            }
            .animatableFont(size: ((isSelected == 1) ? 20 : ((isSelected == 2) ? 13 : 10)))
            .foregroundColor(Color.black)
            .padding(1)
            .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hue: 0.6111, saturation: 0.0276, brightness: 0.8510)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(4)
            .shadow(radius: 2)
            .position(x: ((isSelected == 1 || isSelected == 2) ? width - 20 - 16 : width - 10 - 16), y: startHeight + (height / 2))
        }
    }
}

class SingleBarSettings {
    var centFormatter: NumberFormatter
    var hourFormatter: DateFormatter
    
    var minPrice: Float = 0
    var maxPrice: Float = 0
        
    init() {
        centFormatter = NumberFormatter()
        centFormatter.numberStyle = .currency
        centFormatter.locale = Locale(identifier: "de_DE")
        centFormatter.currencySymbol = "ct"
        centFormatter.maximumFractionDigits = 2
        centFormatter.minimumFractionDigits = 2
        
        hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "H"
    }
}

struct EnergyPriceGraph: View {
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var graphHourPointData = [(EnergyPricePoint, CGFloat)]()

    @State var currentPointerIndexSelected: Int? = nil
    
    @State var pointerHeightDeltaToBefore: CGFloat? = nil
    @State var singleHeight: CGFloat = 0
    
    var singleBarSettings = SingleBarSettings()
    
    var body: some View {
        GeometryReader { geometry in
            makeView(geometry)
                .onAppear {
                    singleHeight = geometry.size.height / CGFloat(awattarData.energyData!.prices.count)

                    graphHourPointData = []
                    
                    var currentHeight: CGFloat = 0
                    for hourPointEntry in awattarData.energyData!.prices {
                        graphHourPointData.append((hourPointEntry, currentHeight))
                        currentHeight += singleHeight
                    }

                    singleBarSettings.minPrice = awattarData.energyData!.minPrice
                    singleBarSettings.maxPrice = awattarData.energyData!.maxPrice
                }
        }
    }
    
    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width

        let graphDragGesture = DragGesture(minimumDistance: 0)
            .onChanged { location in
                let locationHeight = location.location.y
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentPointerIndexSelected = Int(((locationHeight / singleHeight) - 1).rounded(.up))
                }
            }
            .onEnded {_ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentPointerIndexSelected = nil
                }
            }
        
        return ZStack {
            ForEach(0..<graphHourPointData.count, id: \.self) { hourPointIndex in
                EnergyPriceSingleBar(
                    singleBarSettings: singleBarSettings,
                    width: width,
                    height: singleHeight,
                    startHeight: graphHourPointData[hourPointIndex].1,
                    indexSelected: currentPointerIndexSelected,
                    ownIndex: hourPointIndex,
                    hourDataPoint: graphHourPointData[hourPointIndex].0)
            }
            
//            Path { path in
//                path.move(to: CGPoint(x: 10, y: 18.20949285))
//                path.addLine(to: CGPoint(x: 10, y: 18.20949285))
//            }
//            .strokedPath(StrokeStyle(lineWidth: 5, lineCap: .round))
//            .foregroundColor(Color.red)
        }
        .gesture(graphDragGesture)
    }
}

struct EnergyPriceGraph_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            
        }
    }
}
