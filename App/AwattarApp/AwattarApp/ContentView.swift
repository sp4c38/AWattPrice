//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var energyData: EnergyData
    
    class ContentViewPreviewSourcesData: ObservableObject {
        @Published var energyData: SourcesData? = SourcesData(awattar: AwattarData(prices: [AwattarDataPoint(startTimestamp: 938292, endTimestamp: 738299, marketprice: 20, unit: ["Eur / MWh", "Eur / kWh"]), AwattarDataPoint(startTimestamp: 294992, endTimestamp: 299992, marketprice: 10, unit: ["Eur / MWh", "Eur / kWh"])], maxPrice: 20))
    }
    
//    var energyData = ContentViewPreviewSourcesData()
    var hourFormatter: DateFormatter
    var numberFormatter: NumberFormatter
    
    init() {
        hourFormatter = DateFormatter()

        hourFormatter.locale = Locale(identifier: "de_DE")
        hourFormatter.timeStyle = .short
        
        numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "de_DE")
        numberFormatter.numberStyle = .currency
    }
    
    var body: some View {
        NavigationView {
            if energyData.energyData != nil {

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(energyData.energyData!.awattar.prices, id: \.startTimestamp) { price in
                            NavigationLink(destination: HourPriceInfoView(priceDataPoint: price)) {
                                let startDate = Date(timeIntervalSince1970: TimeInterval(price.startTimestamp / 1000))
                                let endDate = Date(timeIntervalSince1970: TimeInterval(price.endTimestamp / 1000))
                                let priceString = numberFormatter.string(from: NSNumber(value: price.marketprice))
                                
                                if priceString != nil {
                                    ZStack(alignment: .trailing) {
                                        ZStack(alignment: .leading) {
                                            EnergyPriceGraph(awattarDataPoint: price, maxPrice: energyData.energyData!.awattar.maxPrice)
                                                .foregroundColor(Color(hue: 0.0673, saturation: 0.7155, brightness: 0.9373))
                                            
                                            Text(priceString!)
                                                .padding(10)
                                                .foregroundColor(Color.white)
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 5) {
                                            Text(hourFormatter.string(from: startDate))
                                            Text("-")
                                            Text(hourFormatter.string(from: endDate))
                                        }
                                        .foregroundColor(Color.black)
                                        .opacity(0.5)
                                        .padding(.trailing, 20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                }
                .navigationBarTitle("Strompreis")
                
            } else {
                VStack(spacing: 40) {
                    Spacer()
                    
                    Text("Daten werden geladen")
                        .font(.title2)
                    
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundColor(Color.green)
                    
                    Spacer()
                }
                .navigationBarTitle("Strompreis")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
    }
}
