//
//  SplashScreenSetupView.swift
//
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

/// Splash screen which handles the input of settings which are required for the main functionality of the app.
struct SplashScreenSetupView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var redirectToNextSplashScreen: Int? = 0
    @State var basicCharge: String = ""
    
    var body: some View {
        ZStack {
            if colorScheme == .light {
                Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9686)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 40) {
                List {
                    AwattarBasicEnergyChargePriceSetting()
                    AwattarTarifSelectionSetting()
                }
                .environment(\.defaultMinListHeaderHeight, 36)
                .listStyle(InsetGroupedListStyle())
                
                NavigationLink("", destination: SplashScreenFinishView(), tag: 1, selection: $redirectToNextSplashScreen)
                    .hidden()
                
                Button(action: {
                    redirectToNextSplashScreen = 1
                }) {
                    Text("continue")
                }
                .buttonStyle(ContinueButtonStyle())
                .padding(.bottom, 16)
                .padding([.leading, .trailing], 16)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarTitle("splashScreenSetupTitle")
            .contentShape(Rectangle())
            .onTapGesture {
                self.hideKeyboard()
            }
        }
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
