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
    
    @GestureState var isPressed = false
    
    var hourFormatter: DateFormatter
    var numberFormatter: NumberFormatter
    
    init() {
        hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "H"
        
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
                        LazyVStack(alignment: .leading, spacing: 0) { // new SwiftUI feature
                                                                      // only creates the views in the VStack if they are really on the screen
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
                                                    .shadow(radius: 1)
                                                    .animation(.easeInOut)
                                            }

                                            HStack(spacing: 5) {
                                                Text(hourFormatter.string(from: startDate))
                                                Text("-")
                                                Text(hourFormatter.string(from: endDate))
                                                Text("Uhr")
                                            }
                                            .padding(3)
                                            .background(Color.white)
                                            .cornerRadius(4)
                                            .shadow(radius: 3)
                                            .padding(.trailing, 25)
                                            .padding(.leading, 15)
                                            .padding(5)
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
