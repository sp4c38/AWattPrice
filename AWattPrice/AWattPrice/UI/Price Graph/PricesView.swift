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

    @State private var displayInterval = PriceGraphDisplayInterval.sixtyMinutes
    @State private var showsDisplayIntervalInfo = false

    private var hasCurrentPriceData: Bool {
        energyDataService.energyData?.currentPrices.isEmpty == false
    }

    private var currentPrices: [EnergyPricePoint] {
        energyDataService.energyData?.currentPrices ?? []
    }

    private var hasFifteenMinutePriceIntervals: Bool {
        currentPrices.contains { pricePoint in
            abs(pricePoint.endTime.timeIntervalSince(pricePoint.startTime) - TimeInterval(15 * 60)) < 1
        }
    }

    private var effectiveDisplayInterval: PriceGraphDisplayInterval {
        hasFifteenMinutePriceIntervals ? displayInterval : .sixtyMinutes
    }

    var body: some View {
        NavigationView {
            Group {
                if hasCurrentPriceData {
                    VStack(spacing: 0) {
                        statusRow

                        EnergyPriceGraph(
                            displayInterval: effectiveDisplayInterval,
                            allowsHourlyExpansion: hasFifteenMinutePriceIntervals
                        )
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

            if hasFifteenMinutePriceIntervals {
                intervalPicker

                Button {
                    showsDisplayIntervalInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Price graph interval info")
            }
        }
        .padding(.leading, PricesLayout.statusLeadingPadding)
        .padding(.trailing, PricesLayout.graphTrailingPadding)
        .padding(.top, PricesLayout.statusTopPadding)
        .padding(.bottom, PricesLayout.statusBottomPadding)
        .alert("Price intervals", isPresented: $showsDisplayIntervalInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("15m shows every price point. 60m averages each hour and lets you press an hour to see its 15-minute prices.")
        }
    }

    private var intervalPicker: some View {
        Picker("Price graph interval", selection: $displayInterval) {
            ForEach(PriceGraphDisplayInterval.allCases) { interval in
                Text(interval.title)
                    .tag(interval)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 104)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        PricesView()
    }
}
