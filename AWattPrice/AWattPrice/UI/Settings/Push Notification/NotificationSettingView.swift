//
//  NotificationSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI
import UIKit

private struct NotificationSettingsBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppTheme.screenBackground(for: colorScheme)
            .ignoresSafeArea()
    }
}

private struct NotificationSettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        AppCard(cornerRadius: 20, padding: 18, spacing: 16) {
            content
        }
    }
}

private struct NotificationSettingsBadge: View {
    let text: String
    let tint: Color
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            }

            Text(text.localized())
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
        .animation(.easeInOut(duration: 0.18), value: isLoading)
    }
}

private enum NotificationThresholdField: Hashable {
    case priceBelow
    case priceAbove
}

struct NotificationDraft: Equatable {
    var priceBelowEnabled: Bool
    var priceBelowThreshold: String
    var priceAboveEnabled: Bool
    var priceAboveThreshold: String
    var dailySummaryEnabled: Bool

    init(setting: Setting) {
        priceBelowEnabled = setting.priceDropsBelowEnabled
        priceBelowThreshold = setting.priceDropsBelowThreshold.priceString ?? ""
        priceAboveEnabled = setting.priceRisesAboveEnabled
        priceAboveThreshold = setting.priceRisesAboveThreshold.priceString ?? ""
        dailySummaryEnabled = setting.dailySummaryEnabled
    }

    var activeRuleCount: Int {
        var count = 0
        if priceBelowEnabled { count += 1 }
        if priceAboveEnabled { count += 1 }
        if dailySummaryEnabled { count += 1 }
        return count
    }

    var hasAnyActiveRule: Bool {
        activeRuleCount > 0
    }

    var canSave: Bool {
        if priceBelowEnabled, priceBelowThreshold.integerValue == nil { return false }
        if priceAboveEnabled, priceAboveThreshold.integerValue == nil { return false }
        return true
    }
}

@MainActor
class NotificationSettingViewModel: ObservableObject {
    enum Timing {
        static let temporaryBannerApproximationNanoseconds: UInt64 = 8_200_000_000
        static let minimumUploadingNanoseconds: UInt64 = 1_600_000_000
        static let uploadIndicatorDelayNanoseconds: UInt64 = 450_000_000
    }

    var settingsManager: SettingsManager
    var notificationService: NotificationService
    private var uploadIndicatorStart: Date?
    private var isUploadRequestInFlight = false

    @Published var draft: NotificationDraft
    @Published private(set) var savedDraft: NotificationDraft
    @Published var isSaving = false
    @Published var uploadFailed = false
    @Published var exampleMessage: String?
    @Published var exampleMessageIsError = false
    @Published var exampleLoadingRule: NotificationRuleType?
    @Published var sentExampleRule: NotificationRuleType?

