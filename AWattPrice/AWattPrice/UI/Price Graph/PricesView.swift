//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

enum PricesLayout {
    static let graphTrailingPadding: CGFloat = 16
    static let graphTopPadding: CGFloat = 2
    static let graphBottomPadding: CGFloat = 6
    static let graphLeadingPadding: CGFloat = 7
    static let axisLabelSideInset: CGFloat = 8
    static let statusIndicatorWidth: CGFloat = 14
    static let statusTopPadding: CGFloat = 10
    static let statusBottomPadding: CGFloat = 6

    static var statusLeadingPadding: CGFloat {
        graphLeadingPadding + axisLabelSideInset - (statusIndicatorWidth / 2)
    }
}

struct PricesView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService

    private var hasCurrentPriceData: Bool {
        energyDataService.energyData?.currentPrices.isEmpty == false
    }

    var body: some View {
        NavigationView {
            Group {
                if hasCurrentPriceData {
                    VStack(spacing: 0) {
                        statusRow

                        EnergyPriceGraph()
                            .padding(.leading, PricesLayout.graphLeadingPadding)
                            .padding(.trailing, PricesLayout.graphTrailingPadding)
                            .padding(.bottom, PricesLayout.graphBottomPadding)
                            .padding(.top, PricesLayout.graphTopPadding)
                    }
                } else {
                    DataDownloadAndError()
                }
            }
            .appScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var statusRow: some View {
        HStack {
            UpdatedDataView(fillsAvailableWidth: false)
            
            Spacer(minLength: 8)
        }
        .padding(.leading, PricesLayout.statusLeadingPadding)
        .padding(.trailing, PricesLayout.graphTrailingPadding)
        .padding(.top, PricesLayout.statusTopPadding)
        .padding(.bottom, PricesLayout.statusBottomPadding)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        PricesView()
    }
}
