//
//  MainView.swift
//  AwattarApp
//
//  Created by Léon Becker on 13.09.20.
//

import SwiftUI

struct TabNavigatorView: View {
    @EnvironmentObject var awattarData: AwattarData
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var tabSelection = 1
    
    var body: some View {
        VStack {
            if currentSetting.setting != nil {
                if currentSetting.setting!.splashScreensFinished == true {
                    TabView(selection: $tabSelection) {
                        SettingsPageView()
                            .tabItem {
                                Image(systemName: "gear")
                                Text("settings")
                            }
                            .tag(0)
                        
                        
                        HomeView()
                            .tabItem {
                                Image(systemName: "bolt")
                                Text("elecPrice")
                            }
                            .tag(1)
                        
                        ConsumptionComparisonView()
                            .tabItem {
                                Image(systemName: "rectangle.and.text.magnifyingglass")
                                Text("usage")
                            }
                            .tag(2)
                    }
                } else if currentSetting.setting!.splashScreensFinished == false {
                    SplashScreenStartView()
                }
            } else if currentSetting.setting == nil {
                
            }
        }
        .onAppear {
            currentSetting.setting = getSetting(managedObjectContext: managedObjectContext)
        }
    }
}

struct TabNavigatorView_Previews: PreviewProvider {
    static var previews: some View {
        TabNavigatorView()
    }
}