    init(settingsManager: SettingsManager, notificationService: NotificationService) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        let draft = NotificationDraft(setting: settingsManager.setting)
        self.draft = draft
        self.savedDraft = draft
    }

    var hasUnsavedChanges: Bool {
        draft != savedDraft
    }

    var needsServerSave: Bool {
        draft.hasAnyActiveRule || savedDraft.hasAnyActiveRule
    }

    func refreshAccessState() async {
        await notificationService.updateAccessStates()
    }

    func resetFromSettings() {
        let currentDraft = NotificationDraft(setting: settingsManager.setting)
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
        let previousValues = NotificationDraft(setting: settingsManager.setting)
        let uploadStart = uploadIndicatorStart ?? Date()
        isUploadRequestInFlight = true

        settingsManager.setting.priceDropsBelowEnabled = draftToSave.priceBelowEnabled
        settingsManager.setting.priceDropsBelowThreshold = draftToSave.priceBelowThreshold.integerValue ?? 0
        settingsManager.setting.priceRisesAboveEnabled = draftToSave.priceAboveEnabled
        settingsManager.setting.priceRisesAboveThreshold = draftToSave.priceAboveThreshold.integerValue ?? 0
        settingsManager.setting.dailySummaryEnabled = draftToSave.dailySummaryEnabled

        let configuration = notificationConfiguration(for: draftToSave, token: nil)

        if needsServerSave == false {
            settingsManager.saveChanges()
            savedDraft = draftToSave
            isUploadRequestInFlight = false
            uploadIndicatorStart = nil
            isSaving = false
            uploadFailed = false
            return
        }

        isSaving = true
        uploadFailed = false

        do {
            _ = try await notificationService.changeNotificationConfiguration(configuration, settingsManager.setting)
            await waitForMinimumUploadingTime(since: uploadStart)
            settingsManager.saveChanges()
            savedDraft = draftToSave
            isUploadRequestInFlight = false
            uploadIndicatorStart = nil
            isSaving = false
        } catch {
            print("Failed to update notification profile: \(error)")
            await waitForMinimumUploadingTime(since: uploadStart)
            settingsManager.setting.priceDropsBelowEnabled = previousValues.priceBelowEnabled
            settingsManager.setting.priceDropsBelowThreshold = previousValues.priceBelowThreshold.integerValue ?? 0
            settingsManager.setting.priceRisesAboveEnabled = previousValues.priceAboveEnabled
            settingsManager.setting.priceRisesAboveThreshold = previousValues.priceAboveThreshold.integerValue ?? 0
            settingsManager.setting.dailySummaryEnabled = previousValues.dailySummaryEnabled
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

    func showExample(for ruleType: NotificationRuleType) async {
        guard canRequestExample(for: ruleType), exampleLoadingRule == nil else { return }

        exampleLoadingRule = ruleType

        do {
            let response = try await notificationService.notificationExample(
                for: ruleType,
                notificationConfiguration: notificationConfiguration(forExample: ruleType)
            )

            if let response, try await notificationService.presentNotificationExample(response) {
                sentExampleRule = ruleType
                exampleMessage = "Focus modes may silence example notifications.".localized()
                exampleMessageIsError = false
                clearInformationalExampleMessageLater()
            } else {
                try await presentFallbackExample(for: ruleType)
            }
        } catch {
            print("Failed to load notification example: \(error)")
            do {
                try await presentFallbackExample(for: ruleType)
            } catch {
                exampleMessage = "Notification example could not be loaded.".localized()
                exampleMessageIsError = true
            }
        }

        exampleLoadingRule = nil

        if sentExampleRule == ruleType {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if self.sentExampleRule == ruleType {
                    self.sentExampleRule = nil
                }
            }
        }
    }

    private func presentFallbackExample(for ruleType: NotificationRuleType) async throws {
        let fallbackResponse = notificationService.fallbackNotificationExample(for: ruleType)
        if try await notificationService.presentNotificationExample(fallbackResponse) {
            sentExampleRule = ruleType
            exampleMessage = "Focus modes may silence example notifications.".localized()
            exampleMessageIsError = false
            clearInformationalExampleMessageLater()
        } else {
            exampleMessage = "Notification example could not be loaded.".localized()
            exampleMessageIsError = true
        }
    }

    private func clearInformationalExampleMessageLater() {
        Task {
            try? await Task.sleep(nanoseconds: Timing.temporaryBannerApproximationNanoseconds)
            if self.exampleMessageIsError == false {
                self.exampleMessage = nil
            }
        }
    }

    func canRequestExample(for ruleType: NotificationRuleType) -> Bool {
        switch ruleType {
        case .priceBelow:
            return draft.priceBelowThreshold.integerValue != nil
        case .priceAbove:
            return draft.priceAboveThreshold.integerValue != nil
        case .dailySummary:
            return true
        }
    }

    private func notificationConfiguration(forExample ruleType: NotificationRuleType) -> NotificationConfiguration {
        var exampleDraft = draft
        switch ruleType {
        case .priceBelow:
            exampleDraft.priceBelowEnabled = true
            exampleDraft.priceAboveEnabled = false
            exampleDraft.dailySummaryEnabled = false
        case .priceAbove:
            exampleDraft.priceBelowEnabled = false
            exampleDraft.priceAboveEnabled = true
            exampleDraft.dailySummaryEnabled = false
        case .dailySummary:
            exampleDraft.priceBelowEnabled = false
            exampleDraft.priceAboveEnabled = false
            exampleDraft.dailySummaryEnabled = true
        }

        return notificationConfiguration(for: exampleDraft, token: "example")
    }

    private func notificationConfiguration(for draft: NotificationDraft, token: String?) -> NotificationConfiguration {
        let general = GeneralNotificationConfiguration(
            marketArea: settingsManager.setting.marketArea,
            tax: true,
            baseFee: settingsManager.setting.totalPriceAddOn,
            percentageAddOn: settingsManager.setting.percentagePriceAddOn
        )
        let rules = NotificationRulesConfiguration(
            priceBelow: PriceBelowNotificationNotificationConfiguration(
                active: draft.priceBelowEnabled,
                threshold: draft.priceBelowEnabled ? draft.priceBelowThreshold.integerValue : nil
            ),
            priceAbove: PriceAboveNotificationConfiguration(
                active: draft.priceAboveEnabled,
                threshold: draft.priceAboveEnabled ? draft.priceAboveThreshold.integerValue : nil
            ),
            dailySummary: DailySummaryNotificationConfiguration(active: draft.dailySummaryEnabled)
        )

        return NotificationConfiguration(token: token, general: general, rules: rules)
    }

}

