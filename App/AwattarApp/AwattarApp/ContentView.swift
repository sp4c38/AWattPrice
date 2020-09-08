//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var energyData: EnergyData
    var dateFormatter: DateFormatter
    var hourFormatter: DateFormatter
    
    init() {
        dateFormatter = DateFormatter()
        hourFormatter = DateFormatter()
        
        dateFormatter.locale = Locale(identifier: "de_DE")
        dateFormatter.dateStyle = .full
        hourFormatter.locale = Locale(identifier: "de_DE")
        
//        dateFormatter.setLocalizedDateFormatFromTemplate("dd.MM.yyyy")
        hourFormatter.setLocalizedDateFormatFromTemplate("HH-mm")
    }
    
    var body: some View {
        NavigationView {
            if energyData.energyData != nil {
                ScrollView(showsIndicators: false) {
                    VStack {
                        ForEach(energyData.energyData!.awattar.prices, id: \.startTimestamp) { price in
                            let startDate = Date(timeIntervalSince1970: TimeInterval(price.startTimestamp / 1000))
                            let endDate = Date(timeIntervalSince1970: TimeInterval(price.endTimestamp / 1000))
                            
                            HStack(spacing: 10) {
                                EnergyPriceGraph(awattarDataPoint: price, maxPrice: energyData.energyData!.awattar.maxPrice)
                                    .foregroundColor(Color(hue: 0.0673, saturation: 0.7155, brightness: 0.9373))
                                
                                Spacer()
                                
                                HStack(spacing: 5) {
                                    Text(hourFormatter.string(from: startDate))
                                    Text("-")
                                    Text(hourFormatter.string(from: endDate))
                                }
                                .foregroundColor(Color.gray)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
                .navigationBarTitle("Strompreis")
                .animation(.easeInOut)
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
