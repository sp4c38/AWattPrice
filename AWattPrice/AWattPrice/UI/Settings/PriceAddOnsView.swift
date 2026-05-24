//
//  PriceAddOnsView.swift
//  AWattPrice
//
//  Created by Léon Becker on 02.12.22.
//

import SwiftUI

private extension Double {
    var isActivePriceComponent: Bool {
        self != 0
    }

    var priceAddOnSummaryText: String {
        self.formatted(.number.precision(.fractionLength(2)))
    }

    var euroPerMonthText: String {
        self.formatted(.number.precision(.fractionLength(2)))
    }

    var kWhPerYearText: String {
        self.formatted(.number.precision(.fractionLength(0)))
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
    var isLoading = false

    var body: some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(tint)
            }

            Text(text.localized())
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct UnitLabel: View {
    let unit: String
    var size: CGFloat = 17
    var weight: Font.Weight = .semibold

    var body: some View {
        Text(unit)
            .font(.system(size: size, weight: weight, design: .rounded))
            .fixedSize()
    }
}

private struct PriceValueLabel: View {
    let value: String
    let unit: String
    var tint: Color = .primary
    var size: CGFloat = 20

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()

            UnitLabel(unit: unit, size: size * 0.80, weight: .semibold)
        }
        .foregroundStyle(tint)
        .fixedSize()
    }
}

private struct PriceAddOnsDraft: Equatable {
    var fixedPriceAddOn: Double
    var percentagePriceAddOn: Double
    var monthlyFixedCost: Double
    var annualConsumptionKWh: Double

    init(setting: Setting) {
        fixedPriceAddOn = setting.baseFeePrice
        percentagePriceAddOn = setting.percentagePriceAddOn
        monthlyFixedCost = setting.monthlyFixedCost
        annualConsumptionKWh = setting.annualConsumptionKWh
    }

    var monthlyFixedCostPrice: Double {
        guard monthlyFixedCost > 0, annualConsumptionKWh > 0 else { return 0 }
        return monthlyFixedCost * 12 * 100 / annualConsumptionKWh
    }

    var totalPriceAddOn: Double {
        fixedPriceAddOn + monthlyFixedCostPrice
    }

    var hasActiveAddOns: Bool {
        percentagePriceAddOn.isActivePriceComponent
            || fixedPriceAddOn.isActivePriceComponent
            || monthlyFixedCostPrice.isActivePriceComponent
    }

    var canSave: Bool {
        if monthlyFixedCost > 0, annualConsumptionKWh <= 0 { return false }
        return true
    }
}

@MainActor
private class PriceAddOnsViewModel: ObservableObject {
    enum Timing {
        static let minimumUploadingNanoseconds: UInt64 = 1_600_000_000
        static let uploadIndicatorDelayNanoseconds: UInt64 = 450_000_000
    }

    var settingsManager: SettingsManager
    var notificationService: NotificationService
    var energyDataService: EnergyDataService
    private var uploadIndicatorStart: Date?
    private var isUploadRequestInFlight = false

    @Published var draft: PriceAddOnsDraft
    @Published private(set) var savedDraft: PriceAddOnsDraft
    @Published var isSaving = false
    @Published var uploadFailed = false

    init(settingsManager: SettingsManager, notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        self.energyDataService = energyDataService
        let draft = PriceAddOnsDraft(setting: settingsManager.setting)
        self.draft = draft
        self.savedDraft = draft
    }

    var hasUnsavedChanges: Bool {
        draft != savedDraft
    }

    var annualConsumptionValidationMessage: String? {
        guard draft.monthlyFixedCost > 0, draft.annualConsumptionKWh <= 0 else { return nil }
        return "Annual consumption is required to allocate monthly fixed costs."
    }

    func resetFromSettings() {
        let currentDraft = PriceAddOnsDraft(setting: settingsManager.setting)
        draft = currentDraft
        savedDraft = currentDraft
        uploadFailed = false
        uploadIndicatorStart = nil
        isUploadRequestInFlight = false
        isSaving = false
    }

