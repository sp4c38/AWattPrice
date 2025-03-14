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
            Text("Cent per kWh")

            Spacer()

            Text("Hour of day")
        }
        .font(.fSubHeadline)
        .animation(.easeInOut)
    }
}

struct GraphSizePreferenceKey: PreferenceKey {
    struct SizeBounds: Equatable {
        static func == (_: GraphSizePreferenceKey.SizeBounds, _: GraphSizePreferenceKey.SizeBounds) -> Bool {
            false
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

    @EnvironmentObject var energyDataController: EnergyDataController

    @State var graphHourPointData = [(EnergyPricePoint, CGFloat)]()
    @State var hapticEngine: CHHapticEngine?
    @State var currentPointerIndexSelected: Int?
    @State var singleHeight: CGFloat = 0
    @State var singleBarSettings: SingleBarSettings?
    @State var dateMarkPointIndex: Int?

    @State var sizeRect = CGRect(x: 0, y: 0, width: 0, height: 0)

    @Binding var headerSize: CGSize

    func updateBarHeights(localHeaderSize: CGSize) {
        if graphHourPointData.count > 0 {
            singleHeight = (sizeRect.height - headerSize.height) / CGFloat(energyDataController.energyData!.currentPrices.count)
            var currentHeight: CGFloat = localHeaderSize.height

            for hourPointIndex in 0 ... (graphHourPointData.count - 1) {
                withAnimation {
                    graphHourPointData[hourPointIndex].1 = currentHeight
                }
                currentHeight += singleHeight
            }
        }
    }

    func setGraphValues(energyData: EnergyData, localSizeRect: CGRect, localHeaderSize: CGSize) {
        if !(localSizeRect.width == 0 || localSizeRect.height == 0) {
            var minPrice = energyData.minCostPricePoint?.marketprice ?? 0
            if minPrice > 0 {
                minPrice = 0
            }
            let maxPrice = energyData.maxCostPricePoint?.marketprice ?? 0
            singleBarSettings = SingleBarSettings(minPrice: minPrice, maxPrice: maxPrice)
            singleHeight = (localSizeRect.height - localHeaderSize.height) / CGFloat(energyData.currentPrices.count)

            if singleHeight != 0 {
                graphHourPointData = []
                dateMarkPointIndex = nil

                let firstItemDate = energyData.currentPrices.first!.startTime
                var currentHeight: CGFloat = localHeaderSize.height
                for hourPointEntry in energyData.currentPrices {
                    graphHourPointData.append((hourPointEntry, currentHeight))
                    let currentItemDate = hourPointEntry.startTime

                    if !(Calendar.current.compare(firstItemDate, to: currentItemDate, toGranularity: .day) == .orderedSame), dateMarkPointIndex == nil {
                        var hourPointEntryIndex = (currentHeight - localHeaderSize.height) / singleHeight
                        hourPointEntryIndex = ((hourPointEntryIndex * 100).rounded() / 100).rounded(.up)
                        dateMarkPointIndex = Int(hourPointEntryIndex)
                    }

                    currentHeight += singleHeight
                }
            }
        }
    }

    func initCHEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            do {
                try hapticEngine?.start()
            } catch {
                hapticEngine = nil
            }
        } catch {
            logger.error("There was an error initiating the haptic engine: \(error.localizedDescription).")
        }
    }

    func shortTapHaptic() {
        guard hapticEngine != nil else { return }

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
            logger.error("Failed to play haptic pattern: \(error.localizedDescription).")
        }
    }

    func readRectSize(preference: GraphSizePreferenceKey.SizeBounds, geo: GeometryProxy) -> some View {
        let newSizeRect = geo[preference.bounds]
        DispatchQueue.main.async {
            guard newSizeRect != self.sizeRect else { return }
            self.sizeRect = newSizeRect
            // logger.debug("Set graph size to \(newSizeRect.debugDescription)")
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
            .onEnded { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPointerIndexSelected = nil
                }
            }

        ZStack {
            GeometryReader { _ in
                ZStack {
                    if singleBarSettings != nil {
                        ForEach(0 ..< graphHourPointData.count, id: \.self) { hourPointIndex -> EnergyPriceSingleBar in
                            EnergyPriceSingleBar(
                                singleBarSettings: singleBarSettings!,
                                width: sizeRect.width,
                                height: singleHeight,
                                startHeight: graphHourPointData[hourPointIndex].1,
                                indexSelected: currentPointerIndexSelected,
                                ownIndex: hourPointIndex,
                                maxIndex: graphHourPointData.count - 1,
                                hourDataPoint: graphHourPointData[hourPointIndex].0
                            )
                        }
                    }

                    if dateMarkPointIndex != nil && graphHourPointData.isEmpty == false {
                        DayMarkView(
                            graphPointItem: graphHourPointData[dateMarkPointIndex!],
                            indexSelected: currentPointerIndexSelected,
                            ownIndex: dateMarkPointIndex!,
                            maxIndex: graphHourPointData.count - 1,
                            height: singleHeight
                        )
                    }
                }
            }
            .onAppear {
                initCHEngine()
            }
            .onChange(of: scenePhase) { newScenePhase in
                if newScenePhase == .active {
                    initCHEngine()
                    setGraphValues(energyData: energyDataController.energyData!, localSizeRect: sizeRect, localHeaderSize: headerSize)
                }
            }
            .onReceive(energyDataController.$energyData) { newEnergyData in
                guard let energyData = newEnergyData else { return }
                setGraphValues(energyData: energyData, localSizeRect: sizeRect, localHeaderSize: headerSize)
            }
            .onChange(of: sizeRect) { newSizeRect in
                setGraphValues(energyData: energyDataController.energyData!, localSizeRect: newSizeRect, localHeaderSize: headerSize)
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
                        .position(x: sizeRect.width / 2, y: headerSize.height + (sizeRect.height / 2))
                }
            }
        }
    }
}
