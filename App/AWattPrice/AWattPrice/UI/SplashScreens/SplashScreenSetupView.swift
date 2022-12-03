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

    @State var nextSplashScreenActive: Bool = false

    var body: some View {
        VStack {
            Form {
                Section {
                    RegionTaxSelectionView()
                }
                
                Section(header: Text("Notifications")) {
                    PriceBelowNotificationView(showHeader: true)
                }
            }
            
            NavigationLink(destination: SplashScreenFinishView(), isActive: $nextSplashScreenActive) {
                Button(action: { nextSplashScreenActive = true }) {
                    Text("Continue")
                }
                .buttonStyle(ContinueButtonStyle())
                .padding(.bottom, 16)
                .padding([.leading, .trailing], 16)
            }
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarTitle("Setup")
        .background((colorScheme == .light ? Color(red: 0.95, green: 0.95, blue: 0.97) : Color.black).ignoresSafeArea(.all))
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
