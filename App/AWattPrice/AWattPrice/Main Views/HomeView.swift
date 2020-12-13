//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct MyTextPreferenceData {
    let viewIndex: Int
    let bounds: Anchor<CGRect>
}

struct MyTextPreferenceKey: PreferenceKey {
    typealias Value = [MyTextPreferenceData]
    static var defaultValue: Value = []
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}

/// The home view mainly holds the graph which represents energy costs for each hour throughout the day.
struct HomeView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var firstEverAppear: Bool = true
    @State var showSettingsPage: Bool = false
    
    @State var headerSize: CGSize = CGSize(width: 0, height: 0)
    
    var body: some View {
        NavigationView {
            VStack {
                if awattarData.energyData != nil && currentSetting.setting != nil && awattarData.currentlyNoData == false {
                    ZStack {
                        VStack(spacing: 5) {
                            GeometryReader { geo in
                                VStack(spacing: 5) {
                                    UpdatedDataView()
                                    GraphHeader()
                                }
                                .padding([.leading, .trailing], 16)
                                .padding(.top, 8)
                                .padding(.bottom, 5)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onChange(of: geo.size) { newSize in
                                                print("Size changed to \(newSize)")
                                                self.headerSize = newSize
                                            }
                                    }
                                )
                            }
                            Spacer()
                        }
                        
                        EnergyPriceGraph(headerSize: self.$headerSize)
                    }
                } else {
                    DataDownloadAndError()
                }
            }
            .navigationTitle("elecPrice")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing:
                Button(action: { showSettingsPage.toggle() }) {
                    Image(systemName: "gear")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .padding(.trailing, 5)
                })
            .fullScreenCover(isPresented: $showSettingsPage) {
                SettingsPageView()
                    .environmentObject(currentSetting)
                    .environmentObject(awattarData)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if firstEverAppear == true {
                awattarData.download(forRegion: currentSetting.setting?.regionSelection ?? 0)
                currentSetting.validateTariffAndEnergyPriceSet()
                firstEverAppear = false
            }
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
