//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var hourPriceInfoViewNavControl: Int? = 0
    @State var settingIsPresented: Bool = false
    
    @GestureState var isPressed = false
    
    var hourFormatter: DateFormatter
    var numberFormatter: NumberFormatter
    
    init() {
        hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "H"
        
        numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = Locale(identifier: "de_DE")
        numberFormatter.currencySymbol = "ct"
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Divider()

                HStack {
                    Text("pricePerKwh")
                        .font(.subheadline)
                        .padding(.top, 8)

                    Spacer()

                    Text("hourOfDay")
                        .font(.subheadline)
                }
                .padding(.bottom, 5)

                if awattarData.energyData != nil && currentSetting.setting != nil {
                    EnergyPriceGraph()
                } else {
                    if awattarData.networkConnectionError == false {
                        // no network connection error
                        // download in progress
                        
                        LoadingView()
                    } else {
                        // network connection error
                        // can't fulfill download
                        
                        NetworkConnectionErrorView()
                    }
                }
            }
            .padding([.leading, .trailing], 16)
            .navigationBarTitle("elecPrice")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            currentSetting.setting = getSetting(managedObjectContext: managedObjectContext)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting())
    }
}
