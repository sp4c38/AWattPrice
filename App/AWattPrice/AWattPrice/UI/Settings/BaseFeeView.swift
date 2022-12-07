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
    
    @State var baseFee: Double = 0
    @FocusState var isInputActive: Bool

    var body: some View {
        Form {
            Section(header: Text("Info").foregroundColor(.blue)) {
                Text("The base fee is added to all electricity prices within the entire AWattPrice app. This fee depends on your contract with aWATTar and may differ from other users.")
            }
            
            Section {
                VStack(alignment: .leading) {
                    Text("Base fee:")
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
                                        saveBaseFee()
                                    }) {
                                        Text("Done")
                                            .bold()
                                    }
                                }
                            }
                            .onSubmit(saveBaseFee)
                    
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
    
    func saveBaseFee() {
        currentSetting.changeBaseFee(to: baseFee)
    }
}

struct BaseFeeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BaseFeeView()
        }
    }
}
