//
//  PushNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI

struct NewPricesNotificationView: View {
    @Environment(\.colorScheme) var colorScheme
    
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
            }
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
    }
}

struct PushNotificationView: View {
    @State var newPricesNotificationSelection: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            CustomInsetGroupedList {
                NewPricesNotificationView($newPricesNotificationSelection)
            }
        }
        .navigationTitle("Notifications")
    }
}

struct PushNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PushNotificationView()
        }
    }
}
