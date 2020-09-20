//
//  MainView.swift
//  AwattarApp
//
//  Created by Léon Becker on 13.09.20.
//

import SwiftUI

struct TabNavigatorView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "bolt")
                    Text("Strompreise")
                }
            
            ConsumptionComparatorView()
                .tabItem {
                    Image(systemName: "rectangle.and.text.magnifyingglass")
                    Text("Verbrauchsvergleicher")
                }
        }
    }
}

struct TabNavigatorView_Previews: PreviewProvider {
    static var previews: some View {
        TabNavigatorView()
    }
}
