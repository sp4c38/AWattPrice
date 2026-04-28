//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct PricesView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService

    private var hasCurrentPriceData: Bool {
        energyDataService.energyData?.currentPrices.isEmpty == false
    }

    var body: some View {
        NavigationView {
            Group {
                if hasCurrentPriceData {
                    VStack(spacing: 6) {
                        EnergyPriceGraph()
                            .padding(.leading, 10)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                            .padding(.top, 2)
                    }
                } else {
                    DataDownloadAndError()
                }
            }
            .navigationTitle("Electricity Prices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    UpdatedDataView()
                        .frame(width: 150)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        PricesView()
    }
}
