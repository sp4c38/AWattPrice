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
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    func getMaxTimeInterval() -> TimeInterval? {
        let minMaxRange = awattarData.minMaxTimeRange
        if minMaxRange == nil {
            return nil
        }
        return minMaxRange!.upperBound.timeIntervalSince(minMaxRange!.lowerBound)
    }
    
    var body: some View {
        VStack {
            if let maxTimeInterval = getMaxTimeInterval() {
                EasyIntervalPickerRepresentable(
                    $cheapestHourManager.timeOfUsageInterval,
                    maxTimeInterval: maxTimeInterval,
                    selectionInterval: 5)
            }
        }
    }
}

struct CheapestTimeViewBody: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    @State var inputMode: Int = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("", selection: $inputMode) {
                Text("cheapestPricePage.inputMode.withDuration")
                    .tag(0)
                Text("cheapestPricePage.inputMode.withKwh")
                    .tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
                
            VStack(alignment: .center, spacing: 20) {
                if inputMode == 0 {
                    CheapestTimeViewBodyPicker()
                } else if inputMode == 1 {
                    PowerOutputInputField(errorValues: cheapestHourManager.errorValues)
                    EnergyUsageInputField(errorValues: cheapestHourManager.errorValues)
                }
                TimeRangeInputField()
            }
            .onChange(of: inputMode) { newInputMode in
                cheapestHourManager.errorValues = []
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

    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var cheapestHourManager: CheapestHourManager

    @State var redirectToComparisonResults: Int? = 0

    var energyDataTimeRange: ClosedRange<Date> {
        let maxHourIndex = awattarData.energyData!.prices.count - 1

        // Add one or subtract one to not overlap to the next or previouse day
        let min = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[0].startTimestamp + 1))
        let max = Date(timeIntervalSince1970:
                        TimeInterval(awattarData.energyData!.prices[maxHourIndex].endTimestamp - 1)
        )

        return min ... max
    }

    var body: some View {
        NavigationView {
            VStack {
                if awattarData.energyData != nil && currentSetting.entity != nil {
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
                            .padding(.top, 10)
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
