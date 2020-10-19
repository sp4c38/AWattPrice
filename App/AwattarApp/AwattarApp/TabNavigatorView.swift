//
//  MainView.swift
//  AwattarApp
//
//  Created by Léon Becker on 13.09.20.
//

import SwiftUI

struct OutSideView: View {
    @Binding var test: Bool
    
    var body: some View {
        VStack {
            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                .font(.largeTitle)
            
            Button(action: {
                test = false
            }) {
                Text("Is true switch to false")
            }
        }
    }
}

struct TabNavigatorView: View {
    @EnvironmentObject var awattarData: AwattarData
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var tabSelection = 1
    
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
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
            }
        }
//        VStack {
//            if currentSetting.setting != nil {
//                if currentSetting.setting!.splashScreensFinished == true {
//                    TabView(selection: $tabSelection) {
//                        SettingsPageView()
//                            .tabItem {
//                                Image(systemName: "gear")
//                                Text("settings")
//                            }
//                            .tag(0)
//
//
//                        HomeView()
//                            .tabItem {
//                                Image(systemName: "bolt")
//                                Text("elecPrice")
//                            }
//                            .tag(1)
//
//                        ConsumptionComparisonView()
//                            .tabItem {
//                                Image(systemName: "rectangle.and.text.magnifyingglass")
//                                Text("usage")
//                            }
//                            .tag(2)
//                    }
//                } else if currentSetting.setting!.splashScreensFinished == false || test == false {
//                    Button(action: {test = true}) {
//                        Text("Switch")
//                    }
//                    SplashScreenStartView(test: $test)
//                        .onReceive(timer) { _ in
//                            print(currentSetting.setting!.splashScreensFinished)
//                            print(test)
//                        }
//                }
//            } else if currentSetting.setting == nil {
//
//            }
//        }
//        .onAppear {
//            currentSetting.setting = getSetting(managedObjectContext: managedObjectContext)
//        }
    }
}

struct TabNavigatorView_Previews: PreviewProvider {
    static var previews: some View {
        TabNavigatorView()
    }
}
