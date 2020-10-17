//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

struct ContinueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hue: 0.6500, saturation: 0.6195, brightness: 0.8863))
            .cornerRadius(11)
    }
}

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
    var body: some View {
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
                
                Button(action: {}) {
                    Text("Continue")
                }
                .buttonStyle(ContinueButtonStyle())
                
            }
            
            Spacer()
        }
        .padding(.top, 40)
        .padding([.leading, .trailing], 20)
    }
}

struct SplashScreenStartView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenStartView()
            .preferredColorScheme(.light)
    }
}
