//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

extension AnyTransition {
    /// A transition used for presenting a view with extra information to the screen.
    static var extraInformationTransition: AnyTransition {
        let insertion = AnyTransition.opacity // AnyTransition.scale(scale: 2).combined(with: .opacity)
        let removal = AnyTransition.opacity // AnyTransition.scale(scale: 2).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

struct ElectricityUsageInputField: View {
    @State var someText: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack {
                Text("elecUsage")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            TextField("", text: $someText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
                .padding(.leading, 17)
                .padding(.trailing, 14)
                .padding([.top, .bottom], 10)
                .background(
                    RoundedRectangle(cornerRadius: 40)
                        .stroke(Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706), lineWidth: 2)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(15)
        .padding([.top, .bottom], 9)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}

/// A view which allows the user to find the cheapest hours for using energy. It optionally can also show the final price which the user would have to pay to aWATTar if consuming the specified amount of energy.
struct ConsumptionComparisonView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    
    @ObservedObject var cheapestHourManager = CheapestHourManager()
    
    /// State variable which if set to true triggers that extra informations is shown of what this view does because it may not be exactly clear to the user at first usage.
    @State var showInfo = false
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
            VStack(alignment: .center, spacing: 0) {
                Divider()
                    .padding(.bottom, 10)

                if awattarData.energyData != nil && currentSetting.setting != nil {
//                    VStack(alignment: .leading, spacing: 15) {
//                        // Input of what the power (in kW) is of the electric consumer for which to find the cheapest hours to operate it
//                        VStack(alignment: .leading, spacing: 5) {
//                            Text("elecUsage")
//                                .bold()
//
//                            HStack(spacing: 7) {
//                                TextField("elecUsage", text: $cheapestHourManager.energyUsageInput)
//                                    .keyboardType(.decimalPad)
//                                    .multilineTextAlignment(.leading)
//                                    .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                                Text("kW")
//                            }
//                        }
//
//                        // Input for the start and end date which present the range in which cheapest hours should be found
//                        VStack {
//                            DatePicker(
//                                selection: $cheapestHourManager.startDate,
//                                in: energyDataTimeRange,
//                                displayedComponents: [.date, .hourAndMinute],
//                                label: { Text("startOfUse").bold() })
//
//                            DatePicker(
//                                selection: $cheapestHourManager.endDate,
//                                in: energyDataTimeRange,
//                                displayedComponents: [.date, .hourAndMinute],
//                                label: { Text("endOfUse").bold() })
//                        }
//
//                        // The time picker to select the length of how long the user wants to use energy
//                        VStack(alignment: .leading, spacing: 5) {
//                            Text("lengthOfUse")
//                                .bold()
//
//                            TimeIntervalPicker(cheapestHourManager: cheapestHourManager)
//                                .frame(maxWidth: .infinity)
//                        }
//
//                        Spacer()
//
//                        NavigationLink(destination: ConsumptionResultView(cheapestHourManager: cheapestHourManager), tag: 1, selection: $redirectToComparisonResults) {
//                        }
//
//                        // Button to perform calculations to find cheapest hours and to redirect to the result view to show the results calculated
//                        Button(action: {
//                            redirectToComparisonResults = 1
//                        }) {
//                            Text("showResults")
//                        }.buttonStyle(ActionButtonStyle())
//                    }
                } else {
                    if awattarData.networkConnectionError == false {
                        // no network connection error
                        // download in progress

                        LoadingView()
                    } else {
                        // network connection error
                        // can't fulfill download

                        NetworkConnectionErrorView()
                            .transition(.opacity)
                    }
                }
            }
            .padding(.bottom, 10)
            .padding([.leading, .trailing], 16)
            .onAppear {
                if awattarData.energyData != nil {
                    let maxHourIndex = awattarData.energyData!.prices.count - 1

                    // Set end date of the end date time picker to the maximal currently time where energy price data points exist
                    cheapestHourManager.endDate = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[maxHourIndex].endTimestamp))
                }
            }
            .navigationBarTitle("usage")
            .navigationBarItems(trailing:
                Button(action: {
                    withAnimation {
                        showInfo.toggle()
                    }
                }) {
                    Image(systemName: "info.circle")
                }
            )
        }
    }
}

struct ConsumptionComparatorView_Previews: PreviewProvider {
    static var previews: some View {
        ElectricityUsageInputField()
//            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
