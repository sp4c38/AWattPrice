//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//


import SwiftUI

struct SplashScreenStartViewTitle: View {
    var body: some View {
        VStack(spacing: 15) {
            AppIconImage()
                .frame(width: 220, height: 220)

            VStack(spacing: 5) {
                Text("Welcome to")
                    .font(
                        .custom("SFCompactDisplay-Black", fixedSize: 35)
                    )

                Text("AWattPrice")
                    .foregroundColor(Color(hue: 0.5648, saturation: 1.0000, brightness: 0.6235))
                    .font(
                        .custom("SFCompactDisplay-Black", fixedSize: 50)
                    )
            }
        }
    }
}

/**
 Start of all splash screens. Presents and describes the main functionalities of the app briefly.
 */
struct SplashScreenStartView: View {
    @State private var showsFeatures = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 5)

                SplashScreenStartViewTitle()

                Spacer(minLength: 5)
                Spacer(minLength: 5)

                Button(action: {
                    showsFeatures = true
                }) {
                    Text("Continue")
                }
                .buttonStyle(ContinueButtonStyle())
            }
            .padding([.leading, .trailing], 20)
            .padding(.bottom, 16)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showsFeatures) {
                SplashScreenFeaturesAndConsentView()
            }
        }
    }
}

struct SplashScreenStartView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenStartView()
            .preferredColorScheme(.light)
    }
}
