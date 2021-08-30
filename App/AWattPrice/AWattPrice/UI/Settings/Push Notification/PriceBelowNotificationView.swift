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
    class ViewModel {
        @ObservedObject var notificationService: NotificationService = Resolver.resolve()
        @Injected var currentSetting: CurrentSetting
        @ObservedObject var crtNotifiSetting: CurrentNotificationSetting = Resolver.resolve()

        let showHeader: Bool

        init(showHeader: Bool) {
            self.showHeader = showHeader
        }
        
        var requestInProgress: Bool { notificationService.apiNotificationRequestState == .requestInProgress }
        
        func priceBelowNotificationToggled(to newSelection: Bool) {
            if let interface = notificationService.getBaseNotificationInterface(), 
               let tokenContainer = notificationService.tokenContainer,
               !(tokenContainer.nextUploadState) ==
            {
                if (tokenContainer.nextUploadState == .uploadAllNotificationConfig) {
                    
                }
            }
        }
    }
}

struct PriceBelowNotificationView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.keyboardObserver) var keyboardObserver
    
    let viewModel: ViewModel
    
    @State var initialAppearFinished: Bool? = false
    @State var keyboardCurrentlyClosed = false
    @State var priceDropsBelowValueNotificationSelection = false
    @State var priceBelowValue: String = ""
    
    @ObservedObject var notificationService: NotificationService = Resolver.resolve()
    
    init(showHeader showHeaderValue: Bool = false) {
        self.viewModel = ViewModel(showHeader: showHeaderValue)
        priceBelowValue = viewModel.crtNotifiSetting.entity!.priceBelowValue.priceString ?? ""
        priceDropsBelowValueNotificationSelection = viewModel.crtNotifiSetting.entity!.priceDropsBelowValueNotification
    }
    
    var body: some View {
        VStack {
            CustomInsetGroupedListItem(
                header: viewModel.showHeader ? Text("general.notifications") : nil,
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

    var toggleView: some View {
        HStack {
            Text("notificationPage.notification.priceDropsBelowValue")
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Spacer()

            Toggle("", isOn: $priceDropsBelowValueNotificationSelection.animation())
                .labelsHidden()
                .onChange(of: priceDropsBelowValueNotificationSelection) { viewModel.priceBelowNotificationToggled(to: $0) }
                .disabled(viewModel.requestInProgress)
        }
    }

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
//                        var newIntegerValue: Int = 0
//                        if let newConvertedIntegerValue = newValue.integerValue {
//                            newIntegerValue = newConvertedIntegerValue
//                        }
//                        crtNotifiSetting.changePriceBelowValue(to: newIntegerValue)
//                        priceBelowValue = newIntegerValue.priceString ?? ""
//
//                        if keyboardCurrentlyClosed {
//                            crtNotifiSetting.pushNotificationUpdateManager.backgroundNotificationUpdate(currentSetting, crtNotifiSetting)
//                        }
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

//struct NewPricesNotificationView_Previews: PreviewProvider {
//    static var previews: some View {
//        PriceDropsBelowValueNotificationInfoView()
//            .padding(.leading, 17)
//            .padding(.trailing, 14)
//            .padding([.top, .bottom], 7)
//
//        NavigationView {
//            PriceDropsBelowValueNotificationView()
//                .environmentObject(
//                    CurrentNotificationSetting(
//                        backendComm: BackendCommunicator(),
//                        managedObjectContext: PersistenceManager().persistentContainer.viewContext
//                    )
//                )
//                .preferredColorScheme(.light)
//                .environment(\.locale, Locale(identifier: "de"))
//        }
//    }
//}
