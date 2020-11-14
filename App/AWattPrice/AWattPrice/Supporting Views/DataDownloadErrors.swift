//
//  NetworkConnectionErrorView.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

// A general network connection error view which is used at multiple spots throughout the application where no network connection could be established or others network problems occur
struct NetworkConnectionErrorView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var awattarData: AwattarData
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(Color.red)
                    .font(.system(size: 60, weight: .light))
                
                Text("Please connect to the\ninternet")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    awattarData.download()
                }) {
                    Text("Retry")
                }.buttonStyle(RetryButtonStyle())
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

struct SevereDataRetrievalError: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var awattarData: AwattarData
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(Color.orange)
                    .font(.system(size: 60, weight: .light))
                
                Text("tryAgainLater")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    awattarData.download()
                }) {
                    Text("Retry")
                }.buttonStyle(RetryButtonStyle())
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

struct CurrentlyNoData: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var awattarData: AwattarData
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "rectangle.slash.fill")
                    .foregroundColor(Color(red: 0.99, green: 0.74, blue: 0.04, opacity: 1.0))
                    .font(.system(size: 60, weight: .light))
                
                Text("Currently no data available\nPlease try again later")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    awattarData.download()
                }) {
                    Text("Retry")
                }.buttonStyle(RetryButtonStyle())
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
