//
//  LoadingView.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

// A general loading view which is used at multiple spots throughout the application where date is beeing processed or downloaded
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView("loading")
            
            Spacer()
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
