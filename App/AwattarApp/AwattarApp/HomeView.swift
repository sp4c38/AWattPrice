//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

/// The home view mainly holds the graph which represents energy costs for each hour throughout the day.
struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
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
                        // download in progress
                        
                        LoadingView()
                    } else {
                        // there is a network connection error
                        // and the download can't be fulfilled
                        
                        NetworkConnectionErrorView()
                            .transition(.opacity)
                    }
                }
            }
            .padding([.leading, .trailing], 16)
            .navigationBarTitle("elecPrice")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
