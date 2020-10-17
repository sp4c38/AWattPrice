//
//  SplashScreenFinishView.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

struct SplashScreenFinishView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(Color.green)
                    .font(.system(size: 100, weight: .regular))
                
                Text("Setup finished")
                    .font(.system(size: 30, weight: .black))
                    .padding(.bottom, 5)
                
                Text("You will be able to change your\n settings again later.")
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            Spacer()
            
            Button(action: {}) {
                Text("Finish")
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .padding()
    }
}

struct SplashScreenFinishView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenFinishView()
    }
}
