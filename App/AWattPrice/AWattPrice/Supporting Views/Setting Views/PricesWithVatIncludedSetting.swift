//
//  PricesWithVatIncludedSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 29.10.20.
//

import SwiftUI

struct PricesWithVatIncludedSetting: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var pricesWithTaxIncluded = true
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text("price")
        ) {
            HStack(spacing: 10) {
                Text("priceWithVat")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Toggle(isOn: $pricesWithTaxIncluded) {
                    
                }
                .labelsHidden()
                .onChange(of: pricesWithTaxIncluded) { newValue in
                    currentSetting.changeTaxSelection(newTaxSelection: newValue)
                }
            }
        }
        .onAppear {
            pricesWithTaxIncluded = currentSetting.setting!.pricesWithTaxIncluded
        }
    }
}
