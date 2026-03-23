//
//  SplashScreenSetupView.swift
//  AWattPrice
//
//  Created by Léon Becker on 16.12.20.
//


import SwiftUI

/// Splash screen which handles the input of settings which are required for the main functionality of the app.
struct SplashScreenSetupView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var nextSplashScreenActive: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        RegionTaxSelectionView()
                    }
                    
                    Section(header: Text("Notifications")) {
                        PriceBelowNotificationView(showHeader: true)
                    }
                }
                
                Button(action: { nextSplashScreenActive = true }) {
                    Text("Continue")
                }
                .buttonStyle(ContinueButtonStyle())
                .padding(.bottom, 16)
                .padding([.leading, .trailing], 16)
            }
            .ignoresSafeArea(.keyboard)
            .navigationTitle("Setup")
            .background((colorScheme == .light ? Color(red: 0.95, green: 0.95, blue: 0.97) : Color.black).ignoresSafeArea(.all))
            .navigationDestination(isPresented: $nextSplashScreenActive) {
                SplashScreenFinishView()
            }
        }
    }
}

struct SplashScreenSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SplashScreenSetupView()
                .preferredColorScheme(.light)
        }
    }
}
