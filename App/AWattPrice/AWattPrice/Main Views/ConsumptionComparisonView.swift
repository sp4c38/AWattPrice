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

/// A view which allows the user to find the cheapest hours for using energy. It optionally can also show the final price which the user would have to pay to aWATTar if consuming the specified amount of energy.
struct ConsumptionComparisonView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    /// A list to which values representing different types of errors are added if any occur
    @State var fieldsEnteredErrorValues = [Int]()
    /// State variable which if set to true triggers that extra informations is shown of what this view does because it may not be exactly clear to the user at first usage.
    @State var redirectToComparisonResults: Int? = 0
    
    /**
     A time range which goes from the start time of the first energy price data point to the end time of the last energy price data point downloaded from the server
    - This time range is used in date pickers to make only times selectable for which also energy price data points currently exist
    */
    var energyDataTimeRange: ClosedRange<Date> {
        let maxHourIndex = awattarData.energyData!.prices.count - 1
        
        // Add one or subtract one to not overlap to the next or previouse day
        let min = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[0].startTimestamp + 1))
        let max = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[maxHourIndex].endTimestamp - 1))
        
        return min...max
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if awattarData.energyData != nil && currentSetting.setting != nil {
                    ScrollView {
                        VStack(spacing: 0) {
                            VStack(alignment: .center, spacing: 20) {
                                PowerOutputInputField(errorValues: fieldsEnteredErrorValues)
                                EnergyUsageInputField(errorValues: fieldsEnteredErrorValues)
                                TimeRangeInputField(errorValues: fieldsEnteredErrorValues)
                            }
                            .padding(.top, 20)
                            .padding([.leading, .trailing], 20)
                            .padding(.bottom, 10)

                            Spacer()

                            NavigationLink(destination: ConsumptionResultView(), tag: 1, selection: $redirectToComparisonResults) {
                            }

                            // Button to perform calculations to find cheapest hours and to redirect to the result view to show the results calculated
                            Button(action: {
                                self.hideKeyboard()
                                fieldsEnteredErrorValues = cheapestHourManager.setValues()
                                if fieldsEnteredErrorValues.contains(0) {
                                    // All requirements are satisfied
                                    redirectToComparisonResults = 1
                                }
                            }) {
                                HStack {
                                    Text("general.result")
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color.white)
                                        .padding(.leading, 10)
                                }
                            }
                            .buttonStyle(ActionButtonStyle())
                            .padding([.leading, .trailing, .bottom], 16)
                            .padding(.top, 10)
                        }
                    }
                } else {
                    DataDownloadAndError()
                }
            }
            .navigationTitle("cheapestPricePage.cheapestPrice")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .animation(nil)
    }
}

struct ConsumptionComparatorView_Previews: PreviewProvider {
    static var previews: some View {
        EnergyUsageInputField(errorValues: [2])
            .environmentObject(CheapestHourManager())
            .preferredColorScheme(.dark)
            .padding()
    }
}
