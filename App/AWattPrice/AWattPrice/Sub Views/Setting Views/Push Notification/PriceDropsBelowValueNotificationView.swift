//
//  NewPricesNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI

struct PriceDropsBelowValueNotificationView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var crtNotifiSettings: CurrentNotificationSetting
    
    @State var firstAppear = true
    @Binding var priceDropsBelowValueNotificationSelection: Bool
    
    init(_ priceDropsBelowValueNotificationSelection: Binding<Bool>) {
        self._priceDropsBelowValueNotificationSelection = priceDropsBelowValueNotificationSelection
    }
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text(""),
            footer: Text("notificationPage.notification.priceDropsBelowValue.description")
        ) {
            HStack {
                Text("notificationPage.notification.priceDropsBelowValue")
                
                Spacer()
                
                Toggle("", isOn: $priceDropsBelowValueNotificationSelection)
                    .labelsHidden()
                    .onAppear {
                        priceDropsBelowValueNotificationSelection = crtNotifiSettings.entity!.priceDropsBelowValueNotification
                        firstAppear = false
                    }
                    .ifTrue(firstAppear == false) { content in
                        content
                            .onChange(of: priceDropsBelowValueNotificationSelection) { newValue in
                                crtNotifiSettings.changePriceDropsBelowValueNotifications(newValue: newValue)
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
            PriceDropsBelowValueNotificationView(.constant(true))
                .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
                .environmentObject(CurrentNotificationSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
        }
    }
}
