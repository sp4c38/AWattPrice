//
//  EnergyUsageInputField.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.10.20.
//

import SwiftUI

/// Input field for the energy usage which the consumer shall consume
struct EnergyUsageInputField: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    @EnvironmentObject var currentSetting: CurrentSetting

    @State var firstAppear = true

    let emptyFieldError: Bool
    let wrongInputError: Bool

    init(errorValues: [Int]) {
        if errorValues.contains(3) {
            emptyFieldError = true
            wrongInputError = false
        } else if errorValues.contains(4) {
            emptyFieldError = false
            wrongInputError = true
        } else {
            emptyFieldError = false
            wrongInputError = false
        }
    }

    func setEnergyUsageString() {
        if currentSetting.entity!.cheapestTimeLastConsumption != 0 {
            if let energyUsageString = currentSetting.entity!.cheapestTimeLastConsumption.priceString {
                cheapestHourManager.energyUsageString = energyUsageString
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("cheapestPricePage.totalConsumption")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                Spacer()
            }

            HStack {
                NumberField(text: $cheapestHourManager.energyUsageString.animation(), placeholder: "general.inKwh".localized(), withDecimalSeperator: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 5)
                    .ifTrue(firstAppear == false) { content in
                        content
                            .onChange(of: cheapestHourManager.energyUsageString) { newValue in
                                currentSetting.changeCheapestTimeLastConsumption(newValue: newValue.doubleValue ?? 0)
                                if let energyUsageString = (newValue.doubleValue ?? 0).priceString {
                                    cheapestHourManager.energyUsageString = energyUsageString
                                }
                            }
                    }
                    .onAppear {
                        setEnergyUsageString()
                        firstAppear = false
                    }

                if cheapestHourManager.energyUsageString != "" {
                    Text("kWh")
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

struct EnergyUsageField_Previews: PreviewProvider {
    static var previews: some View {
        EnergyUsageInputField(errorValues: [])
            .environmentObject(CheapestHourManager())
    }
}
