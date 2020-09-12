//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

class ContentViewPreviewSourcesData: ObservableObject {
    @Published var energyData: SourcesData? = SourcesData(awattar: AwattarData(prices: [AwattarDataPoint(startTimestamp: 938292, endTimestamp: 738299, marketprice: 20, unit: ["Eur / MWh", "Eur / kWh"]), AwattarDataPoint(startTimestamp: 294992, endTimestamp: 299992, marketprice: 15, unit: ["Eur / MWh", "Eur / kWh"]), AwattarDataPoint(startTimestamp: 494992, endTimestamp: 299992, marketprice: -10, unit: ["Eur / MWh", "Eur / kWh"])], minPrice: -10, maxPrice: 20))
}

struct ContentView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var energyData: EnergyData
    
    @State var settingIsPresented: Bool = false
    
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
            VStack {
                if energyData.energyData != nil {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            Divider()
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
                                                EnergyPriceGraph(awattarDataPoint: price, minPrice: energyData.energyData!.awattar.minPrice, maxPrice: energyData.energyData!.awattar.maxPrice)
                                                    .foregroundColor(Color(hue: 0.0673, saturation: 0.7155, brightness: 0.9373))
                                                    .padding(.trailing, 20)

                                                
//                                                if selectedTaxSetting.selectedTaxOption == 0 {
                                                    // With tax
                                                    Text(numberFormatter.string(from: NSNumber(value: (price.marketprice * 100 * 0.001 * 1.16)))!)
                                                        .padding(10)
                                                        .foregroundColor(Color.black)
                                                        .shadow(radius: 5)

//                                                } else if selectedTaxSetting.selectedTaxOption == 1 {
                                                    // Without tax
                                                    Text(numberFormatter.string(from: NSNumber(value: (price.marketprice * 100 * 0.001)))!)
                                                        .padding(10)
                                                        .foregroundColor(Color.white)
                                                        .shadow(radius: 5)
                                                    //    .animation(.easeInOut)
//                                                }
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
                                    }
                                }
                            }
                        }
                    }
                    
                } else {
                    VStack(spacing: 40) {
                        Spacer()
                        ProgressView("")
                        Spacer()
                    }
                }
            }
            .sheet(isPresented: $settingIsPresented) {
                SettingsPageView()
                    .environment(\.managedObjectContext, managedObjectContext)
            }
            .navigationBarTitle("Strompreis")
            .navigationBarItems(trailing:
                Button(action: {
                    settingIsPresented = true
                }) {
                    Image(systemName: "gear")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.blue)
                }
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
