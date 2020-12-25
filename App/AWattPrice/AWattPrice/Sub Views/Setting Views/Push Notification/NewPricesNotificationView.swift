//
//  NewPricesNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI

struct NewPricesNotificationView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var crtNotifiSettings: CurrentNotificationSetting
    
    @State var firstAppear = true
    @Binding var newPricesNotificationSelection: Bool
    
    init(_ newPricesNotificationSelection: Binding<Bool>) {
        self._newPricesNotificationSelection = newPricesNotificationSelection
    }
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text(""),
            footer: Text("Receive a notification as soon as there are new aWATTar prices available for the next day (mostly 14 o'clock, sometimes earlier).")
        ) {
            HStack {
                Text("New Prices available")
                
                Spacer()
                
                Toggle("", isOn: $newPricesNotificationSelection)
                    .labelsHidden()
                    .onAppear {
                        newPricesNotificationSelection = crtNotifiSettings.entity!.getNewPricesAvailableNotification
                        firstAppear = false
                    }
                    .ifTrue(firstAppear == false) { content in
                        content
                            .onChange(of: newPricesNotificationSelection) { newValue in
                                crtNotifiSettings.changeNewPricesAvailable(newValue: newValue)
                                crtNotifiSettings.changesAndStaged = true
                            }
                    }
            }
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
    }
}

struct NewPricesNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NewPricesNotificationView(.constant(true))
                .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
                .environmentObject(CurrentNotificationSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
        }
    }
}