private struct NotificationRuleCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let ruleType: NotificationRuleType
    let exampleLoadingRule: NotificationRuleType?
    let sentExampleRule: NotificationRuleType?
    let canShowExample: Bool
    let onExample: () -> Void
    @Binding var isEnabled: Bool
    @ViewBuilder let content: Content

    private var animatedIsEnabled: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.24)) {
                    isEnabled = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title.localized())
                        .font(.headline)
                    Text((try? AttributedString(markdown: subtitle.localized())) ?? AttributedString(subtitle.localized()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    Button {
                        onExample()
                    } label: {
                        HStack(spacing: 4) {
                            ZStack(alignment: .trailing) {
                                Text("Send example".localized())
                                    .font(.caption)
                                    .opacity(sentExampleRule == ruleType ? 0 : 1)
                                    .offset(y: sentExampleRule == ruleType ? -4 : 0)

                                Text("Sent".localized())
                                    .font(.caption.weight(.semibold))
                                    .opacity(sentExampleRule == ruleType ? 1 : 0)
                                    .offset(y: sentExampleRule == ruleType ? 0 : 4)
                            }
                            .animation(.easeInOut(duration: 0.18), value: sentExampleRule)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(exampleLoadingRule == ruleType || canShowExample == false)
                    .opacity(canShowExample ? 1 : 0.45)

                    Toggle(title.localized(), isOn: animatedIsEnabled)
                        .labelsHidden()
                }
            }

            if isEnabled {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct ThresholdInput: View {
    @Environment(\.colorScheme) private var colorScheme

    let label: String
    let field: NotificationThresholdField
    @Binding var value: String
    let focusedField: FocusState<NotificationThresholdField?>.Binding

    private var inputFill: Color {
        AppTheme.fieldBackground(for: colorScheme)
    }

    private var inputStroke: Color {
        AppTheme.cardStroke(for: colorScheme)
    }

    private func integerText(from input: String) -> String {
        var output = ""
        var canAddMinus = true

        for character in input {
            if character == "-", canAddMinus, output.isEmpty {
                output.append(character)
                canAddMinus = false
            } else if character.isNumber {
                output.append(character)
                canAddMinus = false
            }
        }

        return output
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.localized())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                TextField("0", text: $value)
                    .keyboardType(.numbersAndPunctuation)
                    .focused(focusedField, equals: field)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .onChange(of: value) { _, newValue in
                        let sanitizedValue = integerText(from: newValue)
                        if sanitizedValue != newValue {
                            value = sanitizedValue
                        }
                    }

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
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField.wrappedValue = field
            }
        }
    }
}

