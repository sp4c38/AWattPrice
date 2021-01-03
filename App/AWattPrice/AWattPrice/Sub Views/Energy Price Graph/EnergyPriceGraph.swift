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
            Text("general.centPerKwh")

            Spacer()

            Text("electricityPage.hourOfDay")
        }
        .font(.subheadline)
        .animation(.easeInOut)
    }
}

struct GraphSizePreferenceKey: PreferenceKey {
    struct SizeBounds: Equatable {
        static func == (lhs: GraphSizePreferenceKey.SizeBounds, rhs: GraphSizePreferenceKey.SizeBounds) -> Bool {
            return false
        }
        
        var bounds: Anchor<CGRect>
    }
    
    typealias Value = SizeBounds?
    static var defaultValue: Value = nil
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}

/// Some single bar settings which is used by each bar
class SingleBarSettings: ObservableObject {
    var centFormatter: NumberFormatter
    var hourFormatter: DateFormatter
    
    var minPrice: Double
    var maxPrice: Double
    
    init(minPrice: Double, maxPrice: Double) {
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
    @Environment(\.scenePhase) var scenePhase
    
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var graphHourPointData = [(EnergyPricePoint, CGFloat)]()
    @State var hapticEngine: CHHapticEngine? = nil
    @State var currentPointerIndexSelected: Int? = nil
    @State var singleHeight: CGFloat = 0
    @State var singleBarSettings: SingleBarSettings? = nil
    @State var dateMarkPointIndex: Int? = nil
    
    @State var sizeRect: CGRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    
    @Binding var headerSize: CGSize
    
    func updateBarHeights(localHeaderSize: CGSize) {
        if graphHourPointData.count > 0 {
            self.singleHeight = (sizeRect.height - headerSize.height) / CGFloat(awattarData.energyData!.prices.count)
            var currentHeight: CGFloat = localHeaderSize.height

            for hourPointIndex in 0...(graphHourPointData.count - 1) {
                withAnimation {
                    graphHourPointData[hourPointIndex].1 = currentHeight
                }
                currentHeight += singleHeight
            }
        }
    }
    
    func setGraphValues(energyData: EnergyData, localSizeRect: CGRect, localHeaderSize: CGSize) {
        if !(localSizeRect.width == 0 || localSizeRect.height == 0) {
            self.singleBarSettings = SingleBarSettings(minPrice: energyData.minPrice, maxPrice: energyData.maxPrice)
            self.singleHeight = (localSizeRect.height - localHeaderSize.height) / CGFloat(energyData.prices.count)
            
            if self.singleHeight != 0 {
                self.graphHourPointData = []
                self.dateMarkPointIndex = nil
                
                let firstItemDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[0].startTimestamp))
                var currentHeight: CGFloat = localHeaderSize.height
                for hourPointEntry in energyData.prices {
                    graphHourPointData.append((hourPointEntry, currentHeight))
                    let currentItemDate = Date(timeIntervalSince1970: TimeInterval(hourPointEntry.startTimestamp))

                    if !(Calendar.current.compare(firstItemDate, to: currentItemDate, toGranularity: .day) == .orderedSame) && self.dateMarkPointIndex == nil {
                        var hourPointEntryIndex = (currentHeight - localHeaderSize.height) / singleHeight
                        hourPointEntryIndex = ((hourPointEntryIndex * 100).rounded() / 100).rounded(.up)
                        self.dateMarkPointIndex = Int(hourPointEntryIndex)
                    }
                     
                    currentHeight += singleHeight
                }
            }
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
            print("There was an error initiating the haptic engine: \(error)")
        }
    }
    
    func shortTapHaptic() {
        guard (self.hapticEngine != nil) else { return }
    
        var hapticEvents = [CHHapticEvent]()
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
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
    
    func readRectSize(preference: GraphSizePreferenceKey.SizeBounds, geo: GeometryProxy) -> some View {
        let newSizeRect = geo[preference.bounds]
        DispatchQueue.main.async {
            guard (newSizeRect != self.sizeRect) else { return }
            self.sizeRect = newSizeRect
//             print("Set graph size to \(newSizeRect)")
        }
        return Color.clear
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
                
                var newPointerIndexSelected: Int? = Int(((locationHeight / singleHeight) - 1).rounded(.up))

                if newPointerIndexSelected != nil {
                    if newPointerIndexSelected! < 0 || newPointerIndexSelected! > graphHourPointData.count - 1 {
                        newPointerIndexSelected = nil
                    }
                    
                    if newPointerIndexSelected != currentPointerIndexSelected {
                        shortTapHaptic()
                    }
                }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPointerIndexSelected = newPointerIndexSelected
                }
            }
            .onEnded {_ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPointerIndexSelected = nil
                }
            }

        ZStack {
            GeometryReader { _ in
                ZStack {
                    if singleBarSettings != nil {
                        ForEach(0..<graphHourPointData.count, id: \.self) { hourPointIndex -> EnergyPriceSingleBar in
                            EnergyPriceSingleBar(
                                singleBarSettings: singleBarSettings!,
                                width: sizeRect.width,
                                height: singleHeight,
                                startHeight: graphHourPointData[hourPointIndex].1,
                                indexSelected: currentPointerIndexSelected,
                                ownIndex: hourPointIndex,
                                maxIndex: graphHourPointData.count - 1,
                                hourDataPoint: graphHourPointData[hourPointIndex].0)
                        }
                    }
                    
                    if dateMarkPointIndex != nil && graphHourPointData.isEmpty == false {
                        DayMarkView(graphPointItem: graphHourPointData[dateMarkPointIndex!], indexSelected: currentPointerIndexSelected, ownIndex: dateMarkPointIndex!, maxIndex: graphHourPointData.count - 1, height: singleHeight)
                    }
                }
            }
            .onAppear {
                initCHEngine()
            }
            .onChange(of: scenePhase) { newScenePhase in
                if newScenePhase == .active {
                    initCHEngine()
                    setGraphValues(energyData: awattarData.energyData!, localSizeRect: sizeRect, localHeaderSize: headerSize)
                }
            }
            .onReceive(awattarData.$energyData) { newEnergyData in
                guard let energyData = newEnergyData else { return }
                setGraphValues(energyData: energyData, localSizeRect: sizeRect, localHeaderSize: headerSize)
            }
            .onChange(of: sizeRect) { newSizeRect in
                setGraphValues(energyData: awattarData.energyData!, localSizeRect: newSizeRect, localHeaderSize: headerSize)
            }
            .onChange(of: headerSize) { newHeaderSize in
                updateBarHeights(localHeaderSize: newHeaderSize)
            }
            .anchorPreference(key: GraphSizePreferenceKey.self, value: .bounds, transform: { GraphSizePreferenceKey.SizeBounds(bounds: $0) })
            .backgroundPreferenceValue(GraphSizePreferenceKey.self) { preference in
                if preference != nil {
                    GeometryReader { geo in
                        self.readRectSize(preference: preference!, geo: geo)
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
            .drawingGroup()
            
            VStack {
                if sizeRect.height != 0 {
                    Color.clear
                        .frame(width: sizeRect.width, height: sizeRect.height)
                        .contentShape(Rectangle())
                        .gesture(graphDragGesture)
                        .position(x: sizeRect.width / 2, y: (headerSize.height) + (sizeRect.height / 2))
                }
            }
        }
    }
}
