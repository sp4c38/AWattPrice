//
//  NewPricesNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import Combine
import SwiftUI

struct PriceDropsBelowValueNotificationInfoView: View {
    let completeExtraTextLineTwo: Text

    init() {
        completeExtraTextLineTwo =
            Text("notificationPage.notification.priceDropsBelowValue.description.firstLine.pt1")
                + Text("notificationPage.notification.priceDropsBelowValue.description.firstLine.pt2")
                .fontWeight(.heavy)
                + Text("notificationPage.notification.priceDropsBelowValue.description.firstLine.pt3")
                + Text("notificationPage.notification.priceDropsBelowValue.description.firstLine.pt4")
                .fontWeight(.heavy)
                + Text("notificationPage.notification.priceDropsBelowValue.description.firstLine.pt5")
                + Text("notificationPage.notification.priceDropsBelowValue.description.firstLine.pt6")
                .fontWeight(.heavy)
                + Text("notificationPage.notification.priceDropsBelowValue.description.firstLine.pt7")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                completeExtraTextLineTwo
                    .foregroundColor(.blue)
            }
            .font(.caption)
            .lineSpacing(2)
        }
    }
}

struct PriceDropsBelowValueNotificationSubView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.keyboardObserver) var keyboardObserver

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
                    toggleView

                    if priceDropsBelowValueNotificationSelection {
                        wishPriceInputField
                    }

                    if priceDropsBelowValueNotificationSelection {
                        PriceDropsBelowValueNotificationInfoView()
                    }
                }
            }
        }
    }
}

extension PriceDropsBelowValueNotificationSubView {
    var toggleView: some View {
        HStack {
            Text("notificationPage.notification.priceDropsBelowValue")
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Spacer()

            Toggle("", isOn: $priceDropsBelowValueNotificationSelection.animation())
                .labelsHidden()
                .onChange(of: priceDropsBelowValueNotificationSelection) { newValue in
                    crtNotifiSetting.changePriceDropsBelowValueNotifications(to: newValue)
                    crtNotifiSetting.changesAndStaged = true
                    crtNotifiSetting.pushNotificationUpdateManager.backgroundNotificationUpdate(
                        currentSetting,
                        crtNotifiSetting
                    )
                }
        }
    }
}

extension PriceDropsBelowValueNotificationSubView {
    var wishPriceInputField: some View {
        VStack(alignment: .leading) {
            Text("notificationPage.notification.priceDropsBelowValue.wishPrice")
                .textCase(.uppercase)
                .foregroundColor(.gray)
                .font(.caption)

            HStack {
                NumberField(text: $priceBelowValue, placeholder: "general.cent.long".localized(), plusMinusButton: true, withDecimalSeperator: false)
                    .fixedSize(horizontal: false, vertical: true)
                    .onChange(of: priceBelowValue) { newValue in
                        var newIntegerValue: Int = 0
                        if let newConvertedIntegerValue = newValue.integerValue {
                            newIntegerValue = newConvertedIntegerValue
                        }
                        crtNotifiSetting.changePriceBelowValue(to: newIntegerValue)
                        priceBelowValue = newIntegerValue.priceString ?? ""

                        if keyboardCurrentlyClosed {
                            crtNotifiSetting.pushNotificationUpdateManager.backgroundNotificationUpdate(currentSetting, crtNotifiSetting)
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
            .modifier(GeneralInputView(markedRed: false))
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
                .environmentObject(
                    CurrentNotificationSetting(
                        backendComm: BackendCommunicator(),
                        managedObjectContext: PersistenceManager().persistentContainer.viewContext
                    )
                )
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "de"))
        }
    }
}
