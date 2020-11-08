//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

/// A view which allows the user to find the cheapest hours for using energy. It optionally can also show the final price which the user would have to pay to aWATTar if consuming the specified amount of energy.
struct ConsumptionComparisonView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    /// State variable which if set to true triggers that extra informations is shown of what this view does because it may not be exactly clear to the user at first usage.
    @State var redirectToComparisonResults: Int? = 0
    /// A list to which values representing different types of errors are added if any occur
    @State var fieldsEnteredErrorValues = [Int]()
    
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
            if awattarData.energyData != nil && currentSetting.setting != nil {
                ScrollView {
                    VStack(alignment: .center, spacing: 20) {
                        PowerOutputInputField(errorValues: fieldsEnteredErrorValues)
                        EnergyUsageInputField(errorValues: fieldsEnteredErrorValues)
                        TimeRangeInputField(errorValues: fieldsEnteredErrorValues)
                    }
                    .animation(.easeInOut)
                    .padding(.top, 20)
                    .padding([.leading, .trailing], 20)
                    .padding(.bottom, 10)

                    Spacer()
                    
                    NavigationLink(destination: ConsumptionResultView(), tag: 1, selection: $redirectToComparisonResults) {
                    }

                    // Button to perform calculations to find cheapest hours and to redirect to the result view to show the results calculated
                    Button(action: {
                        fieldsEnteredErrorValues = cheapestHourManager.setValues()
                        if fieldsEnteredErrorValues.contains(0) {
                            // All requirements are satisfied
                            redirectToComparisonResults = 1
                            self.hideKeyboard()
                        }
                    }) {
                        HStack {
                            Text("result")
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.white)
                                .padding(.leading, 10)
                        }
                    }
                    .buttonStyle(ActionButtonStyle())
                    .padding([.leading, .trailing, .bottom], 16)
                    .padding(.top, 10)
                }
                .navigationTitle("cheapestPrice")
                .onTapGesture {
                    self.hideKeyboard()
                }
            } else {
                if awattarData.severeDataRetrievalError == true {
                    SevereDataRetrievalError()
                        .transition(.opacity)
                } else if awattarData.networkConnectionError == true {
                    NetworkConnectionErrorView()
                        .transition(.opacity)
                } else {
                    LoadingView()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ConsumptionComparatorView_Previews: PreviewProvider {
    static var previews: some View {
        EnergyUsageInputField(errorValues: [2])
            .environmentObject(CheapestHourManager())
            .preferredColorScheme(.dark)
            .padding()
        
//        ConsumptionComparisonView()
//            .environmentObject(CheapestHourManager())
//            .environmentObject(AwattarData())
//            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
//            .preferredColorScheme(.dark)
    }
}
