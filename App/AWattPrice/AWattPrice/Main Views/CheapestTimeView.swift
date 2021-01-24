//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

struct ViewSizePreferenceKey: PreferenceKey {
    struct SizeBounds {
        var bounds: Anchor<CGRect>
    }

    typealias Value = SizeBounds?
    var defaultValue: Value = nil

    static func reduce(value: inout SizeBounds?, nextValue: () -> SizeBounds?) {
        value = nextValue()
    }
}

struct CheapestTimeViewBodyPicker: View {
    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var maxTimeInterval = TimeInterval(3600)
    
    func setMaxTimeInterval() {
        let minMaxRange = backendComm.minMaxTimeRange
        if minMaxRange == nil {
            return
        }
        let nowHourStart = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: Date()),
            minute: 0,
            second: 0,
            of: Date()
        )!
        let nowHourEnd = nowHourStart.addingTimeInterval(3600)
        var differenceTimeInterval: Double = TimeInterval()
        if minMaxRange!.lowerBound >= nowHourStart, minMaxRange!.lowerBound <= nowHourEnd {
            differenceTimeInterval = TimeInterval(
                nowHourStart.timeIntervalSince(
                    Date()
                ).rounded(.up)
            )
        }
        maxTimeInterval = (minMaxRange!.upperBound.timeIntervalSince(minMaxRange!.lowerBound)) + differenceTimeInterval
    }

    var body: some View {
        VStack {
            EasyIntervalPickerRepresentable(
                $cheapestHourManager.timeOfUsageInterval,
                maxTimeInterval: maxTimeInterval,
                selectionInterval: 5
            )
            .frame(width: 275) // The UI View won't apply to this property. But it makes sure that the time interval picker won't go outside of display borders (i.e. on iPhone SE).
            .onAppear {
                setMaxTimeInterval()
            }
            .onReceive(backendComm.$energyData) { _ in
                setMaxTimeInterval()
            }
        }
    }
}

struct CheapestTimeViewBody: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var inputMode: Int = 0

    var body: some View {
        VStack(spacing: 15) {
            Picker("", selection: $inputMode) {
                Text("cheapestPricePage.inputMode.withDuration")
                    .tag(0)
                Text("cheapestPricePage.inputMode.withKwh")
                    .tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())

            VStack(alignment: .center, spacing: 0) {
                VStack(alignment: .center, spacing: 25) {
                    if inputMode == 0 {
                        CheapestTimeViewBodyPicker()
                    } else if inputMode == 1 {
                        PowerOutputInputField(errorValues: cheapestHourManager.errorValues)
                        EnergyUsageInputField(errorValues: cheapestHourManager.errorValues)
                    }
                }
                .padding(.bottom, inputMode == 0 ? 0 : 25)

                TimeRangeInputField()
            }
            .onChange(of: inputMode) { newInputMode in
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    cheapestHourManager.errorValues = []
                }
                cheapestHourManager.inputMode = newInputMode
            }
        }
        .padding(.top, 20)
        .padding([.leading, .trailing], 20)
        .padding(.bottom, 10)
    }
}

/// A view which allows the user to find the cheapest hours for using energy. It optionally can also show
/// the final price which the user would have to pay to aWATTar if consuming the specified amount of energy.
struct CheapestTimeView: View {
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var backendComm: BackendCommunicator
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var redirectToComparisonResults: Int? = 0

    var energyDataTimeRange: ClosedRange<Date> {
        // Add one or subtract one to not overlap to the next or previouse day
        let min = backendComm.energyData!.prices.first!.startTimestamp.addingTimeInterval(1)
        let max = backendComm.energyData!.prices.last!.endTimestamp.addingTimeInterval(-1)

        return min ... max
    }

    var body: some View {
        NavigationView {
            VStack {
                if backendComm.energyData != nil && currentSetting.entity != nil {
                    ScrollView {
                        VStack(spacing: 0) {
                            CheapestTimeViewBody()

                            Spacer()

                            NavigationLink(
                                destination: CheapestTimeResultView(),
                                tag: 1,
                                selection: $redirectToComparisonResults
                            ) {}

                            // Button to perform calculations to find cheapest hours and
                            // to redirect to the result view to show the results calculated
                            Button(action: {
                                self.hideKeyboard()
                                cheapestHourManager.setValues()
                                if cheapestHourManager.errorValues.contains(0) {
                                    // All requirements are satisfied
                                    redirectToComparisonResults = 1
                                }
                            }, label: {
                                HStack {
                                    Text("general.result")
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color.white)
                                        .padding(.leading, 10)
                                }
                            })
                                .buttonStyle(ActionButtonStyle())
                                .padding([.leading, .trailing, .bottom], 16)
                                .padding(.top, 5)
                        }
                        .animation(.easeInOut)
                    }
                    .padding(.top, 1.5)
                } else {
                    DataDownloadAndError()
                }
            }
            .navigationTitle("cheapestPricePage.cheapestPrice")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct CheapestTimeView_Previews: PreviewProvider {
    static var previews: some View {
        let backendComm = BackendCommunicator()
        let networkManager = NetworkManager()

        return VStack(spacing: 0.0) {
            CheapestTimeView()
                .environmentObject(backendComm)
                .environmentObject(CheapestHourManager())
                .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
                .preferredColorScheme(.light)
                .onAppear {
                    backendComm.download(forRegion: 0, networkManager: networkManager)
                }
            Spacer(minLength: 0)
            TabBar()
                .environmentObject(TBItems())
        }
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: "de_DE"))
    }
}
