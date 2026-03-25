//
//  BaseFeeView.swift
//  AWattPrice
//
//  Created by Léon Becker on 02.12.22.
//

import Combine
import SwiftUI

private extension Double {
    var baseFeeSummaryText: String {
        self.formatted(.number.precision(.fractionLength(2))) + " ct/kWh"
    }
}

private struct BaseFeeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.95, blue: 0.92),
                Color(red: 0.95, green: 0.97, blue: 0.99),
                Color.white,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct BaseFeeCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 20, y: 8)
    }
}

private struct BaseFeeBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.localized())
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

@MainActor
class BaseFeeViewModel: ObservableObject {
    var settingsManager: SettingsManager
    var notificationService: NotificationService
    var energyDataService: EnergyDataService

    @Published var baseFee: Double = 0
    @Published var isUploading = false
    @Published var showUploadIndicators = false
    @Published var uploadFailed = false

    var cancellables = [AnyCancellable]()

    init(settingsManager: SettingsManager, notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        self.energyDataService = energyDataService

        baseFee = settingsManager.setting.baseFeePrice
    }

    func baseFeeChanges() async {
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.general.baseFee = baseFee

        isUploading = true
        showUploadIndicators = true

        do {
            _ = try await notificationService.changeNotificationConfiguration(
                notificationConfiguration,
                settingsManager.setting
            )

            isUploading = false
            showUploadIndicators = false
            uploadFailed = false

            settingsManager.setting.baseFeePrice = self.baseFee
            energyDataService.energyData?.computeValues(with: settingsManager.setting.pricingConfiguration)
        } catch {
            print("Failed to update notification: \(error)")
            isUploading = false
            showUploadIndicators = false
            uploadFailed = true
        }
    }
}

struct BaseFeeView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var notificationService: NotificationService

    @StateObject private var viewModel: BaseFeeViewModel
    @FocusState private var isInputActive: Bool

    init() {
        _viewModel = StateObject(wrappedValue: BaseFeeViewModel(
            settingsManager: SettingsManager.shared,
            notificationService: NotificationService(),
            energyDataService: EnergyDataService()
        ))
    }

    var body: some View {
        ZStack {
            BaseFeeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BaseFeeCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Base Fee")
                                .font(.system(size: 34, weight: .bold, design: .rounded))

                            Text(viewModel.baseFee.baseFeeSummaryText)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .monospacedDigit()

                            if viewModel.settingsManager.setting.priceDropsBelowEnabled {
                                BaseFeeBadge(text: "Used in Price Guard", tint: .green)
                            }
                        }
                    }

                    BaseFeeCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Value")
                                .font(.headline)

                            HStack(spacing: 12) {
                                TextField("0.00", value: $viewModel.baseFee, format: .number.precision(.fractionLength(0 ... 2)))
                                    .keyboardType(.decimalPad)
                                    .focused($isInputActive)
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .monospacedDigit()

                                Spacer(minLength: 0)

                                Text("ct/kWh")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.72))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                            )

                            if viewModel.uploadFailed {
                                SettingsUploadErrorView()
                            }
                        }
                        .opacity(viewModel.showUploadIndicators ? 0.5 : 1)
                        .grayscale(viewModel.showUploadIndicators ? 0.5 : 0)
                        .disabled(viewModel.isUploading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }

            if viewModel.showUploadIndicators {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .navigationTitle("Base Fee")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputActive = false
                    Task { await viewModel.baseFeeChanges() }
                }
                .bold()
            }
        }
        .onAppear {
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
            viewModel.baseFee = settingsManager.setting.baseFeePrice
        }
    }
}

struct BaseFeeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BaseFeeView()
                .environmentObject(SettingsManager.shared)
                .environmentObject(NotificationService())
                .environmentObject(EnergyDataService())
        }
    }
}
