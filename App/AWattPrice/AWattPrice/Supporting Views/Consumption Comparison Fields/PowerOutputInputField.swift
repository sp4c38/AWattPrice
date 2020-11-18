//
//  PowerOutputInputField.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.10.20.
//

import SwiftUI

/// Input field for the power output of the consumer
struct PowerOutputInputField: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    @EnvironmentObject var currentSetting: CurrentSetting
    
    let emptyFieldError: Bool
    let wrongInputError: Bool
    
    init(errorValues: [Int]) {
        if errorValues.contains(1) {
            emptyFieldError = true
            wrongInputError = false
        } else if errorValues.contains(2) {
            emptyFieldError = false
            wrongInputError = true
        } else {
            emptyFieldError = false
            wrongInputError = false
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("power")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            HStack {
                TextField("inKw", text: $cheapestHourManager.powerOutputString.animation())
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .padding(.trailing, 5)
                    .onChange(of: cheapestHourManager.powerOutputString) { newValue in
                        currentSetting.changeCheapestTimeLastPower(newLastPower: newValue.doubleValue ?? 0)
                    }
                
                if cheapestHourManager.powerOutputString != "" {
                    Text("kW")
                        .transition(.opacity)
                }
            }
            .padding(.leading, 17)
            .padding(.trailing, 14)
            .padding([.top, .bottom], 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke((emptyFieldError || wrongInputError) ? Color.red : Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706), lineWidth: 2)
            )
            
            if emptyFieldError {
                Text("emptyFieldError")
                    .font(.caption)
                    .foregroundColor(Color.red)
            }
            
            if wrongInputError {
                Text("wrongInputError")
                    .font(.caption)
                    .foregroundColor(Color.red)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if currentSetting.setting!.cheapestTimeLastPower != 0 {
                if let powerOutputString = currentSetting.setting!.cheapestTimeLastPower.priceString {
                    cheapestHourManager.powerOutputString = powerOutputString
                } else {
                    cheapestHourManager.powerOutputString = ""
                }
            } else {
                cheapestHourManager.powerOutputString = ""
            }
        }
    }
}

struct PowerOutputInputField_Previews: PreviewProvider {
    static var previews: some View {
        PowerOutputInputField(errorValues: [])
            .environmentObject(CheapestHourManager())
    }
}
