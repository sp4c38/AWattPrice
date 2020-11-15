//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

/// The home view mainly holds the graph which represents energy costs for each hour throughout the day.
struct HomeView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var justNowUpdatedData: Bool? = nil // Shortly set to true
    
    @State var showSettingsPage: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                GraphHeader(justNowUpdatedData: justNowUpdatedData)

                if awattarData.energyData != nil && currentSetting.setting != nil && (awattarData.currentlyNoData == false) {
                    EnergyPriceGraph()
                } else {
                    DataDownloadError()
                }
            }
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
        .onAppear {
            currentSetting.validateTariffAndEnergyPriceSet()
            awattarData.download()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                if justNowUpdatedData != nil {
                    // Not called on start up of the app
                    print("Data updated")
                    awattarData.download()
                    
                    if awattarData.currentlyNoData == false || awattarData.dataRetrievalError == false {
                        withAnimation {
                            justNowUpdatedData = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                justNowUpdatedData = false
                            }
                        }
                    }
                } else {
                    justNowUpdatedData = false
                }
            }
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
