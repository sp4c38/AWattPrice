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

    @State var firstAppear = true
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
                .onAppear {
                    pricesWithTaxIncluded = currentSetting.setting!.pricesWithTaxIncluded
                    firstAppear = false
                }
                .ifTrue(firstAppear == false) { content in
                    content
                        .onChange(of: pricesWithTaxIncluded) { newValue in
                            currentSetting.changeTaxSelection(newTaxSelection: newValue)
                        }
                }
            }
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
    }
}
