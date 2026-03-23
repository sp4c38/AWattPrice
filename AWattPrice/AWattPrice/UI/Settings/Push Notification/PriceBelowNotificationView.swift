//
//  PriceBelowNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

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

@MainActor
class PriceBelowNotificationViewModel: ObservableObject {
    var settingsManager: SettingsManager
    var notificationService: NotificationService

    @Published var notificationIsEnabled: Bool {
        didSet {
            if oldValue != notificationIsEnabled {
                Task { await priceBelowNotificationToggled(to: notificationIsEnabled) }
            }
        }
    }
    
    @Published var priceBelowValue: String {
        didSet {
            if oldValue != priceBelowValue {
                Task { await updateWishPrice(to: priceBelowValue) }
            }
        }
    }
    
    @Published private(set) var isLoading = false
    
    init(settingsManager: SettingsManager, notificationService: NotificationService) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        
        notificationIsEnabled = settingsManager.setting.priceDropsBelowEnabled
        priceBelowValue = settingsManager.setting.priceDropsBelowThreshold.priceString ?? ""
    }
    
    var showUploadIndicators: Bool {
        return isLoading
    }
    
    func priceBelowNotificationToggled(to newSelection: Bool) async {
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.notifications.priceBelow.active = newSelection
        
        do {
            // Show loading indicator
            await MainActor.run { isLoading = true }
            
            _ = try await notificationService.changeNotificationConfiguration(
                notificationConfiguration,
                settingsManager.setting
            )
            
            await MainActor.run {
                settingsManager.setting.priceDropsBelowEnabled = newSelection
                isLoading = false
            }
        } catch {
            print("Failed to update notification configuration: \(error)")
            // Revert to the previous value on failure
            await MainActor.run {
                self.notificationIsEnabled = settingsManager.setting.priceDropsBelowEnabled
                isLoading = false
            }
        }
    }
    
    func updateWishPrice(to newWishPriceString: String) async {
        guard let newWishPrice = newWishPriceString.integerValue else { 
            await MainActor.run { priceBelowValue = "" }
            return 
        }
        
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.notifications.priceBelow.belowValue = newWishPrice
        
        do {
            // Show loading indicator
            await MainActor.run { isLoading = true }
            
            _ = try await notificationService.changeNotificationConfiguration(
                notificationConfiguration,
                settingsManager.setting
            )
            
            await MainActor.run {
                settingsManager.setting.priceDropsBelowThreshold = newWishPrice
                isLoading = false
            }
        } catch {
            print("Failed to update notification configuration: \(error)")
            // Revert to the previous value on failure
            await MainActor.run {
                self.priceBelowValue = settingsManager.setting.priceDropsBelowThreshold.priceString ?? ""
                isLoading = false
            }
        }
    }
}

struct PriceBelowNotificationView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.keyboardObserver) var keyboardObserver
    
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var notificationService: NotificationService
    
    @StateObject private var viewModel: PriceBelowNotificationViewModel
    @State var keyboardCurrentlyClosed = false
    
    // This property will be simplified since we no longer need error observers
    let showHeader: Bool
    
    init(showHeader: Bool = false) {
        self.showHeader = showHeader
        
        // Initialize with temporary values that will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: PriceBelowNotificationViewModel(
            settingsManager: SettingsManager.shared,
            notificationService: NotificationService()
        ))
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
        .disabled(viewModel.isLoading)
        .onAppear {
            // Update viewModel with the actual environment objects
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
        }
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
                keyboardCurrentlyClosed = (newKeyboardHeight == 0)
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
            .environmentObject(NotificationService())
    }
}
