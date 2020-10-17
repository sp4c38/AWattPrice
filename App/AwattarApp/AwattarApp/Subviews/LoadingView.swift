//
//  LoadingView.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            ProgressView("")
            Spacer()
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
