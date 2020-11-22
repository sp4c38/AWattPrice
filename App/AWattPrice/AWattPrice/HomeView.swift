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
    
    @State var showSettingsPage: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                if awattarData.energyData != nil && currentSetting.setting != nil && (awattarData.currentlyNoData == false) {
                    VStack(spacing: 3) {
                        UpdatedDataView()
                        GraphHeader()
                    }
                    .padding([.leading, .trailing], 16)
                    .padding(.top, 8)
                    .padding(.bottom, 5)

                    EnergyPriceGraph()
                } else {
                    DataDownloadAndError()
                }
            }
            .zIndex(0)
            .navigationTitle("elecPrice")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showSettingsPage) {
                SettingsPageView()
                    .environmentObject(currentSetting)
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
            awattarData.download(forRegion: currentSetting.setting?.regionSelection ?? 0)
            currentSetting.validateTariffAndEnergyPriceSet()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                print("Updating data")
                awattarData.download(forRegion: currentSetting.setting?.regionSelection ?? 0)
            }
        }
        .onChange(of: currentSetting.setting?.regionSelection) { newRegionSelection in
            awattarData.download(forRegion: currentSetting.setting?.regionSelection ?? 0)
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
