//
//  PriceBelowNotificationView.swift
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

class PriceBelowNotificationViewModel: ObservableObject {
    @Injected var setting: SettingCoreData
    @Injected var notificationSetting: NotificationSettingCoreData
    var notificationService: NotificationService = Resolver.resolve()

    @Published var notificationIsEnabled: Bool = false
    var notificationIsEnabledMethodNotifier: AnyCancellable? = nil
    @Published var priceBelowValue: String = ""
    var priceBelowValueMethodNotifier: AnyCancellable? = nil
    
    let uploadObserver = DownloadPublisherLoadingViewObserver(intervalBeforeExceeded: 0.4)
    var uploadErrorObserver: UploadErrorPublisherViewObserver? = nil
    
    var cancellables = [AnyCancellable]()
    
    init() {
        uploadObserver.objectWillChange.receive(on: DispatchQueue.main).sink(receiveValue: { self.objectWillChange.send() }).store(in: &cancellables)
        
        notificationIsEnabled = notificationSetting.entity.priceDropsBelowValueNotification
        notificationIsEnabledMethodNotifier = $notificationIsEnabled.dropFirst().sink(receiveValue: priceBelowNotificationToggled)
        priceBelowValue = Int(notificationSetting.entity.priceBelowValue).priceString ?? ""
        priceBelowValueMethodNotifier = $priceBelowValue.dropFirst().sink(receiveValue: updateWishPrice)
    }
    
    var isUploading: Bool {
        [.uploadingAndTimeExceeded, .uploadingAndTimeNotExceeded].contains(uploadObserver.loadingPublisher)
    }
    
    var showUploadIndicators: Bool {
        uploadObserver.loadingPublisher == .uploadingAndTimeExceeded
    }
    
    func priceBelowNotificationToggled(to newSelection: Bool) {
        var notificationConfiguration = NotificationConfiguration.create(nil, setting, notificationSetting)
        notificationConfiguration.notifications.priceBelow.active = newSelection
        let uploadFailure = {
            DispatchQueue.main.async {
                self.notificationIsEnabledMethodNotifier = self.$notificationIsEnabled.dropFirst().dropFirst().sink(receiveValue: self.priceBelowNotificationToggled)
                self.notificationIsEnabled = self.notificationSetting.entity.priceDropsBelowValueNotification
            }
        }

        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, skipWantNotificationCheck: true) { downloadPublisher in
            self.uploadObserver.register(for: downloadPublisher.ignoreOutput().eraseToAnyPublisher())
            self.uploadErrorObserver?.register(for: downloadPublisher.eraseToAnyPublisher())
            downloadPublisher.sink(receiveCompletion: { completion in
                switch completion { case .finished: self.notificationSetting.changeSetting { $0.entity.priceDropsBelowValueNotification = newSelection }
                                    case .failure: uploadFailure() }
            }, receiveValue: {_ in}).store(in: &self.cancellables)
        } cantStartUpload: {
            uploadFailure()
        }
    }
    
    func updateWishPrice(to newWishPriceString: String) {
        guard let newWishPrice = newWishPriceString.integerValue else { priceBelowValue = ""; return }
        var notificationConfiguration = NotificationConfiguration.create(nil, setting, notificationSetting)
        notificationConfiguration.notifications.priceBelow.belowValue = newWishPrice
        let uploadFailure = {
            DispatchQueue.main.async {
                self.priceBelowValueMethodNotifier = self.$priceBelowValue.dropFirst().dropFirst().sink(receiveValue: self.updateWishPrice)
                self.priceBelowValue = Int(self.notificationSetting.entity.priceBelowValue).priceString ?? ""
            }
        }
        
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, skipWantNotificationCheck: true) { downloadPublisher in
            self.uploadObserver.register(for: downloadPublisher.ignoreOutput().eraseToAnyPublisher())
            self.uploadErrorObserver?.register(for: downloadPublisher.eraseToAnyPublisher())
            downloadPublisher.sink(receiveCompletion: { completion in
                switch completion { case .finished: self.notificationSetting.changeSetting { $0.entity.priceBelowValue = Int64(newWishPrice) }
                                    case .failure: uploadFailure() }
            }, receiveValue: {_ in}).store(in: &self.cancellables)
        } cantStartUpload: {
            uploadFailure()
        }
    }
}

struct PriceBelowNotificationView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.keyboardObserver) var keyboardObserver
    
    @StateObject var viewModel = PriceBelowNotificationViewModel()
    @State var keyboardCurrentlyClosed = false
    
    // This property will be injected in the views .onAppear. The view model is a StateObject which makes it a bit of a tricky situation but as this variable is used the earliest
    // after the first view rendered it is a working and acceptable approach.
    let uploadErrorObserver: UploadErrorPublisherViewObserver?
    let showHeader: Bool
    
    init(uploadErrorObserver: UploadErrorPublisherViewObserver? = nil, showHeader: Bool = false) {
        self.uploadErrorObserver = uploadErrorObserver
        self.showHeader = showHeader
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                toggleView

                if viewModel.notificationIsEnabled {
                    wishPriceInputField

                    PriceDropsBelowValueNotificationInfoView()
                }
            }
            .opacity(viewModel.showUploadIndicators ? 0.5 : 1)
            .grayscale(viewModel.showUploadIndicators ? 0.5 : 0)
            
            if viewModel.showUploadIndicators {
                loadingView
            }
        }
        .disabled(viewModel.isUploading)
        .onAppear { viewModel.uploadErrorObserver = uploadErrorObserver }
    }

    var toggleView: some View {
        Toggle("Price notification", isOn: $viewModel.notificationIsEnabled)
    }

    var wishPriceInputField: some View {
        VStack(alignment: .leading) {
            Text("Wish Price:")
                .textCase(.uppercase)
                .foregroundColor(.gray)
                .font(.caption)

            HStack {
                NumberField(text: $viewModel.priceBelowValue, placeholder: "Cent".localized(), plusMinusButton: true, withDecimalSeperator: false)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Cent per kWh")
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
    
    var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
    }
}

struct PriceBelowNotifictionView_Previews: PreviewProvider {
    static var previews: some View {
        PriceBelowNotificationView()
    }
}
