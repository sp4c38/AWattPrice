//
//  PriceBelowNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import Combine
import Resolver
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

class PriceBelowNotificationViewModel: ObservableObject {
    @Injected var currentSetting: CurrentSetting
    @ObservedObject var notificationSetting: CurrentNotificationSetting = Resolver.resolve()
    @ObservedObject var notificationService: NotificationService = Resolver.resolve()

    @Published var notificationIsEnabled: Bool = false
    @Published var priceBelowValue: String = ""
    
    var cancellables = [AnyCancellable]()

    init() {
        notificationIsEnabled = notificationSetting.entity!.priceDropsBelowValueNotification
        priceBelowValue = notificationSetting.entity!.priceBelowValue.priceString ?? ""
        
        $notificationIsEnabled.dropFirst().sink(receiveValue: priceBelowNotificationToggled).store(in: &cancellables)
        $priceBelowValue.dropFirst().sink(receiveValue: updateWishPrice).store(in: &cancellables)
    }
    
    func priceBelowNotificationToggled(to newSelection: Bool) {
        guard newSelection != self.notificationSetting.entity!.priceDropsBelowValueNotification else { return }
        
        var notificationConfiguration = NotificationConfiguration.create(nil, currentSetting, notificationSetting)
        notificationConfiguration.notifications.priceBelow.active = newSelection
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, skipWantNotificationCheck: true, uploadFinished: {
            self.notificationSetting.changePriceDropsBelowValueNotifications(to: newSelection)
        }, uploadError: { DispatchQueue.main.async { self.notificationIsEnabled = self.notificationSetting.entity!.priceDropsBelowValueNotification } })
    }
    
    func updateWishPrice(to newWishPriceString: String) {
        guard let newWishPrice = newWishPriceString.integerValue else { priceBelowValue = ""; return }
        guard newWishPrice != self.notificationSetting.entity!.priceBelowValue else { return }
        
        var notificationConfiguration = NotificationConfiguration.create(nil, currentSetting, notificationSetting)
        notificationConfiguration.notifications.priceBelow.belowValue = newWishPrice
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, skipWantNotificationCheck: true, uploadFinished: {
            self.notificationSetting.changePriceBelowValue(to: newWishPrice)
        }, uploadError: { DispatchQueue.main.async { self.priceBelowValue = self.notificationSetting.entity!.priceBelowValue.priceString ?? "" } })
    }
}

struct PriceBelowNotificationView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.keyboardObserver) var keyboardObserver
    
    @StateObject var viewModel = PriceBelowNotificationViewModel()
    @State var keyboardCurrentlyClosed = false
    
    let showHeader: Bool
    
    init(showHeader: Bool = false) {
        self.showHeader = showHeader
    }
    
    var body: some View {
        VStack {
            CustomInsetGroupedListItem(
                header: showHeader ? Text("general.notifications") : nil,
                footer: nil
            ) {
                VStack(alignment: .leading, spacing: 20) {
                    toggleView

                    if viewModel.notificationIsEnabled {
                        wishPriceInputField

                        PriceDropsBelowValueNotificationInfoView()
                    }
                }
            }
        }
    }

    var toggleView: some View {
        Toggle("notificationPage.notification.priceDropsBelowValue", isOn: $viewModel.notificationIsEnabled)
    }

    var wishPriceInputField: some View {
        VStack(alignment: .leading) {
            Text("notificationPage.notification.priceDropsBelowValue.wishPrice")
                .textCase(.uppercase)
                .foregroundColor(.gray)
                .font(.caption)

            HStack {
                NumberField(text: $viewModel.priceBelowValue, placeholder: "general.cent.long".localized(), plusMinusButton: true, withDecimalSeperator: false)
                    .fixedSize(horizontal: false, vertical: true)
//                    .disabled(!viewModel.areChangeable)
//                    .opacity(viewModel.areChangeable ? 1.0 : 0.7)

                Text("general.centPerKwh")
                    .transition(.opacity)
            }
            .onReceive(keyboardObserver.keyboardHeight) { newKeyboardHeight in
                if newKeyboardHeight == 0 {
                    keyboardCurrentlyClosed = true
                } else {
                    keyboardCurrentlyClosed = false
                }
            }
            .modifier(GeneralInputView(markedRed: false))
        }
    }
}
