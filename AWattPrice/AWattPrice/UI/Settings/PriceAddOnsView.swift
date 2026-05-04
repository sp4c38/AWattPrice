//
//  PriceAddOnsView.swift
//  AWattPrice
//
//  Created by Léon Becker on 02.12.22.
//

import Combine
import SwiftUI

private extension Double {
    var priceAddOnSummaryText: String {
        self.formatted(.number.precision(.fractionLength(2))) + " ct/kWh"
    }

    var euroPerMonthText: String {
        self.formatted(.number.precision(.fractionLength(2))) + " EUR/month"
    }

    var kWhPerYearText: String {
        self.formatted(.number.precision(.fractionLength(0))) + " kWh/year"
    }

    var percentageText: String {
        self.formatted(.number.precision(.fractionLength(0 ... 3))) + "%"
    }
}

private struct PriceAddOnsBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppTheme.screenBackground(for: colorScheme)
            .ignoresSafeArea()
    }
}

private struct PriceAddOnsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        AppCard(cornerRadius: 20, padding: 18, spacing: 16) {
            content
        }
    }
}

private struct PriceAddOnsBadge: View {
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
class PriceAddOnsViewModel: ObservableObject {
    var settingsManager: SettingsManager
    var notificationService: NotificationService
    var energyDataService: EnergyDataService

    @Published var fixedPriceAddOn: Double = 0
    @Published var percentagePriceAddOn: Double = 0
    @Published var monthlyFixedCost: Double = 0
    @Published var annualConsumptionKWh: Double = 3500
    @Published var isUploading = false
    @Published var showUploadIndicators = false
    @Published var uploadFailed = false

    var cancellables = [AnyCancellable]()

    init(settingsManager: SettingsManager, notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        self.energyDataService = energyDataService

        loadValues()
    }

    var monthlyFixedCostPrice: Double {
        guard monthlyFixedCost > 0, annualConsumptionKWh > 0 else { return 0 }
        return monthlyFixedCost * 12 * 100 / annualConsumptionKWh
    }

    var totalPriceAddOn: Double {
        fixedPriceAddOn + monthlyFixedCostPrice
    }

    func loadValues() {
        fixedPriceAddOn = settingsManager.setting.baseFeePrice
        percentagePriceAddOn = settingsManager.setting.percentagePriceAddOn
        monthlyFixedCost = settingsManager.setting.monthlyFixedCost
        annualConsumptionKWh = settingsManager.setting.annualConsumptionKWh
    }

    func priceAddOnsChanges() async {
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.general.baseFee = totalPriceAddOn

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

            settingsManager.setting.baseFeePrice = self.fixedPriceAddOn
            settingsManager.setting.percentagePriceAddOn = self.percentagePriceAddOn
            settingsManager.setting.monthlyFixedCost = self.monthlyFixedCost
            settingsManager.setting.annualConsumptionKWh = self.annualConsumptionKWh
            settingsManager.saveChanges()
            energyDataService.energyData?.computeValues(with: settingsManager.setting.pricingConfiguration)
        } catch {
            print("Failed to update notification: \(error)")
            isUploading = false
            showUploadIndicators = false
            uploadFailed = true
        }
    }
}

private struct PriceModelInputRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let unit: String
    @Binding var value: Double
    let isInputActive: FocusState<Bool>.Binding

    private var inputFill: Color {
        AppTheme.fieldBackground(for: colorScheme)
    }

    private var inputStroke: Color {
        AppTheme.cardStroke(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized())
                    .font(.headline)

                Text(subtitle.localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                TextField("0.00", value: $value, format: .number.precision(.fractionLength(0 ... 2)))
                    .keyboardType(.decimalPad)
                    .focused(isInputActive)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Spacer(minLength: 0)

                Text(unit)
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
    }
}

struct PriceAddOnsView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var notificationService: NotificationService

    @StateObject private var viewModel: PriceAddOnsViewModel
    @FocusState private var isInputActive: Bool

    init() {
        _viewModel = StateObject(wrappedValue: PriceAddOnsViewModel(
            settingsManager: SettingsManager.shared,
            notificationService: NotificationService(),
            energyDataService: EnergyDataService()
        ))
    }

    var body: some View {
        ZStack {
            PriceAddOnsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PriceAddOnsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Price Add-ons")
                                .font(.system(size: 34, weight: .bold, design: .rounded))

                            Text("Final price =")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Market price with VAT * (1 + percentage add-on / 100) + fixed add-ons")
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .minimumScaleFactor(0.62)
                                .lineLimit(3)

                            Text("Fixed add-ons include the monthly fixed cost allocation.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                PriceAddOnsBadge(text: "+ \(viewModel.percentagePriceAddOn.percentageText)", tint: AppTheme.accent)
                                PriceAddOnsBadge(text: "+ \(viewModel.totalPriceAddOn.priceAddOnSummaryText)", tint: AppTheme.success)
                            }

                            if viewModel.settingsManager.setting.priceDropsBelowEnabled {
                                PriceAddOnsBadge(text: "Used in Price Guard", tint: AppTheme.success)
                            }
                        }
                    }

                    PriceAddOnsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            PriceModelInputRow(
                                title: "Fixed Add-on",
                                subtitle: "Generic extra costs per consumed kWh.",
                                unit: "ct/kWh",
                                value: $viewModel.fixedPriceAddOn,
                                isInputActive: $isInputActive
                            )

                            PriceModelInputRow(
                                title: "Percentage Add-on",
                                subtitle: "A contract markup based on the current price.",
                                unit: "%",
                                value: $viewModel.percentagePriceAddOn,
                                isInputActive: $isInputActive
                            )

                            PriceModelInputRow(
                                title: "Monthly Fixed Cost",
                                subtitle: "Standing charge or basic supplier fee.",
                                unit: "EUR/month",
                                value: $viewModel.monthlyFixedCost,
                                isInputActive: $isInputActive
                            )

                            PriceModelInputRow(
                                title: "Annual Consumption",
                                subtitle: "Used to spread fixed monthly costs over each kWh.",
                                unit: "kWh/year",
                                value: $viewModel.annualConsumptionKWh,
                                isInputActive: $isInputActive
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
        .navigationTitle("Price Add-ons")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputActive = false
                    Task { await viewModel.priceAddOnsChanges() }
                }
                .bold()
            }
        }
        .onAppear {
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
            viewModel.loadValues()
        }
    }
}

struct PriceAddOnsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PriceAddOnsView()
                .environmentObject(SettingsManager.shared)
                .environmentObject(NotificationService())
                .environmentObject(EnergyDataService())
        }
    }
}
