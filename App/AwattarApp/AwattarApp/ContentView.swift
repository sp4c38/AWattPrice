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
            VStack {
                if energyData.energyData != nil {
                    List(energyData.energyData!.awattar.prices, id: \.startTimestamp) { price in
                        let startDate = Date(timeIntervalSince1970: TimeInterval(price.startTimestamp / 1000))
                        let endDate = Date(timeIntervalSince1970: TimeInterval(price.endTimestamp / 1000))
                        
                        HStack(spacing: 5) {
                            EnergyPriceGraph(awattarDataPoint: price)
                            
                            Spacer()
                            
                            Text(hourFormatter.string(from: startDate))
                            Text("-")
                            Text(hourFormatter.string(from: endDate))
                        }
                        .foregroundColor(Color.gray)
                    }
                }
                
                Text("Hello")
            }
        }
        
//        if energyData.energyData != nil {
//            if energyData.energyData!.awattar.prices.count >= 1 {
//                navView.navigationBarTitle(dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(energyData.energyData!.awattar.prices[0].startTimestamp))))
//            }
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
