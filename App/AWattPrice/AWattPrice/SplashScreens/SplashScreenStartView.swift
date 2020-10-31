//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

/**
 Single detail view to show a icon, title and subtitle intended to describe a main functionality of the app.
 */
struct SplashScreenDetailNoteView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var title: LocalizedStringKey
    var subTitle: LocalizedStringKey
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

/**
 Start of all splash screens. Presents and describes the main functionalities of the app briefly.
 */
struct SplashScreenStartView: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    @State var redirectToNextSplashScreen: Int? = 0
    
    var body: some View {
        VStack {
            VStack(spacing: 30) {
                Image("BigAppIcon")
                    .resizable()
                    .scaledToFit()

                VStack(spacing: 5) {
                    Text("splashScreenWelcome")
                        .font(.system(size: 40, weight: .black))
                    Text("AWattPrice App")
                        .foregroundColor(Color(hue: 0.5648, saturation: 1.0000, brightness: 0.6235))
                        .font(.system(size: 36, weight: .black))
                }
                .padding(.bottom, 20)

                SplashScreenDetailNoteView(title: "splashScreenViewPrices", subTitle: "splashScreenViewPricesInfo", imageName: "magnifyingglass")

                SplashScreenDetailNoteView(title: "splashScreenComparePrices", subTitle: "splashScreenComparePricesInfo", imageName: "arrow.left.arrow.right")
            }

            Spacer()
            
            Button(action: {
                currentSetting.changeSplashScreenFinished(newState: true)
            }) {
                Text("continue")
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .padding(.top, 40)
        .padding([.leading, .trailing], 20)
        .padding(.bottom, 16)
    }
}

struct SplashScreenStartView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenStartView()
            .preferredColorScheme(.light)
    }
}
