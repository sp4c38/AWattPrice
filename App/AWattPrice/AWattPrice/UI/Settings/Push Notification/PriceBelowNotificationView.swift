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

extension PriceBelowNotificationView {
    class ViewModel: ObservableObject {
        @ObservedObject var notificationService: NotificationService = Resolver.resolve()
        @Injected var currentSetting: CurrentSetting
        @ObservedObject var crtNotifiSetting: CurrentNotificationSetting = Resolver.resolve()

        @Published var notificationIsEnabled: Bool = false
        @Published var priceBelowValue: String = ""
        
        let showHeader: Bool

        init(showHeader: Bool) {
            self.showHeader = showHeader
            
            notificationIsEnabled = crtNotifiSetting.entity!.priceDropsBelowValueNotification
            priceBelowValue = crtNotifiSetting.entity!.priceBelowValue.priceString ?? ""
        }
        
        func priceBelowNotificationToggled(to newSelection: Bool) {
            notificationService.ensureAccess { access in
                if access == true,
                   let tokenContainer = self.notificationService.tokenContainer,
                   let notificationSettingEntity = self.crtNotifiSetting.entity
                {
                    let apiInterface = APINotificationInterface(token: tokenContainer.token)
                    let notificationInfo = SubDesubPriceBelowNotificationInfo(belowValue: notificationSettingEntity.priceBelowValue)
                    let subDesubPayload = SubDesubPayload(notificationType: .priceBelow, active: newSelection, notificationInfo: notificationInfo )
                    apiInterface.addPriceBelowSubDesubTask(subDesubPayload)
                    self.notificationService.runNotificationRequest(interface: apiInterface, appSetting: self.currentSetting, notificationSetting: self.crtNotifiSetting) {
                        DispatchQueue.main.async { self.notificationIsEnabled = newSelection }
                    }
                    print("Out")
                }
            }
        }
        
        func updateWishPrice(to newWishPrice: Int) {
            notificationService.ensureAccess { access in
                if access == true,
                   let tokenContainer = self.notificationService.tokenContainer
                {
                    let apiInterface = APINotificationInterface(token: tokenContainer.token)
                    let updatedData = UpdatedPriceBelowNotificationData(belowValue: newWishPrice)
                    let updatePayload = UpdatePayload(subject: .priceBelow, updatedData: updatedData)
                    apiInterface.addPriceBelowUpdateTask(updatePayload)
                    self.notificationService.runNotificationRequest(interface: apiInterface, appSetting: self.currentSetting, notificationSetting: self.crtNotifiSetting)
                }
            }
        }
    }
}

extension Binding {
    func willSet(execute: @escaping (Value) -> Void) -> Binding {
        return Binding(
            get: { self.wrappedValue },
            set: { newValue in
                execute(newValue)
            }
        )
    }
}


struct PriceBelowNotificationView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.keyboardObserver) var keyboardObserver
    
    @ObservedObject var viewModel: ViewModel
    
    @State var initialAppearFinished: Bool? = false
    @State var keyboardCurrentlyClosed = false
    
    @ObservedObject var notificationService: NotificationService = Resolver.resolve()
    
    init(showHeader showHeaderValue: Bool = false) {
        self.viewModel = ViewModel(showHeader: showHeaderValue)
    }
    
    var body: some View {
        VStack {
            CustomInsetGroupedListItem(
                header: viewModel.showHeader ? Text("general.notifications") : nil,
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
        HStack {
            Text("notificationPage.notification.priceDropsBelowValue")
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Spacer()
            Text(String(viewModel.notificationService.isUploading.isLocked))
            if !viewModel.notificationService.isUploading.isLocked {
                Toggle("", isOn: $viewModel.notificationIsEnabled.willSet { viewModel.priceBelowNotificationToggled(to: $0) }.animation())
                    .labelsHidden()
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
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
                    .onChange(of: viewModel.priceBelowValue) { newValue in
                        var newIntegerValue: Int = 0
                        if let newConvertedIntegerValue = newValue.integerValue {
                            newIntegerValue = newConvertedIntegerValue
                        }
                        viewModel.priceBelowValue = newIntegerValue.priceString ?? ""

                        if keyboardCurrentlyClosed {
                            viewModel.updateWishPrice(to: newIntegerValue)
                        }
                    }

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
