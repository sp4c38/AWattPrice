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
    @EnvironmentObject var setting: SettingCoreData

    @State var firstAppear = true
    @FocusState private var fieldIsFocused: Bool
    
    let emptyFieldError: Bool
    let wrongInputError: Bool
    let onFocusChange: (Bool) -> Void

    init(errorValues: [Int], isFocused: Binding<Bool> = .constant(false)) {
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
        self.onFocusChange = { newValue in
            isFocused.wrappedValue = newValue
        }
    }

    func setPowerOutputString() {
        if setting.entity.cheapestTimeLastPower != 0 {
            if let powerOutputString = setting.entity.cheapestTimeLastPower.priceString {
                cheapestHourManager.powerOutputString = powerOutputString
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Power")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                Spacer()
            }

            HStack {
                NumberField(text: $cheapestHourManager.powerOutputString.animation(), placeholder: "in kW".localized(), withDecimalSeperator: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 5)
                    .focused($fieldIsFocused)
                    .onChange(of: fieldIsFocused) { newValue in
                        onFocusChange(newValue)
                    }
                    .onChange(of: cheapestHourManager.powerOutputString) { newValue in
                        if !firstAppear {
                            setting.changeSetting { $0.entity.cheapestTimeLastPower = newValue.doubleValue ?? 0 }
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
            .modifier(GeneralInputView(markedRed: emptyFieldError || wrongInputError))

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
