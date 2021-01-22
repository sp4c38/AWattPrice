//
//  APNSUploadError.swift
//  AWattPrice
//
//  Created by Léon Becker on 22.01.21.
//

import SwiftUI

struct APNSUploadError: View {
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .font(.title)
                
                Text("Error uploading notification settings.")
            }
            
            Text("Try again")
                .bold()
                .padding(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 2)
                )
                .background(
                    Color.red
                        .cornerRadius(5)
                        .shadow(radius: 5)
                )
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.red)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct APNSUploadError_Previews: PreviewProvider {
    static var previews: some View {
        APNSUploadError()
    }
}
