//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

class SelectedTaxSetting: ObservableObject {
    var taxOptions = [(0, "Mit Mehrwertsteuer"), (1, "Ohne Mehrwertsteuer")]
    @Published var selectedTaxOption = 0
}

struct ContentView: View {
    @EnvironmentObject var energyData: EnergyData
    @ObservedObject var selectedTaxSetting = SelectedTaxSetting()
    
    class ContentViewPreviewSourcesData: ObservableObject {
        @Published var energyData: SourcesData? = SourcesData(awattar: AwattarData(prices: [AwattarDataPoint(startTimestamp: 938292, endTimestamp: 738299, marketprice: 21.94, unit: ["Eur / MWh", "Eur / kWh"]), AwattarDataPoint(startTimestamp: 294992, endTimestamp: 299992, marketprice: 15.12, unit: ["Eur / MWh", "Eur / kWh"])], maxPrice: 21.97))
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
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Divider()
                    
                        Picker(selection: $selectedTaxSetting.selectedTaxOption, label: Text("Picker")) {
                            ForEach(selectedTaxSetting.taxOptions, id: \.0) { taxOption in
                                Text(taxOption.1).tag(taxOption.0)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.bottom, 5)
                        .padding(.leading, 16)
                        .padding(.trailing, 16)

                        Text("Preis pro kWh")
                            .font(.subheadline)
                            .padding(.leading, 10)

                        ForEach(energyData.energyData!.awattar.prices, id: \.startTimestamp) { price in
                            let startDate = Date(timeIntervalSince1970: TimeInterval(price.startTimestamp / 1000))
                            let endDate = Date(timeIntervalSince1970: TimeInterval(price.endTimestamp / 1000))

                            NavigationLink(destination: HourPriceInfoView(priceDataPoint: price)) {
                                VStack {
                                    ZStack(alignment: .trailing) {
                                        ZStack(alignment: .leading) {
                                            EnergyPriceGraph(awattarDataPoint: price, maxPrice: energyData.energyData!.awattar.maxPrice)
                                                .foregroundColor(Color(hue: 0.0673, saturation: 0.7155, brightness: 0.9373))
                                                .padding(.trailing, 20)

                                            
                                            if selectedTaxSetting.selectedTaxOption == 0 {
                                                // With tax
                                                
                                                Text(numberFormatter.string(from: NSNumber(value: (price.marketprice * 100 * 0.001 * 1.16)))!)
                                                    .padding(10)
                                                    .foregroundColor(Color.white)

                                            } else if selectedTaxSetting.selectedTaxOption == 1 {
                                                 // Without tax
                                                Text(numberFormatter.string(from: NSNumber(value: (price.marketprice * 100 * 0.001)))!)
                                                    .padding(10)
                                                    .foregroundColor(Color.white)
                                            }
                                        }

                                        HStack(spacing: 5) {
                                            Text(hourFormatter.string(from: startDate))
                                            Text("-")
                                            Text(hourFormatter.string(from: endDate))
                                        }
                                        .padding(3)
                                        .background(Color.white)
                                        .cornerRadius(4)
                                        .shadow(radius: 3)
                                        .padding(.trailing, 25)

                                    }
                                    .foregroundColor(Color.black)
                                    .animation(.easeInOut)
                                }
                            }
                        }
                    }
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
