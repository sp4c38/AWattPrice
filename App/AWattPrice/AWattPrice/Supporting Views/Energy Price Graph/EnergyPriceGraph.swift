//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import CoreHaptics
import SwiftUI

struct GraphHeader: View {
    var body: some View {
        HStack {
            Text("centPerKwh")

            Spacer()

            Text("hourOfDay")
        }
        .font(.subheadline)
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
    @State var hapticEngine: CHHapticEngine? = nil
    @State var currentPointerIndexSelected: Int? = nil
    @State var singleHeight: CGFloat = 0
    @State var singleBarSettings: SingleBarSettings? = nil
    
    func setGraphValues(geometry: GeometryProxy) {
        self.singleBarSettings = SingleBarSettings(minPrice: awattarData.energyData!.minPrice, maxPrice: awattarData.energyData!.maxPrice)

        self.singleHeight = geometry.size.height / CGFloat(awattarData.energyData!.prices.count)

        self.graphHourPointData = []

        var currentHeight: CGFloat = 0
        for hourPointEntry in awattarData.energyData!.prices {
            graphHourPointData.append((hourPointEntry, currentHeight))
            currentHeight += singleHeight
        }
    }
    
    func initCHEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            self.hapticEngine = try CHHapticEngine()
            do {
                try hapticEngine?.start()
            } catch {
                self.hapticEngine = nil
            }
        } catch {
            print("There was an error initiating the engine: \(error)")
        }
    }
    
    func shortTapHaptic() {
        guard (self.hapticEngine != nil) else { return }
    
        var hapticEvents = [CHHapticEvent]()
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let hapticEvent = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        hapticEvents.append(hapticEvent)
        
        do {
            let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
            let player = try hapticEngine!.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    var body: some View {
        // The drag gesture responsible for making the graph interactive.
        // It gets active when the user presses anywhere on the graph.
        // After that the gesture calculates the bar which the user pressed on. This bar and its
        // associated text is than resized to be larger. This is used to display many
        // bars on one screen and still ensure that they can be easily recognized

        let graphDragGesture = DragGesture(minimumDistance: 0)
            .onChanged { location in
                let locationHeight = location.location.y
                
                let newPointerIndexSelected = Int(((locationHeight / singleHeight) - 1).rounded(.up))
                
                if newPointerIndexSelected != currentPointerIndexSelected {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPointerIndexSelected = newPointerIndexSelected
                    }
                    shortTapHaptic()
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
                            maxIndex: graphHourPointData.count - 1,
                            hourDataPoint: graphHourPointData[hourPointIndex].0)
                    }
                }
            }
            .drawingGroup()
            .onAppear {
                setGraphValues(geometry: geometry)
                initCHEngine()
            }
            .onReceive(awattarData.$energyData) { newEnergyData in
                setGraphValues(geometry: geometry)
            }
        }
        .ignoresSafeArea(.keyboard) // Ignore the keyboard. Without this the graph was been squeezed together when opening the keyboard somewhere in the app
        .contentShape(Rectangle())
        .gesture(graphDragGesture)
    }
}
