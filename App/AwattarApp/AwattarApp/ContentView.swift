//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var energyData: EnergyData
//    let dateFormatter: DateFormatter
    
    init() {
//        self.dateFormatter = DateFormatter()
//        self.dateFormatter.dateFormat
    }
    
    var body: some View {
        VStack {
            if energyData.energyData != nil {
                List(energyData.energyData!.awattar.prices, id: \.startTimestamp) { price in
                    let date = Date(timeIntervalSince1970: TimeInterval(price.startTimestamp))
                    Text(date.description)
                    Text(price.unit)
                }
            }
            
            Text("Hello")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
