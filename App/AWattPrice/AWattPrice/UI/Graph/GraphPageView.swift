//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import Resolver
import SwiftUI

struct HeaderSizePreferenceKey: PreferenceKey {
    struct SizeBounds: Equatable {
        static func == (_: HeaderSizePreferenceKey.SizeBounds, _: HeaderSizePreferenceKey.SizeBounds) -> Bool {
            false
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
    @Environment(\.networkManager) var networkManager
    @Environment(\.scenePhase) var scenePhase

    @ObservedObject var energyDataController: EnergyDataController = Resolver.resolve()
    @ObservedObject var currentSetting: CurrentSetting = Resolver.resolve()

    @State var headerSize = CGSize(width: 0, height: 0)
    @State var initialAppearFinished: Bool? = false
    @State var showWhatsNewPage: Bool = false

    func parseHeaderSize(preference: HeaderSizePreferenceKey.SizeBounds, geo: GeometryProxy) -> some View {
        let newHeaderSize = geo[preference.bounds].size
        guard newHeaderSize != headerSize else { return Color.clear }
        headerSize = newHeaderSize
        return Color.clear
    }

    var body: some View {
        NavigationView {
            VStack {
                if energyDataController.energyData != nil, currentSetting.entity != nil {
                    ZStack {
                        VStack {
                            VStack(spacing: 5) {
                                UpdatedDataView()
                                GraphHeader()
                            }
                            .padding([.leading, .trailing], 16)
                            .padding(.top, 8)
                            .padding(.bottom, 5)
                            .anchorPreference(key: HeaderSizePreferenceKey.self,
                                              value: .bounds,
                                              transform: { HeaderSizePreferenceKey.SizeBounds(bounds: $0) })
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
            .navigationTitle("Electricity Prices")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            showWhatsNewPage = currentSetting.entity!.showWhatsNew
            initialAppearFinished = nil
        }
        .onChange(of: scenePhase) { phase in
            if initialAppearFinished == nil {
                initialAppearFinished = true
                return
            }
            if phase == .active, initialAppearFinished == true {
                logger.debug("App was reentered. Updating data.")
                loadEnergyData()
                showWhatsNewPage = currentSetting.entity!.showWhatsNew
            }
        }
        .onChange(of: currentSetting.entity!.regionIdentifier) { _ in
            loadEnergyData()
        }
//        .sheet(isPresented: $showWhatsNewPage) {
//            WhatsNewPage()
//        }
        .onChange(of: showWhatsNewPage) { newValue in
            if newValue == false { currentSetting.changeShowWhatsNew(to: false) }
        }
    }
    
    func loadEnergyData() {
        if let region = Region(rawValue: currentSetting.entity!.regionIdentifier) {
            energyDataController.download(region: region)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(
                CurrentSetting(
                    managedObjectContext: PersistenceManager().persistentContainer.viewContext
                )
            )
    }
}
