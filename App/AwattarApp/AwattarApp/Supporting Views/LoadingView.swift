//
//  LoadingView.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

struct LoadingView: View {
    // Loading view used by multiple views when indicating for example that data is beeing processed or data is beeing downloaded
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView("loadingData")
            
            Spacer()
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
