//
//  RegionAndVatSelection.swift
//  AWattPrice
//
//  Created by Léon Becker on 21.11.20.
//

import SwiftUI

struct RegionAndVatSelection: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var selectedRegion: Int = 0
    @State var pricesWithTaxIncluded = true
    
    @State var firstAppear = true
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text("settingsPage.region"),
            footer: Text("settingsPage.regionToGetPrices")
        ) {
            VStack(alignment: .leading, spacing: 20) {
                Picker(selection: $selectedRegion.animation(), label: Text("")) {
                    Text("settingsPage.region.germany")
                        .tag(0)
                    Text("settingsPage.region.austria")
                        .tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .ifTrue(firstAppear == false) { content in
                    content
                        .onChange(of: selectedRegion) { newRegionSelection in
                            currentSetting.changeRegionSelection(newValue: Int16(newRegionSelection))
                            
                            if newRegionSelection == 1 {
                                currentSetting.changeTaxSelection(newValue: false)
                            }
                        }
                }
                .onAppear {
                    selectedRegion = Int(currentSetting.entity!.regionSelection)
                    firstAppear = false
                }
                
                if selectedRegion == 0 {
                    HStack(spacing: 10) {
                        Text("settingsPage.priceWithVat")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                        
                        Toggle(isOn: $pricesWithTaxIncluded) {
                            
                        }
                        .labelsHidden()
                        .onAppear {
                            pricesWithTaxIncluded = currentSetting.entity!.pricesWithTaxIncluded
                            firstAppear = false
                        }
                        .ifTrue(firstAppear == false) { content in
                            content
                                .onChange(of: pricesWithTaxIncluded) { newValue in
                                    currentSetting.changeTaxSelection(newValue: newValue)
                                }
                        }
                    }
                }
            }
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
    }
}

struct RegionSelection_Previews: PreviewProvider {
    static var previews: some View {
        RegionAndVatSelection()
            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
