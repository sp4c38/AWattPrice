//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

class EnergyCalculator: ObservableObject {
    @Published var energyUsageInput = ""
    @Published var timeOfUsageInput = ""
    
    @Published var energyUsage = Float(0)
    @Published var timeOfUsage = Float(0)
    
    func setValues() {
        self.energyUsage = Float(self.energyUsageInput) ?? 0
        self.timeOfUsage = Float(self.timeOfUsageInput) ?? 0
    }
    
    func calculateRealPrice(baseEnergyPrice: Float) {
        
    }
}

struct ConsumptionComparatorView: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    
    @ObservedObject var energyCalculator = EnergyCalculator()
    
    var body: some View {
        VStack(alignment: .center) {
            if currentSetting.setting != nil {
                Text("Bestmögliche Zeit für Verbrauch finden")
                    .bold()
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Deine angegebene Grundgebühr: ")
                        Spacer()
                        HStack(spacing: 5) {
                            Text(String(currentSetting.setting!.awattarProfileBasicCharge))
                            Text("Cent pro kWh")
                        }
                    }
                    
                    HStack {
                        Text("Dein angegebener Strompreis: ")
                        Spacer()
                        HStack(spacing: 5) {
                            Text(String(currentSetting.setting!.awattarEnergyPrice))
                            Text("Cent pro kWh")
                        }
                    }
                    
                    TextField("Verbrauch", text: $energyCalculator.energyUsageInput)
                        .keyboardType(.decimalPad)
                    TextField("Zeit des Verbrauches", text: $energyCalculator.timeOfUsageInput)
                        .keyboardType(.decimalPad)
                    
                    
                    Button(action: {
                        energyCalculator.setValues()
                    }) {
                        Text("Berechnen")
                    }
                }
                
                Spacer()
            } else {
                Text("Fehler mit Einstellungen")
            }
        }
        .padding()
    }
}

struct ConsumptionComparatorView_Previews: PreviewProvider {
    static var previews: some View {
        ConsumptionComparatorView()
            .environmentObject(CurrentSetting())
    }
}
