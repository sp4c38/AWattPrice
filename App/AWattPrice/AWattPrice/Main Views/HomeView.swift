//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct HeaderSizePreferenceKey: PreferenceKey {
    struct SizeBounds: Equatable {
        static func == (lhs: HeaderSizePreferenceKey.SizeBounds, rhs: HeaderSizePreferenceKey.SizeBounds) -> Bool {
            return false
        }
        
        var bounds: Anchor<CGRect>
    }
    
    typealias Value = SizeBounds?
    static var defaultValue: Value = nil
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
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
    
    func parseHeaderSize(preference: HeaderSizePreferenceKey.SizeBounds, geo: GeometryProxy) -> some View {
        let newHeaderSize = geo[preference.bounds].size
        guard (newHeaderSize != headerSize) else { return Color.clear }
        self.headerSize = newHeaderSize
        return Color.clear
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if awattarData.energyData != nil && currentSetting.entity != nil && awattarData.currentlyNoData == false {
                    ZStack {
                        VStack {
                            VStack(spacing: 5) {
                                UpdatedDataView()
                                GraphHeader()
                            }
                            .padding([.leading, .trailing], 16)
                            .padding(.top, 8)
                            .padding(.bottom, 5)
                            .anchorPreference(key: HeaderSizePreferenceKey.self, value: .bounds, transform: { HeaderSizePreferenceKey.SizeBounds(bounds: $0) })
                            .backgroundPreferenceValue(HeaderSizePreferenceKey.self) { headerSize in
                                if headerSize != nil {
                                    GeometryReader { geo in
                                        self.parseHeaderSize(preference: headerSize!, geo: geo)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        EnergyPriceGraph(headerSize: self.$headerSize)
                    }
                } else {
                    DataDownloadAndError()
                }
            }
            .navigationTitle("electricityPage.elecPrice")
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
            // Though onAppear will be called only on the first ever appear anyway this variable is used to make sure that onAppear doesn't interfere with any other on* methods applied to this view.
            awattarData.download(forRegion: currentSetting.entity?.regionSelection ?? 0)
            currentSetting.validateTariffAndEnergyPriceSet()
            managePushNotificationsOnAppStart()
            firstEverAppear = false
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active && firstEverAppear == false {
                print("Updating data")
                awattarData.download(forRegion: currentSetting.entity?.regionSelection ?? 0)
            }
        }
        .onChange(of: currentSetting.entity?.regionSelection) { newRegionSelection in
            awattarData.download(forRegion: currentSetting.entity?.regionSelection ?? 0)
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
