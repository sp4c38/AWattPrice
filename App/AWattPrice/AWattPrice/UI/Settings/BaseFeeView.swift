//
//  BaseFeeView.swift
//  AWattPrice
//
//  Created by Léon Becker on 02.12.22.
//

import Resolver
import SwiftUI

struct BaseFeeView: View {
    @Injected var currentSetting: CurrentSetting
    @Injected var energyDataController: EnergyDataController
    
    @State var baseFee: Double = 0
    @FocusState var isInputActive: Bool

    var body: some View {
        Form {
            Section(header: Text("Info").foregroundColor(.blue)) {
                Text("baseFee.infoText")
            }
            
            Section {
                VStack(alignment: .leading) {
                    Text("Base fee (incl. VAT):")
                        .textCase(.uppercase)
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    HStack {
                        TextField("", value: $baseFee, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($isInputActive)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button(action: {
                                        isInputActive = false
                                        updateBaseFee()
                                    }) {
                                        Text("Done")
                                            .bold()
                                    }
                                }
                            }
                            .onSubmit(updateBaseFee)
                    
                        Text("Cent per kWh")
                    }
                    .modifier(GeneralInputView(markedRed: false))
                }
            }
        }
        .navigationTitle("Base Fee")
        .onAppear {
            baseFee = currentSetting.entity!.baseFee
        }
    }
    
    func updateBaseFee() {
        currentSetting.changeBaseFee(to: baseFee)
        energyDataController.energyData?.computeValues()
    }
}

struct BaseFeeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BaseFeeView()
        }
    }
}
