//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

struct SplashScreenDetailNoteView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var title: String
    var subTitle: String
    var imageName: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: imageName)
                .font(.system(size: 40))
                .foregroundColor(Color(hue: 0.5648, saturation: 1.0000, brightness: 0.6235))
                .padding()
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                
                Text(subTitle)
                    .font(.body)
                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            }
            
            Spacer()
        }
    }
}

struct SplashScreenStartView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var currentSetting: CurrentSetting
    @State var redirectToNextSplashScreen: Int? = 0
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 30) {
                    Image("appSymbol")
                        .resizable()
                        .scaledToFit()

                    VStack(spacing: 5) {
                        Text("Welcome to the")
                            .font(.system(size: 40, weight: .black))
                        Text("energyTo App")
                            .foregroundColor(Color(hue: 0.5648, saturation: 1.0000, brightness: 0.6235))
                            .font(.system(size: 36, weight: .black))
                    }
                    .padding(.bottom, 20)

                    SplashScreenDetailNoteView(title: "View prices", subTitle: "Look at the current energy prices for each hour.", imageName: "magnifyingglass")

                    SplashScreenDetailNoteView(title: "Compare prices", subTitle: "Let the app find the cheapest time to use electricty.", imageName: "arrow.left.arrow.right")

                    NavigationLink("", destination: SplashScreenSetupView(), tag: 1, selection: $redirectToNextSplashScreen)
                }

                Spacer()
                
                Button(action: {
//                    changeSplashScreenFinished(newState: true, settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
                    currentSetting.changeSplashScreenFinished(newState: true)
                }) {
                    Text("Continue")
                }
                .buttonStyle(ContinueButtonStyle())
            }
//            .navigationBarHidden(true)
            .padding(.top, 40)
            .padding([.leading, .trailing], 20)
            .padding(.bottom, 16)
        }
    }
}

struct SplashScreenStartView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenStartView()
            .preferredColorScheme(.light)
    }
}
