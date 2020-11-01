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
    
    @State var showSettingsPage: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("centPerKwh")
                        .font(.subheadline)
                        .padding(.top, 8)

                    Spacer()

                    Text("hourOfDay")
                        .font(.subheadline)
                }
                .padding(.leading, 16)
                .padding(.bottom, 5)

                if awattarData.energyData != nil && currentSetting.setting != nil {
                    EnergyPriceGraph()
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
            .padding(.trailing, 16)
            .navigationTitle("elecPrice")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showSettingsPage) {
                SettingsPageView().environmentObject(TextFieldCurrentlySelected())
            }
            .navigationBarItems(trailing:
                Button(action: { showSettingsPage.toggle() }) {
                    Image(systemName: "gear")
                        .resizable()
                        .frame(width: 22, height: 22)
                        .padding(.trailing, 5)
                })
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
