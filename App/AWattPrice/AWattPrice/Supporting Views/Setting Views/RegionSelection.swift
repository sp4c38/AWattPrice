//
//  RegionSelection.swift
//  AWattPrice
//
//  Created by Léon Becker on 21.11.20.
//

import SwiftUI

struct RegionSelection: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var selectedRegion: Int = 0
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text("region"),
            footer: Text("Select the region for which you would like to get aWATTar prices.")
        ) {
            VStack(alignment: .leading) {
                Picker(selection: $selectedRegion, label: Text("")) {
                    Text("🇩🇪 Germany")
                        .tag(0)
                    Text("🇦🇹 Austria")
                        .tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedRegion) { newRegionSelection in
                    currentSetting.changeRegionSelection(newRegionSelection: Int16(newRegionSelection))
                }
            }
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
        .onAppear {
            selectedRegion = Int(currentSetting.setting!.regionSelection)
        }
    }
}

struct RegionSelection_Previews: PreviewProvider {
    static var previews: some View {
        RegionSelection()
    }
}