    func beginUploadFeedback() {
        if isSaving == false {
            uploadIndicatorStart = Date()
            isSaving = true
        }

        uploadFailed = false
    }

    func cancelPendingUploadFeedback() {
        guard isUploadRequestInFlight == false else { return }
        uploadIndicatorStart = nil
        isSaving = false
    }

    func save() async {
        guard draft.canSave else {
            cancelPendingUploadFeedback()
            return
        }
        guard isUploadRequestInFlight == false else { return }

        let draftToSave = draft
        let previousDraft = PriceAddOnsDraft(setting: settingsManager.setting)
        let uploadStart = uploadIndicatorStart ?? Date()
        isUploadRequestInFlight = true

        settingsManager.setting.baseFeePrice = draftToSave.fixedPriceAddOn
        settingsManager.setting.percentagePriceAddOn = draftToSave.percentagePriceAddOn
        settingsManager.setting.monthlyFixedCost = draftToSave.monthlyFixedCost
        settingsManager.setting.annualConsumptionKWh = draftToSave.annualConsumptionKWh

        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.general.baseFee = draftToSave.totalPriceAddOn
        notificationConfiguration.general.percentageAddOn = draftToSave.percentagePriceAddOn

        isSaving = true
        uploadFailed = false

        do {
            _ = try await notificationService.changeNotificationConfiguration(
                notificationConfiguration,
                settingsManager.setting
            )

            await waitForMinimumUploadingTime(since: uploadStart)
            settingsManager.saveChanges()
            savedDraft = draftToSave
            isUploadRequestInFlight = false
            uploadIndicatorStart = nil
            isSaving = false
            energyDataService.energyData?.computeValues(with: settingsManager.setting.pricingConfiguration)
        } catch {
            print("Failed to update notification: \(error)")
            await waitForMinimumUploadingTime(since: uploadStart)
            settingsManager.setting.baseFeePrice = previousDraft.fixedPriceAddOn
            settingsManager.setting.percentagePriceAddOn = previousDraft.percentagePriceAddOn
            settingsManager.setting.monthlyFixedCost = previousDraft.monthlyFixedCost
            settingsManager.setting.annualConsumptionKWh = previousDraft.annualConsumptionKWh
            draft = savedDraft
            isUploadRequestInFlight = false
            uploadIndicatorStart = nil
            isSaving = false
            uploadFailed = true
        }
    }

    private func waitForMinimumUploadingTime(since startDate: Date) async {
        let elapsed = Date().timeIntervalSince(startDate)
        let minimum = Double(Timing.minimumUploadingNanoseconds) / 1_000_000_000
        guard elapsed < minimum else { return }
        let remaining = UInt64((minimum - elapsed) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: remaining)
    }
}

