//
//  NetworkConnectionErrorView.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

struct NetworkConnectionErrorView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(Color.red)
                    .font(.system(size: 60, weight: .light))
                
                Text("Network connection\nfailed")
                    .font(.title3)
                    .multilineTextAlignment(.center)
            }
            .padding(25)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme == .light ? Color(hue: 0.0000, saturation: 0.0000, brightness: 0.9137) : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.2446), lineWidth: 5)
            )

            Spacer()
        }
    }
}

struct NetworkConnectionErrorView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkConnectionErrorView()
            .preferredColorScheme(.dark)
    }
}
