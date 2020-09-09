//
//  HourPriceInfoView.swift
//  AwattarApp
//
//  Created by Léon Becker on 09.09.20.
//

import SwiftUI

struct HourPriceInfoView: View {
    let priceDataPoint: AwattarDataPoint
    var numberFormatter: NumberFormatter
    
    var priceInMWh: String?
    var priceInkWh: String?
    
    init(priceDataPoint: AwattarDataPoint) {
        self.priceDataPoint = priceDataPoint
        
        numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        
        priceInMWh = numberFormatter.string(from: NSNumber(value: priceDataPoint.marketprice))
        priceInkWh = numberFormatter.string(from: NSNumber(value: (priceDataPoint.marketprice * 100) * 0.001)) // Price converted from mwh to kwh
    }
    
    var body: some View {
        if priceInkWh != nil && priceInMWh != nil {
            VStack(spacing: 60) {
                Image("awattarLogo")
                    .resizable()
                    .scaledToFit()

                HStack(spacing: 12) {
                    Image(systemName: "bolt")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.green)
                        .frame(width: 25, alignment: .center)
                    
                    Text("Strompreis: ")
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 10) {
                        HStack {
                            Text(priceInkWh!)
                            Text("Cent / kWh")
                        }
                        
                        HStack {
                            Text(priceInMWh!)
                            Text(priceDataPoint.unit)
                        }
                        
                    }
                    .foregroundColor(Color.white)
                    .padding(5)
                    .background(Color.gray)
                    .cornerRadius(5
                    )
                }
                
                Spacer()
            }
            .padding()
        }
        
    }
}

struct HourPriceInfoView_Previews: PreviewProvider {
    static var previews: some View {
        HourPriceInfoView(priceDataPoint: AwattarDataPoint(startTimestamp: 19384829, endTimestamp: 19484829, marketprice: 29.28, unit: "Eur/MWh"))
    }
}
