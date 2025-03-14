//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

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

struct PricesView: View {
    @Environment(\.scenePhase) var scenePhase

    @EnvironmentObject var energyDataController: EnergyDataController
    @EnvironmentObject var setting: SettingCoreData

    @State var headerSize = CGSize(width: 0, height: 0)
    @State var initialAppearFinished: Bool? = false

    func parseHeaderSize(preference: HeaderSizePreferenceKey.SizeBounds, geo: GeometryProxy) -> some View {
        let newHeaderSize = geo[preference.bounds].size
        guard newHeaderSize != headerSize else { return Color.clear }
        headerSize = newHeaderSize
        return Color.clear
    }

    var body: some View {
        NavigationView {
            VStack {
                if energyDataController.energyData != nil {
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
            }
        }
    }
    
    func loadEnergyData() {
        if let region = Region(rawValue: setting.entity.regionIdentifier) {
            energyDataController.download(region: region)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        PricesView()
            .environment(\.managedObjectContext, CoreDataService.shared.container.viewContext)
            .environmentObject(SettingCoreData(viewContext: CoreDataService.shared.container.viewContext))
    }
}
