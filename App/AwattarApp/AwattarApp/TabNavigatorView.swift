//
//  MainView.swift
//  AwattarApp
//
//  Created by Léon Becker on 13.09.20.
//

import SwiftUI

struct TabNavigatorView: View {
    @EnvironmentObject var awattarData: AwattarData
    @State var tabSelection = 1
    
    var body: some View {
        if awattarData.energyData != nil {
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
        } else {
            VStack(spacing: 40) {
                if awattarData.energyData == nil {
                    Spacer()
                    ProgressView("")
                    Text("loadingData")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
        }
    }
}

struct TabNavigatorView_Previews: PreviewProvider {
    static var previews: some View {
        TabNavigatorView()
    }
}
