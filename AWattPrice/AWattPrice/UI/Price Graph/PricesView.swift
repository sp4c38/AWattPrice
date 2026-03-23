//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct PricesView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService

    var body: some View {
        NavigationView {
            Group {
                if energyDataService.energyData != nil {
                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            UpdatedDataView()
                            GraphHeader()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        EnergyPriceGraph()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                } else {
                    DataDownloadAndError()
                }
            }
            .navigationTitle("Electricity Prices")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        PricesView()
    }
}
