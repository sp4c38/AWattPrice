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
    
    @State var hourPriceInfoViewNavControl: Int? = 0
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
            if awattarData.energyData != nil {
                ScrollView(showsIndicators: true) {
                    Divider()
                    
                    HStack {
                        Text("pricePerKwh")
                            .font(.subheadline)
                            .padding(.leading, 10)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        
                        Spacer()
                        
                        Text("hourOfDay")
                            .padding(.trailing, 25)
                    }
                    
                    EnergyPriceGraph()
                        .frame(height: 2000)
//                        .foregroundColor(Color.blue)
//                        .shadow(radius: 1)
//                        .animation(.easeInOut)
//                        .padding(.trailing, 35)

//                    ForEach(awattarData.energyData!.awattar.prices, id: \.startTimestamp) { price in
//                        let startDate = Date(timeIntervalSince1970: TimeInterval(price.startTimestamp / 1000))
//                        let endDate = Date(timeIntervalSince1970: TimeInterval(price.endTimestamp / 1000))
//
//                        Button(action: {
//                            hourPriceInfoViewNavControl = 1
//                        }) {
//                            ZStack(alignment: .trailing) {
//                                HStack(spacing: 5) {
//                                    Text(hourFormatter.string(from: startDate))
//                                    Text("-")
//                                    Text(hourFormatter.string(from: endDate))
//                                }
//                                .foregroundColor(Color.black)
//                                .padding(.top, 1.5)
//                                .padding(.bottom, 1.5)
//                                .padding(.leading, 5)
//                                .padding(.trailing, 5)
//                                .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color(hue: 0.6111, saturation: 0.0276, brightness: 0.8510)]), startPoint: .topLeading, endPoint: .bottomTrailing))
//                                .cornerRadius(4)
//                                .shadow(radius: 2)
//                                .padding(.trailing, 25)
//                                .padding(.leading, 10)
//                                .padding(.top, 5)
//                                .padding(.bottom, 5)
//                            }
//                        }
//                    }
                }
                .sheet(isPresented: $settingIsPresented) {
                    SettingsPageView()
                        .environment(\.managedObjectContext, managedObjectContext)
                }
                .navigationBarTitle("elecPrice")
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
            } else {
                VStack(spacing: 40) {
                    Spacer()
                    ProgressView("")
                    Spacer()
                }
            }
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
