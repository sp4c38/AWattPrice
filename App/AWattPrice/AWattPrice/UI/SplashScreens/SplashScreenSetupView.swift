//
//  SplashScreenSetupView.swift
//  AWattPrice
//
//  Created by Léon Becker on 16.12.20.
//

import Resolver
import SwiftUI

/// Splash screen which handles the input of settings which are required for the main functionality of the app.
struct SplashScreenSetupView: View {
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var currentSetting: CurrentSetting = Resolver.resolve()

    @State var redirectToNextSplashScreen: Int? = 0
    @State var basicCharge: String = ""

    var body: some View {
        VStack {
            if currentSetting.entity != nil {
                CustomInsetGroupedList {
                    RegionTaxSelectionView()

                    PriceBelowNotificationView(showHeader: true)
                    
//                    AwattarTariffSelectionSetting()
                }

                NavigationLink("", destination: SplashScreenFinishView(), tag: 1, selection: $redirectToNextSplashScreen)
                    .hidden()

                Button(action: {
                    redirectToNextSplashScreen = 1
                }) {
                    Text("Continue")
                }
                .buttonStyle(ContinueButtonStyle())
                .padding(.bottom, 16)
                .padding([.leading, .trailing], 16)
            } else {
                Text("Couldn't load settings.")
            }
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarTitle("Setup")
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SplashScreenSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SplashScreenSetupView()
                .preferredColorScheme(.light)
                .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
        }
    }
}
