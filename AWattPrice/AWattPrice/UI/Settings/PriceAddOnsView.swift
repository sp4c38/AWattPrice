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

private extension PriceAddOnKind {
    var tint: Color {
        switch self {
        case .fixed: AppTheme.success
        case .percentage: AppTheme.accent
        case .monthly: AppTheme.success
        }
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
    var addOnOrder: [PriceAddOnKind]

    init(setting: Setting) {
        fixedPriceAddOn = setting.baseFeePrice
        percentagePriceAddOn = setting.percentagePriceAddOn
        monthlyFixedCost = setting.monthlyFixedCost
        annualConsumptionKWh = setting.annualConsumptionKWh
        addOnOrder = setting.orderedPriceAddOnKinds
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

    var activeAddOnKinds: [PriceAddOnKind] {
        addOnOrder.filter { isActive($0) }
    }

    var canReorderAddOns: Bool {
        activeAddOnKinds.count > 1
    }

    var canSave: Bool {
        if monthlyFixedCost > 0, annualConsumptionKWh <= 0 { return false }
        return true
    }

    func isActive(_ kind: PriceAddOnKind) -> Bool {
        switch kind {
        case .fixed: fixedPriceAddOn.isActivePriceComponent
        case .percentage: percentagePriceAddOn.isActivePriceComponent
        case .monthly: monthlyFixedCostPrice.isActivePriceComponent
        }
    }

    func formulaTerm(for kind: PriceAddOnKind) -> PriceFormulaTerm {
        switch kind {
        case .fixed:
            PriceFormulaTerm.price(fixedPriceAddOn.priceAddOnSummaryText, unit: "ct/kWh", tint: kind.tint, id: kind.rawValue)
        case .percentage:
            PriceFormulaTerm.percentage(percentagePriceAddOn.percentageText, tint: kind.tint, id: kind.rawValue)
        case .monthly:
            PriceFormulaTerm.price(monthlyFixedCostPrice.priceAddOnSummaryText, unit: "ct/kWh", tint: kind.tint, id: kind.rawValue)
        }
    }

    mutating func moveAddOn(_ source: PriceAddOnKind, to target: PriceAddOnKind) {
        guard source != target else { return }
        var normalizedOrder = Setting.normalizedPriceAddOnOrder(addOnOrder)
        guard
            let sourceIndex = normalizedOrder.firstIndex(of: source),
            let targetIndex = normalizedOrder.firstIndex(of: target)
        else { return }

        normalizedOrder.remove(at: sourceIndex)
        let insertionIndex = min(targetIndex, normalizedOrder.count)
        normalizedOrder.insert(source, at: insertionIndex)
        addOnOrder = Setting.normalizedPriceAddOnOrder(normalizedOrder)
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

    var needsServerSave: Bool {
        notificationService.wantToReceiveAnyNotification(setting: settingsManager.setting)
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
        settingsManager.setting.orderedPriceAddOnKinds = draftToSave.addOnOrder

        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.general.baseFee = draftToSave.totalPriceAddOn
        notificationConfiguration.general.percentageAddOn = draftToSave.percentagePriceAddOn

        if needsServerSave == false {
            settingsManager.saveChanges()
            savedDraft = draftToSave
            isUploadRequestInFlight = false
            uploadIndicatorStart = nil
            isSaving = false
            uploadFailed = false
            energyDataService.energyData?.computeValues(with: settingsManager.setting.pricingConfiguration)
            return
        }

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
            settingsManager.setting.orderedPriceAddOnKinds = previousDraft.addOnOrder
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
    let activeTint: Color?
    @State private var text: String

    init(
        title: String,
        subtitle: String?,
        unit: String,
        value: Binding<Double>,
        isInputActive: FocusState<Bool>.Binding,
        activeTint: Color? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.unit = unit
        self._value = value
        self.isInputActive = isInputActive
        self.activeTint = activeTint
        self._text = State(initialValue: Self.text(for: value.wrappedValue, unit: unit))
    }

    private var inputFill: Color {
        AppTheme.fieldBackground(for: colorScheme)
    }

    private var inputStroke: Color {
        AppTheme.cardStroke(for: colorScheme)
    }

    private var placeholder: String {
        Self.text(for: 0, unit: unit)
    }

    private static func text(for value: Double, unit: String) -> String {
        if unit == "kWh/year" {
            value.formatted(.number.precision(.fractionLength(0)))
        } else {
            value.formatted(.number.precision(.fractionLength(2)))
        }
    }

    private static func parsedValue(from text: String, unit: String) -> Double? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else { return 0 }

        if unit == "kWh/year" {
            var sanitizedText = ""
            for character in trimmedText {
                if character == "-", sanitizedText.isEmpty {
                    sanitizedText.append(character)
                } else if character.isNumber {
                    sanitizedText.append(character)
                }
            }
            return Double(sanitizedText)
        }

        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let alternateSeparator = decimalSeparator == "," ? "." : ","
        let textWithLocaleDecimalSeparator: String

        if trimmedText.range(of: decimalSeparator) == nil, trimmedText.range(of: alternateSeparator) != nil {
            textWithLocaleDecimalSeparator = trimmedText.replacingOccurrences(of: alternateSeparator, with: decimalSeparator)
        } else {
            textWithLocaleDecimalSeparator = trimmedText
        }

        return textWithLocaleDecimalSeparator.doubleValue
    }

    private func updateValue(from newText: String) {
        if let parsedValue = Self.parsedValue(from: newText, unit: unit) {
            value = parsedValue
        }
    }

    private func formatText() {
        text = Self.text(for: value, unit: unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized())
                    .font(.headline)
                    .foregroundStyle(activeTint ?? .primary)

                if let subtitle = subtitle {
                    Text(subtitle.localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .focused(isInputActive)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .onChange(of: text) { _, newText in
                        updateValue(from: newText)
                    }
                    .onChange(of: value) { _, newValue in
                        guard text.isEmpty == false else { return }
                        let parsedTextValue = Self.parsedValue(from: text, unit: unit)
                        if parsedTextValue.map({ $0 != newValue }) ?? true {
                            text = Self.text(for: newValue, unit: unit)
                        }
                    }
                    .onChange(of: isInputActive.wrappedValue) { _, isActive in
                        if isActive == false {
                            formatText()
                        }
                    }

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
                            .stroke(activeTint.map { $0.opacity(0.42) } ?? inputStroke, lineWidth: 1)
                    )
            )
            .animation(.easeInOut(duration: 0.18), value: activeTint != nil)
        }
        .animation(.easeInOut(duration: 0.18), value: activeTint != nil)
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

        terms.append(contentsOf: draft.activeAddOnKinds.map { draft.formulaTerm(for: $0) })

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

private struct ReorderablePriceAddOnSection<Content: View>: View {
    let kind: PriceAddOnKind
    let canReorder: Bool
    let isDragging: Bool
    let dragTranslation: CGFloat
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        PriceAddOnsCard {
            if canReorder {
                HStack {
                    Spacer()

                    Image(systemName: "line.3.horizontal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isDragging ? .secondary : .tertiary)
                        .padding(10)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                                .onChanged(onDragChanged)
                                .onEnded(onDragEnded)
                        )
                        .accessibilityLabel("Reorder".localized())
                }
            }

            content
        }
        .scaleEffect(isDragging ? 1.03 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.12 : 0), radius: isDragging ? 10 : 0, y: isDragging ? 4 : 0)
        .offset(y: isDragging ? dragTranslation : 0)
        .zIndex(isDragging ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isDragging)
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

    @State private var draggingKind: PriceAddOnKind? = nil
    @State private var dragTranslation: CGFloat = 0
    @State private var lastRawTranslation: CGFloat = 0
    @State private var itemHeights: [PriceAddOnKind: CGFloat] = [:]
    private let cardSpacing: CGFloat = 18

    init() {
        _viewModel = StateObject(wrappedValue: PriceAddOnsViewModel(
            settingsManager: SettingsManager.shared,
            notificationService: NotificationService(),
            energyDataService: EnergyDataService()
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            PriceAddOnsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PriceAddOnsCard {
                        Text("Add-ons are applied to prices everywhere throughout AWattPrice.".localized())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            PriceFormulaView(draft: viewModel.draft)
                        }
                    }

                    ForEach(Setting.normalizedPriceAddOnOrder(viewModel.draft.addOnOrder), id: \.self) { kind in
                        priceAddOnSection(for: kind)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear { itemHeights[kind] = geo.size.height }
                                        .onChange(of: geo.size.height) { _, h in itemHeights[kind] = h }
                                }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.draft.hasActiveAddOns)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.draft.fixedPriceAddOn.isActivePriceComponent)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.draft.percentagePriceAddOn.isActivePriceComponent)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.draft.monthlyFixedCostPrice.isActivePriceComponent)
            }

        }
        .background(SavingStatusWindowOverlay(isVisible: viewModel.isSaving).frame(width: 0, height: 0))
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

    @ViewBuilder
    private func priceAddOnSection(for kind: PriceAddOnKind) -> some View {
        ReorderablePriceAddOnSection(
            kind: kind,
            canReorder: viewModel.draft.canReorderAddOns && viewModel.draft.isActive(kind),
            isDragging: draggingKind == kind,
            dragTranslation: draggingKind == kind ? dragTranslation : 0,
            onDragChanged: { handleDragChanged(kind: kind, value: $0) },
            onDragEnded: { handleDragEnded(kind: kind, value: $0) }
        ) {
            switch kind {
            case .fixed:
                VStack(alignment: .leading, spacing: 16) {
                    PriceModelInputRow(
                        title: "Fixed Add-on",
                        subtitle: nil,
                        unit: "ct/kWh",
                        value: $viewModel.draft.fixedPriceAddOn,
                        isInputActive: $isInputActive,
                        activeTint: viewModel.draft.fixedPriceAddOn.isActivePriceComponent ? .green : nil
                    )
                }
            case .percentage:
                VStack(alignment: .leading, spacing: 16) {
                    PriceModelInputRow(
                        title: "Percentage Add-on",
                        subtitle: nil,
                        unit: "%",
                        value: $viewModel.draft.percentagePriceAddOn,
                        isInputActive: $isInputActive,
                        activeTint: viewModel.draft.percentagePriceAddOn.isActivePriceComponent ? .cyan : nil
                    )
                }
            case .monthly:
                VStack(alignment: .leading, spacing: 16) {
                    PriceModelInputRow(
                        title: "Monthly Fixed Cost",
                        subtitle: "Basic electricity provider fee.",
                        unit: "EUR/month",
                        value: $viewModel.draft.monthlyFixedCost,
                        isInputActive: $isInputActive,
                        activeTint: viewModel.draft.monthlyFixedCostPrice.isActivePriceComponent ? .blue : nil
                    )

                    PriceModelInputRow(
                        title: "Annual Consumption",
                        subtitle: "Used to spread fixed monthly costs over each kWh.",
                        unit: "kWh/year",
                        value: $viewModel.draft.annualConsumptionKWh,
                        isInputActive: $isInputActive,
                        activeTint: viewModel.draft.monthlyFixedCostPrice.isActivePriceComponent ? .blue : nil
                    )

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Monthly fixed cost adds".localized())
                            .font(.footnote.weight(.semibold))

                        PriceValueLabel(
                            value: viewModel.draft.monthlyFixedCostPrice.priceAddOnSummaryText,
                            unit: "ct/kWh",
                            tint: Color.secondary,
                            size: 13
                        )

                        Text(".")
                            .font(.footnote.weight(.semibold))
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
    }

    private func handleDragChanged(kind: PriceAddOnKind, value: DragGesture.Value) {
        if draggingKind == nil {
            draggingKind = kind
            lastRawTranslation = 0
        }

        let raw = value.translation.height
        dragTranslation += raw - lastRawTranslation
        lastRawTranslation = raw

        // Swap with adjacent active item when the drag crosses the midpoint of that item.
        // Both the order change and the offset correction are wrapped in the same animation so
        // the dragged card appears stationary while neighbours spring into their new slots.
        var keepChecking = true
        while keepChecking {
            keepChecking = false
            let active = viewModel.draft.activeAddOnKinds
            guard let idx = active.firstIndex(of: kind) else { break }

            if dragTranslation > 0, idx < active.count - 1 {
                let next = active[idx + 1]
                let threshold = (itemHeights[next] ?? 100) + cardSpacing
                if dragTranslation > threshold / 2 {
                    withAnimation(.interactiveSpring(response: 0.25)) {
                        viewModel.draft.moveAddOn(kind, to: next)
                        dragTranslation -= threshold
                    }
                    keepChecking = true
                }
            } else if dragTranslation < 0, idx > 0 {
                let prev = active[idx - 1]
                let threshold = (itemHeights[prev] ?? 100) + cardSpacing
                if dragTranslation < -(threshold / 2) {
                    withAnimation(.interactiveSpring(response: 0.25)) {
                        viewModel.draft.moveAddOn(kind, to: prev)
                        dragTranslation += threshold
                    }
                    keepChecking = true
                }
            }
        }
    }

    private func handleDragEnded(kind: PriceAddOnKind, value: DragGesture.Value) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            draggingKind = nil
            dragTranslation = 0
        }
        lastRawTranslation = 0
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        uploadFeedbackTask?.cancel()
        guard viewModel.hasUnsavedChanges, viewModel.draft.canSave else {
            viewModel.cancelPendingUploadFeedback()
            return
        }

        if viewModel.needsServerSave {
            uploadFeedbackTask = Task {
                try? await Task.sleep(nanoseconds: PriceAddOnsViewModel.Timing.uploadIndicatorDelayNanoseconds)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    viewModel.beginUploadFeedback()
                }
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
