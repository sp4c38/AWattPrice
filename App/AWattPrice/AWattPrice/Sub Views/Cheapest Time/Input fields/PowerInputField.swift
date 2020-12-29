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
    @EnvironmentObject var keyboardObserver: KeyboardObserver
    
    @State var firstAppear = true
    
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
    
    func setPowerOutputString() {
        if currentSetting.entity!.cheapestTimeLastPower != 0 {
            if let powerOutputString = currentSetting.entity!.cheapestTimeLastPower.priceString {
                cheapestHourManager.powerOutputString = powerOutputString
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("general.power")
                    .font(.title3)
                    .bold()
                Spacer()
            }

            HStack {
                DecimalTextFieldWithDoneButton(text: $cheapestHourManager.powerOutputString.animation(), placeholder: "general.inKw".localized())
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 5)
                    .ifTrue(firstAppear == false) { content in
                        content
                            .onChange(of: cheapestHourManager.powerOutputString) { newValue in
                                currentSetting.changeCheapestTimeLastPower(newValue: newValue.doubleValue ?? 0)
                                if let energyUsageString = (newValue.doubleValue ?? 0).priceString {
                                    cheapestHourManager.powerOutputString = energyUsageString
                                }
                            }
                    }
                    .onAppear {
                        setPowerOutputString()
                        firstAppear = false
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
                Text("cheapestPricePage.emptyFieldError")
                    .font(.caption)
                    .foregroundColor(Color.red)
            }
            
            if wrongInputError {
                Text("cheapestPricePage.wrongInputError")
                    .font(.caption)
                    .foregroundColor(Color.red)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct PowerOutputInputField_Previews: PreviewProvider {
    static var previews: some View {
        PowerOutputInputField(errorValues: [])
            .environmentObject(CheapestHourManager())
    }
}