struct NotificationSettingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var notificationService: NotificationService
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var uploadFeedbackTask: Task<Void, Never>?
    @FocusState private var focusedThresholdField: NotificationThresholdField?
    @StateObject private var viewModel = NotificationSettingViewModel(
        settingsManager: SettingsManager.shared,
        notificationService: NotificationService()
    )

    var body: some View {
        ZStack(alignment: .top) {
            NotificationSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if notificationService.accessState == .rejected {
                        NotificationSettingsCard {
                            NoNotificationAccessView()
                        }
                    }

                    if let exampleMessage = viewModel.exampleMessage {
                        Text(exampleMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(viewModel.exampleMessageIsError ? AppTheme.error : Color.blue)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    if viewModel.uploadFailed {
                        Text("Notification settings could not be saved to the server. Your previous settings were restored.".localized())
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.error)
                    }
                    
                    NotificationSettingsCard {
                        NotificationRuleCard(
                            title: "Price Below",
                            subtitle: "Cheap hours **tomorrow**.",
                            systemImage: "bell.badge.fill",
                            tint: AppTheme.success,
                            ruleType: .priceBelow,
                            exampleLoadingRule: viewModel.exampleLoadingRule,
                            sentExampleRule: viewModel.sentExampleRule,
                            canShowExample: viewModel.canRequestExample(for: .priceBelow),
                            onExample: { Task { await viewModel.showExample(for: .priceBelow) } },
                            isEnabled: $viewModel.draft.priceBelowEnabled
                        ) {
                            ThresholdInput(
                                label: "Alert below",
                                field: .priceBelow,
                                value: $viewModel.draft.priceBelowThreshold,
                                focusedField: $focusedThresholdField
                            )
                        }
                    }

                    NotificationSettingsCard {
                        NotificationRuleCard(
                            title: "Price Above",
                            subtitle: "Expensive hours **tomorrow**.",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: AppTheme.error,
                            ruleType: .priceAbove,
                            exampleLoadingRule: viewModel.exampleLoadingRule,
                            sentExampleRule: viewModel.sentExampleRule,
                            canShowExample: viewModel.canRequestExample(for: .priceAbove),
                            onExample: { Task { await viewModel.showExample(for: .priceAbove) } },
                            isEnabled: $viewModel.draft.priceAboveEnabled
                        ) {
                            ThresholdInput(
                                label: "Warn above",
                                field: .priceAbove,
                                value: $viewModel.draft.priceAboveThreshold,
                                focusedField: $focusedThresholdField
                            )
                        }
                    }

                    NotificationSettingsCard {
                        NotificationRuleCard(
                            title: "Daily Summary",
                            subtitle: "**Tomorrow's** price summary.",
                            systemImage: "list.bullet.rectangle.fill",
                            tint: AppTheme.accent,
                            ruleType: .dailySummary,
                            exampleLoadingRule: viewModel.exampleLoadingRule,
                            sentExampleRule: viewModel.sentExampleRule,
                            canShowExample: viewModel.canRequestExample(for: .dailySummary),
                            onExample: { Task { await viewModel.showExample(for: .dailySummary) } },
                            isEnabled: $viewModel.draft.dailySummaryEnabled
                        ) {
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }

        }
        .background(SavingStatusWindowOverlay(isVisible: viewModel.isSaving).frame(width: 0, height: 0))
        .animation(.easeInOut(duration: 0.18), value: viewModel.isSaving)
        .animation(.easeInOut(duration: 0.2), value: viewModel.exampleMessage)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedThresholdField = nil
                }
                .bold()
            }
        }
        .task {
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
            viewModel.resetFromSettings()
            await viewModel.refreshAccessState()
        }
        .onChange(of: viewModel.draft) { _, _ in
            scheduleAutoSave()
        }
        .onChange(of: viewModel.isSaving) { _, isSaving in
            if isSaving == false, viewModel.uploadFailed == false {
                scheduleAutoSave()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refreshAccessState() }
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

        if viewModel.needsServerSave {
            uploadFeedbackTask = Task {
                try? await Task.sleep(nanoseconds: NotificationSettingViewModel.Timing.uploadIndicatorDelayNanoseconds)
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

struct NoNotificationAccessView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Notifications are disabled.".localized(), systemImage: "bell.slash.fill")
                .font(.headline)

            Button("Open Settings App") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
    }
}

struct NotificationSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationSettingView()
                .environmentObject(SettingsManager.shared)
                .environmentObject(NotificationService())
        }
    }
}