private struct PriceModelInputRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String?
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

                if let subtitle = subtitle {
                    Text(subtitle.localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                TextField("0.00", value: $value, format: .number.precision(.fractionLength(0 ... 2)))
                    .keyboardType(.decimalPad)
                    .focused(isInputActive)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Spacer(minLength: 0)

                UnitLabel(unit: unit)
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

private struct PriceFormulaTerm: Identifiable {
    let id: String
    let title: String?
    let value: String?
    let unit: String?
    let tint: Color?

    static func text(_ title: String, id: String) -> PriceFormulaTerm {
        PriceFormulaTerm(id: id, title: title, value: nil, unit: nil, tint: nil)
    }

    static func price(_ value: String, unit: String, tint: Color, id: String) -> PriceFormulaTerm {
        PriceFormulaTerm(id: id, title: nil, value: value, unit: unit, tint: tint)
    }

    static func percentage(_ value: String, tint: Color, id: String) -> PriceFormulaTerm {
        PriceFormulaTerm(id: id, title: nil, value: value, unit: nil, tint: tint)
    }
}

private struct PriceFormulaTermView: View {
    let term: PriceFormulaTerm

    var body: some View {
        Group {
            if let title = term.title {
                Text(title.localized())
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            } else if let value = term.value, let unit = term.unit, let tint = term.tint {
                PriceValueLabel(value: value, unit: unit, tint: tint, size: 20)
            } else if let value = term.value, let tint = term.tint {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
        }
    }
}

private struct PriceFormulaOperator: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

private struct PriceFormulaView: View {
    let draft: PriceAddOnsDraft

    private var formulaTerms: [PriceFormulaTerm] {
        var terms = [
            PriceFormulaTerm.text("Market price", id: "market-price"),
            PriceFormulaTerm.percentage("VAT", tint: .orange, id: "vat")
        ]

        if draft.percentagePriceAddOn.isActivePriceComponent {
            terms.append(PriceFormulaTerm.percentage(draft.percentagePriceAddOn.percentageText, tint: .cyan, id: "percentage"))
        }

        if draft.fixedPriceAddOn.isActivePriceComponent {
            terms.append(PriceFormulaTerm.price(draft.fixedPriceAddOn.priceAddOnSummaryText, unit: "ct/kWh", tint: .green, id: "fixed"))
        }

        if draft.monthlyFixedCostPrice.isActivePriceComponent {
            terms.append(PriceFormulaTerm.price(draft.monthlyFixedCostPrice.priceAddOnSummaryText, unit: "ct/kWh", tint: .blue, id: "monthly"))
        }

        return terms
    }

    var body: some View {
        FlowLayout(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("Final price =".localized())
                    .font(.headline)
                    .foregroundStyle(.secondary)

                PriceFormulaTermView(term: formulaTerms[0])
            }
            .fixedSize()

            ForEach(Array(formulaTerms.dropFirst()), id: \.id) { term in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    PriceFormulaOperator(text: "+")
                    PriceFormulaTermView(term: term)
                }
                .fixedSize()
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: formulaTerms.map(\.id))
    }
}

private struct ActivePriceAddOnsView: View {
    let draft: PriceAddOnsDraft

    var body: some View {
        if draft.hasActiveAddOns {
            FlowLayout(spacing: 8) {
                if draft.percentagePriceAddOn.isActivePriceComponent {
                    PriceAddOnsBadge(
                        text: String(format: "Percentage %@".localized(), "+\(draft.percentagePriceAddOn.percentageText)"),
                        tint: AppTheme.accent
                    )
                }

                if draft.fixedPriceAddOn.isActivePriceComponent {
                    PriceAddOnsBadge(
                        text: String(format: "Fixed %@".localized(), "+\(draft.fixedPriceAddOn.priceAddOnSummaryText)"),
                        tint: AppTheme.success
                    )
                }

                if draft.monthlyFixedCostPrice.isActivePriceComponent {
                    PriceAddOnsBadge(
                        text: String(format: "Monthly cost %@".localized(), "+\(draft.monthlyFixedCostPrice.priceAddOnSummaryText)"),
                        tint: AppTheme.success
                    )
                }
            }
        } else {
            PriceAddOnsBadge(text: "No add-ons active", tint: Color.secondary)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(proposal: proposal, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.last.map { $0.y + $0.height } ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in rows(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private func rows(proposal: ProposedViewSize, subviews: Subviews) -> [FlowLayoutRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [FlowLayoutRow] = []
        var currentItems: [FlowLayoutItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        var currentY: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if nextWidth > maxWidth, currentItems.isEmpty == false {
                rows.append(FlowLayoutRow(items: currentItems, y: currentY, width: currentWidth, height: currentHeight))
                currentY += currentHeight + spacing
                currentItems = [FlowLayoutItem(index: index, x: 0, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                let x = currentItems.isEmpty ? 0 : currentWidth + spacing
                currentItems.append(FlowLayoutItem(index: index, x: x, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if currentItems.isEmpty == false {
            rows.append(FlowLayoutRow(items: currentItems, y: currentY, width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

private struct FlowLayoutItem {
    let index: Int
    let x: CGFloat
    let size: CGSize
}

private struct FlowLayoutRow {
    let items: [FlowLayoutItem]
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

private struct PriceAddOnsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.localized())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

struct PriceAddOnsView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var notificationService: NotificationService

    @StateObject private var viewModel: PriceAddOnsViewModel
    @FocusState private var isInputActive: Bool
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var uploadFeedbackTask: Task<Void, Never>?

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
                    if viewModel.isSaving {
                        PriceAddOnsBadge(text: "Saving to server", tint: AppTheme.accent, isLoading: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    PriceAddOnsCard {
                        Text("Add-ons are applied to prices everywhere throughout AWattPrice.".localized())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            PriceFormulaView(draft: viewModel.draft)
                        }
                    }
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.draft.hasActiveAddOns)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.draft.fixedPriceAddOn.isActivePriceComponent)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.draft.percentagePriceAddOn.isActivePriceComponent)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.draft.monthlyFixedCostPrice.isActivePriceComponent)

                    PriceAddOnsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            PriceModelInputRow(
                                title: "Fixed Add-on",
                                subtitle: nil,
                                unit: "ct/kWh",
                                value: $viewModel.draft.fixedPriceAddOn,
                                isInputActive: $isInputActive
                            )
                        }
                    }

                    PriceAddOnsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            PriceModelInputRow(
                                title: "Percentage Add-on",
                                subtitle: nil,
                                unit: "%",
                                value: $viewModel.draft.percentagePriceAddOn,
                                isInputActive: $isInputActive
                            )
                        }
                    }

                    PriceAddOnsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            PriceModelInputRow(
                                title: "Monthly Fixed Cost",
                                subtitle: "Basic electricity provider fee.",
                                unit: "EUR/month",
                                value: $viewModel.draft.monthlyFixedCost,
                                isInputActive: $isInputActive
                            )

                            PriceModelInputRow(
                                title: "Annual Consumption",
                                subtitle: "Used to spread fixed monthly costs over each kWh.",
                                unit: "kWh/year",
                                value: $viewModel.draft.annualConsumptionKWh,
                                isInputActive: $isInputActive
                            )

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("Monthly fixed cost adds".localized())
                                    .font(.footnote.weight(.semibold))

                                PriceValueLabel(
                                    value: viewModel.draft.monthlyFixedCostPrice.priceAddOnSummaryText,
                                    unit: "ct/kWh.",
                                    tint: Color.secondary,
                                    size: 13
                                )
                            }
                            .foregroundStyle(.secondary)

                            if let annualConsumptionValidationMessage = viewModel.annualConsumptionValidationMessage {
                                Text(annualConsumptionValidationMessage.localized())
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.error)
                            }

                            if viewModel.uploadFailed {
                                Text("Price add-ons could not be saved to the server. Your previous settings were restored.".localized())
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.error)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.isSaving)
        .navigationTitle("Price Add-ons")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputActive = false
                }
                .bold()
            }
        }
        .onAppear {
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
            viewModel.resetFromSettings()
        }
        .onChange(of: viewModel.draft) { _, _ in
            scheduleAutoSave()
        }
        .onChange(of: viewModel.isSaving) { _, isSaving in
            if isSaving == false, viewModel.uploadFailed == false {
                scheduleAutoSave()
            }
        }
        .onDisappear {
            autoSaveTask?.cancel()
            uploadFeedbackTask?.cancel()
            viewModel.cancelPendingUploadFeedback()
        }
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        uploadFeedbackTask?.cancel()
        guard viewModel.hasUnsavedChanges, viewModel.draft.canSave else {
            viewModel.cancelPendingUploadFeedback()
            return
        }

        uploadFeedbackTask = Task {
            try? await Task.sleep(nanoseconds: PriceAddOnsViewModel.Timing.uploadIndicatorDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                viewModel.beginUploadFeedback()
            }
        }

        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard Task.isCancelled == false else { return }
            await viewModel.save()
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
