//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var settingIsPresented: Bool = false
    
    var hourFormatter: DateFormatter
    var numberFormatter: NumberFormatter
    
    init() {
        hourFormatter = DateFormatter()

        hourFormatter.locale = Locale(identifier: "de_DE")
        hourFormatter.timeStyle = .short
        
        numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = Locale(identifier: "de_DE")
        numberFormatter.currencySymbol = "ct"
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if awattarData.energyData != nil {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            Divider()
                            Text("Preis pro kWh")
                                .font(.subheadline)
                                .padding(.leading, 10)
                                .padding(.top, 8)
                                .padding(.bottom, 8)

                            ForEach(awattarData.energyData!.awattar.prices, id: \.startTimestamp) { price in
                                let startDate = Date(timeIntervalSince1970: TimeInterval(price.startTimestamp / 1000))
                                let endDate = Date(timeIntervalSince1970: TimeInterval(price.endTimestamp / 1000))

                                NavigationLink(destination: HourPriceInfoView(priceDataPoint: price)) {
                                    VStack(spacing: 0) {
                                        ZStack(alignment: .trailing) {
                                            ZStack(alignment: .leading) {
                                                EnergyPriceGraph(awattarDataPoint: price, minPrice: awattarData.energyData!.awattar.minPrice, maxPrice: awattarData.energyData!.awattar.maxPrice)
                                                    .foregroundColor(Color(hue: 0.0673, saturation: 0.7155, brightness: 0.9373))
                                                
                                                if currentSetting.setting!.pricesWithTaxIncluded {
                                                    // With tax
                                                    Text(numberFormatter.string(from: NSNumber(value: (price.marketprice * 100 * 0.001 * 1.16)))!)
                                                        .padding(10)
                                                        .foregroundColor((colorScheme == .dark) ? Color.white : Color.black)
                                                        .shadow(radius: 5)

                                                } else if !currentSetting.setting!.pricesWithTaxIncluded {
                                                    // Without tax
                                                    Text(numberFormatter.string(from: NSNumber(value: (price.marketprice * 100 * 0.001)))!)
                                                        .padding(10)
                                                        .foregroundColor((colorScheme == .dark) ? Color.white : Color.black)
                                                        .shadow(radius: 5)
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
                                            .padding(.leading, 15)
                                        }
                                        .foregroundColor(Color.black)
                                    }
                                }
                            }
                        }
                        .padding()
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
        .onAppear {
            currentSetting.setSetting(managedObjectContext: managedObjectContext)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting())
    }
}
