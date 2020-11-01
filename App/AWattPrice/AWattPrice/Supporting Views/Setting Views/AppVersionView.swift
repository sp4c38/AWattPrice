//
//  AppVersionView.swift
//  AWattPrice
//
//  Created by Léon Becker on 29.10.20.
//

import SwiftUI

struct AppVersionView: View {
    var body: some View {
        CustomInsetGroupedListItem {
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Image("BigAppIcon")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .saturation(0)
                        .opacity(0.6)

                    Text("AWattPrice")
                        .font(.headline)
                    
                    if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                        if let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                            
                            Text("\("version".localized()) \(currentVersion) (\(currentBuild))")
                                .font(.footnote)
                        }
                    }
                }
                Spacer()
            }
            .foregroundColor(Color(hue: 0.6667, saturation: 0.0448, brightness: 0.5255))
        }
    }
}
