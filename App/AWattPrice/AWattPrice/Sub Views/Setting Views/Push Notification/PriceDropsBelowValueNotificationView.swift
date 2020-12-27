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
    
    @State var firstAppearToggle = true
    @State var textFieldTextSet = false
    @State var priceBelowValue: String = ""
    @State var priceDropsBelowValueNotificationSelection: Bool = false
    
    func getPriceBelowValueCentString(value: Double) -> String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
        
        if let result = numberFormatter.string(from: NSNumber(value: value)) {
            return result
        } else {
            return nil
        }
    }
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text(""),
            footer: Text("notificationPage.notification.priceDropsBelowValue.description")
        ) {
            VStack(spacing: 20) {
                HStack {
                    Text("notificationPage.notification.priceDropsBelowValue")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    Toggle("", isOn: $priceDropsBelowValueNotificationSelection.animation())
                        .labelsHidden()
                        .onAppear {
                            priceDropsBelowValueNotificationSelection = crtNotifiSettings.entity!.priceDropsBelowValueNotification
                            firstAppearToggle = false
                        }
                        .ifTrue(firstAppearToggle == false) { content in
                            content
                                .onChange(of: priceDropsBelowValueNotificationSelection) { newValue in
                                    crtNotifiSettings.changePriceDropsBelowValueNotifications(newValue: newValue)
                                    crtNotifiSettings.changesAndStaged = true
                                }
                        }
                }
                
                if priceDropsBelowValueNotificationSelection && textFieldTextSet {
                    HStack {
                        DecimalTextFieldWithDoneButton(text: $priceBelowValue, placeholder: "general.cent.long".localized(), plusMinusButton: true)
                            .fixedSize(horizontal: false, vertical: true)
                            .onChange(of: priceBelowValue) { newValue in
                                var newDoubleValue: Double = 0
                                if let newConvertedDoubleValue = newValue.doubleValue {
                                    newDoubleValue = (newConvertedDoubleValue * 100).rounded() / 100
                                }
                                crtNotifiSettings.changePriceBelowValue(newValue: newDoubleValue)
                                priceBelowValue = getPriceBelowValueCentString(value: newDoubleValue) ?? ""
                                crtNotifiSettings.changesAndStaged = true
                            }
                        
                        if priceBelowValue != "" {
                            Text("general.cent.short")
                                .transition(.opacity)
                        }
                    }
                    .padding(.leading, 17)
                    .padding(.trailing, 14)
                    .padding([.top, .bottom], 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706), lineWidth: 2)
                    )
                }
            }
            .padding([.top, .bottom], 2)
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
        .onAppear {
            self.priceBelowValue = getPriceBelowValueCentString(value: crtNotifiSettings.entity!.priceBelowValue) ?? ""
            self.textFieldTextSet = true
        }
    }
}

struct NewPricesNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PriceDropsBelowValueNotificationView()
                .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
                .environmentObject(CurrentNotificationSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
        }
    }
}
