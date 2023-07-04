//
//  PowerOutputInputField.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.10.20.
//

import Resolver
import SwiftUI

/// Input field for the power output of the consumer
struct PowerOutputInputField: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    @Injected var setting: SettingCoreData

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
                    .ifTrue(firstAppear == false) { content in
                        content
                            .onChange(of: cheapestHourManager.powerOutputString) { newValue in
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
