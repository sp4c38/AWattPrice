//
//  DataDownloadAndError.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

struct DataRetrievalLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView("general.loading")
            
            Spacer()
        }
    }
}

struct DataRetrievalError: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var awattarData: AwattarData
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(Color.orange)
                    .font(.system(size: 60, weight: .light))
                
                Text("dataDownloadError.tryAgainLater")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    awattarData.download()
                }) {
                    Text("general.retry")
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
                
                Text("dataDownloadError.noDataAvailable")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    awattarData.download()
                }) {
                    Text("general.retry")
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

/// Classify network errors
struct DataDownloadAndError: View {
    @EnvironmentObject var awattarData: AwattarData
    
    var body: some View {
        VStack {
            if awattarData.dataRetrievalError == true {
                DataRetrievalError()
                    .transition(.opacity)
            } else if awattarData.currentlyNoData == true {
                CurrentlyNoData()
                    .transition(.opacity)
            } else if awattarData.currentlyUpdatingData == true {
                DataRetrievalLoadingView()
            }
        }
    }
}

struct NetworkConnectionErrorView_Previews: PreviewProvider {
    static var previews: some View {
        DataRetrievalError()
            .preferredColorScheme(.dark)
    }
}
