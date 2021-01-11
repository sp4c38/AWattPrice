//
//  NewPricesNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import Combine
import SwiftUI

struct PriceDropsBelowValueNotificationInfoView: View {
    let completeExtraText: Text

    init() {
        completeExtraText = Text("notificationPage.notification.priceDropsBelowValue.description.extra.pt1") +
            Text("notificationPage.notification.priceDropsBelowValue.description.extra.pt2").fontWeight(.heavy) +
            Text("notificationPage.notification.priceDropsBelowValue.description.extra.pt3") +
            Text("notificationPage.notification.priceDropsBelowValue.description.extra.pt4").fontWeight(.heavy) +
            Text("notificationPage.notification.priceDropsBelowValue.description.extra.pt5")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            
            completeExtraText
                .font(.footnote)
            
            Text("notificationPage.notification.priceDropsBelowValue.description.hint")
                .font(.caption)
                .lineSpacing(2)
                .foregroundColor(Color.blue)
        }
    }
}

struct PriceDropsBelowValueNotificationInputField: View {
    @Environment(\.keyboardObserver) var keyboardObserver

    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    @EnvironmentObject var currentSetting: CurrentSetting

    @State var keyboardCurrentlyClosed: Bool = true

    @Binding var priceBelowValue: String

    init(_ priceBelowValue: Binding<String>) {
        _priceBelowValue = priceBelowValue
    }

    var body: some View {
        HStack {
            NumberField(text: $priceBelowValue, placeholder: "general.cent.long".localized(), plusMinusButton: true, withDecimalSeperator: false)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: priceBelowValue) { newValue in
                    var newIntegerValue: Int = 0
                    if let newConvertedIntegerValue = newValue.integerValue {
                        newIntegerValue = newConvertedIntegerValue
                    }
                    crtNotifiSetting.changePriceBelowValue(newValue: newIntegerValue)
                    priceBelowValue = newIntegerValue.priceString ?? ""

                    if keyboardCurrentlyClosed {
                        crtNotifiSetting.pushNotificationUpdateManager.backgroundNotificationUpdate(currentSetting: currentSetting, crtNotifiSetting: crtNotifiSetting)
                    }
                }

            Text("general.centPerKwh")
                .transition(.opacity)
        }
        .onReceive(keyboardObserver.keyboardHeight) { newKeyboardHeight in
            if newKeyboardHeight == 0 {
                self.keyboardCurrentlyClosed = true
            } else {
                self.keyboardCurrentlyClosed = false
            }
        }
    }
}

struct PriceDropsBelowValueNotificationToggleView: View {
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    @EnvironmentObject var currentSetting: CurrentSetting

    @Binding var priceDropsBelowValueNotificationSelection: Bool

    init(
        _ selection: Binding<Bool>
    ) {
        _priceDropsBelowValueNotificationSelection = selection
    }

    var body: some View {
        HStack {
            Text("notificationPage.notification.priceDropsBelowValue")
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Spacer()

            Toggle("", isOn: $priceDropsBelowValueNotificationSelection.animation())
                .labelsHidden()
                .onChange(of: priceDropsBelowValueNotificationSelection) { newValue in
                    crtNotifiSetting.changePriceDropsBelowValueNotifications(newValue: newValue)
                    crtNotifiSetting.changesAndStaged = true
                    crtNotifiSetting.pushNotificationUpdateManager.backgroundNotificationUpdate(
                        currentSetting: currentSetting,
                        crtNotifiSetting: crtNotifiSetting
                    )
                }
        }
    }
}

struct PriceDropsBelowValueNotificationSubView: View {
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var currentSetting: CurrentSetting

    @ObservedObject var crtNotifiSetting: CurrentNotificationSetting

    @State var initialAppearFinished: Bool? = false
    @State var keyboardCurrentlyClosed = false
    @State var priceDropsBelowValueNotificationSelection = false
    @State var priceBelowValue: String = ""
    
    let showHeader: Bool

    init(crtNotifiSetting: CurrentNotificationSetting, showHeader showHeaderValue: Bool = false) {
        showHeader = showHeaderValue
        
        _crtNotifiSetting = ObservedObject(initialValue: crtNotifiSetting)
        _priceDropsBelowValueNotificationSelection = State(initialValue: self.crtNotifiSetting.entity!.priceDropsBelowValueNotification)
        _priceBelowValue = State(initialValue: self.crtNotifiSetting.entity!.priceBelowValue.priceString ?? "")
    }

    var body: some View {
        VStack {
            CustomInsetGroupedListItem(
                header: showHeader ? Text("general.notifications") : nil,
                footer: nil
            ) {
                VStack(alignment: .leading, spacing: 20) {
                    PriceDropsBelowValueNotificationToggleView(
                        self.$priceDropsBelowValueNotificationSelection
                    )

                    if priceDropsBelowValueNotificationSelection {
                        HStack {
                            PriceDropsBelowValueNotificationInputField(
                                self.$priceBelowValue
                            )
                        }
                        .padding(.leading, 17)
                        .padding(.trailing, 14)
                        .padding([.top, .bottom], 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    Color(
                                        hue: 0.0000,
                                        saturation: 0.0000,
                                        brightness: 0.8706
                                    ),
                                    lineWidth: 2
                                )
                        )
                    }

                    if priceDropsBelowValueNotificationSelection {
                        PriceDropsBelowValueNotificationInfoView()
                    }
                }
            }
        }
    }
}

struct PriceDropsBelowValueNotificationView: View {
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    
    let showHeader: Bool
    
    init(showHeader showHeaderValue: Bool = false) {
        showHeader = showHeaderValue
    }

    var body: some View {
        PriceDropsBelowValueNotificationSubView(crtNotifiSetting: crtNotifiSetting, showHeader: showHeader)
    }
}

struct NewPricesNotificationView_Previews: PreviewProvider {
    static var previews: some View {
//        PriceDropsBelowValueNotificationInfoView()
//            .padding(.leading, 17)
//            .padding(.trailing, 14)
//            .padding([.top, .bottom], 7)

        NavigationView {
            PriceDropsBelowValueNotificationView()
                .environmentObject(CurrentNotificationSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
                .preferredColorScheme(.dark)
        }
    }
}
