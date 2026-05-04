//
//  PriceBelowNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI

private struct PriceGuardBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
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
        isLoading
    }

    func priceBelowNotificationToggled(to newSelection: Bool) async {
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.notifications.priceBelow.active = newSelection

        do {
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
            await MainActor.run {
                self.priceBelowValue = settingsManager.setting.priceDropsBelowThreshold.priceString ?? ""
                isLoading = false
            }
        }
    }
}

struct PriceBelowNotificationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var notificationService: NotificationService

    @StateObject private var viewModel: PriceBelowNotificationViewModel

    let showHeader: Bool

    init(showHeader: Bool = false) {
        self.showHeader = showHeader

        _viewModel = StateObject(wrappedValue: PriceBelowNotificationViewModel(
            settingsManager: SettingsManager.shared,
            notificationService: NotificationService()
        ))
    }

    private var statusText: String {
        viewModel.notificationIsEnabled ? "On".localized() : "Off".localized()
    }

    private var currentThresholdText: String {
        let value = viewModel.priceBelowValue.isEmpty ? "0" : viewModel.priceBelowValue
        return "\(value) ct/kWh"
    }

    private var inputFill: Color {
        AppTheme.fieldBackground(for: colorScheme)
    }

    private var inputStroke: Color {
        AppTheme.cardStroke(for: colorScheme)
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                if showHeader {
                    HStack {
                        Text("Price Guard")
                            .font(.headline)

                        Spacer()

                        PriceGuardBadge(
                            text: statusText,
                            tint: viewModel.notificationIsEnabled ? AppTheme.success : .secondary
                        )
                    }
                }

                Toggle("Notify me", isOn: $viewModel.notificationIsEnabled)

                if viewModel.notificationIsEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Threshold")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Spacer()

                            PriceGuardBadge(text: currentThresholdText, tint: AppTheme.accent)
                        }

                        HStack(spacing: 12) {
                            NumberField(
                                text: $viewModel.priceBelowValue,
                                placeholder: "0",
                                plusMinusButton: false,
                                withDecimalSeperator: false
                            )
                            .frame(height: 24)

                            Spacer(minLength: 0)

                            Text("ct/kWh")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(inputFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(inputStroke, lineWidth: 1)
                                )
                        )
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .opacity(viewModel.showUploadIndicators ? 0.5 : 1)
            .grayscale(viewModel.showUploadIndicators ? 0.5 : 0)

            if viewModel.showUploadIndicators {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .disabled(viewModel.isLoading)
        .animation(.easeInOut(duration: 0.18), value: viewModel.notificationIsEnabled)
        .onAppear {
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
            viewModel.notificationIsEnabled = settingsManager.setting.priceDropsBelowEnabled
            viewModel.priceBelowValue = settingsManager.setting.priceDropsBelowThreshold.priceString ?? ""
        }
    }
}

struct PriceBelowNotifictionView_Previews: PreviewProvider {
    static var previews: some View {
        PriceBelowNotificationView(showHeader: true)
            .environmentObject(SettingsManager.shared)
            .environmentObject(NotificationService())
    }
}
