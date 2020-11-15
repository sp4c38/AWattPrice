//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

struct GraphHeader: View {
    var justNowUpdatedData: Bool?
    
    var body: some View {
        VStack {
            if justNowUpdatedData == true {
                UpdatedDataView()
                    .padding(.top, 12)
                    .padding(.bottom, 3)
            }
            
            HStack {
                Text("centPerKwh")
                    .font(.subheadline)

                Spacer()

                Text("hourOfDay")
                    .font(.subheadline)
            }
            .padding([.leading, .trailing], 16)
            .padding(.top, 8)
            .padding(.bottom, 5)
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
        .ignoresSafeArea(.keyboard) // Ignore the keyboard. Without this the graph was been squeezed together when opening the keyboard somewhere in the app
        .contentShape(Rectangle())
        .gesture(graphDragGesture)
    }
}
