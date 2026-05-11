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

    var body: some View {
        Text(text.localized())
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
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

struct NotificationExamplePreview: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

@MainActor
class NotificationSettingViewModel: ObservableObject {
    var settingsManager: SettingsManager
    var notificationService: NotificationService

    @Published var draft: NotificationDraft
    @Published private(set) var savedDraft: NotificationDraft
    @Published var isSaving = false
    @Published var uploadFailed = false
    @Published var examplePreview: NotificationExamplePreview?
    @Published var exampleLoadingRule: NotificationRuleType?

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

    var statusBadge: (String, Color) {
        if isSaving {
            return ("Saving", .secondary)
        }

        if hasUnsavedChanges {
            return ("Unsaved", AppTheme.warning)
        }

        switch notificationService.accessState {
        case .granted:
            return draft.hasAnyActiveRule ? ("Ready", AppTheme.success) : ("Notifications off", .secondary)
        case .rejected:
            return ("Notifications Off", AppTheme.error)
        case .notAsked:
            return ("Not configured", AppTheme.warning)
        case .unknown:
            return ("Checking", .secondary)
        }
    }

    var activeRulesText: String {
        switch draft.activeRuleCount {
        case 0:
            return "No alerts active".localized()
        case 1:
            return "1 alert active".localized()
        default:
            return String(format: "%@ alerts active".localized(), String(draft.activeRuleCount))
        }
    }

    func refreshAccessState() async {
        await notificationService.updateAccessStates()
    }

    func resetFromSettings() {
        let currentDraft = NotificationDraft(setting: settingsManager.setting)
        draft = currentDraft
        savedDraft = currentDraft
        uploadFailed = false
    }

    func save() async {
        guard draft.canSave, isSaving == false else { return }

        let draftToSave = draft
        let previousValues = NotificationDraft(setting: settingsManager.setting)

        settingsManager.setting.priceDropsBelowEnabled = draftToSave.priceBelowEnabled
        settingsManager.setting.priceDropsBelowThreshold = draftToSave.priceBelowThreshold.integerValue ?? 0
        settingsManager.setting.priceRisesAboveEnabled = draftToSave.priceAboveEnabled
        settingsManager.setting.priceRisesAboveThreshold = draftToSave.priceAboveThreshold.integerValue ?? 0
        settingsManager.setting.dailySummaryEnabled = draftToSave.dailySummaryEnabled

        let configuration = notificationConfiguration(for: draftToSave, token: nil)

        isSaving = true
        uploadFailed = false

        do {
            _ = try await notificationService.changeNotificationConfiguration(configuration, settingsManager.setting)
            settingsManager.saveChanges()
            savedDraft = draftToSave
            isSaving = false
        } catch {
            print("Failed to update notification profile: \(error)")
            settingsManager.setting.priceDropsBelowEnabled = previousValues.priceBelowEnabled
            settingsManager.setting.priceDropsBelowThreshold = previousValues.priceBelowThreshold.integerValue ?? 0
            settingsManager.setting.priceRisesAboveEnabled = previousValues.priceAboveEnabled
            settingsManager.setting.priceRisesAboveThreshold = previousValues.priceAboveThreshold.integerValue ?? 0
            settingsManager.setting.dailySummaryEnabled = previousValues.dailySummaryEnabled
            isSaving = false
            uploadFailed = true
        }
    }

    func showExample(for ruleType: NotificationRuleType) async {
        guard canRequestExample(for: ruleType), exampleLoadingRule == nil else { return }

        exampleLoadingRule = ruleType

        do {
            let response = try await notificationService.notificationExample(
                for: ruleType,
                notificationConfiguration: notificationConfiguration(forExample: ruleType)
            )

            if let response, response.wouldSend {
                examplePreview = NotificationExamplePreview(
                    title: localizedNotificationText(
                        key: response.titleLocKey,
                        arguments: []
                    ),
                    body: localizedNotificationText(
                        key: response.bodyLocKey,
                        arguments: response.locArgs
                    )
                )
            } else {
                examplePreview = NotificationExamplePreview(
                    title: "No example available".localized(),
                    body: "With the current prices and threshold, this notification would not be sent.".localized()
                )
            }
        } catch {
            print("Failed to load notification example: \(error)")
            examplePreview = NotificationExamplePreview(
                title: "No example available".localized(),
                body: "Notification example could not be loaded.".localized()
            )
        }

        exampleLoadingRule = nil
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

    private func localizedNotificationText(key: String?, arguments: [String]) -> String {
        guard let key else { return "" }
        let format = key.localized()
        return String(format: format, arguments: arguments.map { $0 as CVarArg })
    }
}

private struct NotificationRuleCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let ruleType: NotificationRuleType
    let exampleLoadingRule: NotificationRuleType?
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
                    Text(subtitle.localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    Button {
                        onExample()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Example".localized())
                                .font(.caption.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(exampleLoadingRule != nil || canShowExample == false)
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

private struct NotificationExampleSheet: View {
    let preview: NotificationExamplePreview

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.title)
                        .font(.headline)
                    Text(preview.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(24)
        .presentationDetents([.height(190), .medium])
    }
}

private struct ThresholdInput: View {
    @Environment(\.colorScheme) private var colorScheme

    let label: String
    @Binding var value: String

    private var inputFill: Color {
        AppTheme.fieldBackground(for: colorScheme)
    }

    private var inputStroke: Color {
        AppTheme.cardStroke(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.localized())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                NumberField(
                    text: $value,
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
    }
}

struct NotificationSettingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var notificationService: NotificationService
    @State private var autoSaveTask: Task<Void, Never>?
    @StateObject private var viewModel = NotificationSettingViewModel(
        settingsManager: SettingsManager.shared,
        notificationService: NotificationService()
    )

    var body: some View {
        ZStack {
            NotificationSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NotificationSettingsCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notifications")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))

                                Text(viewModel.activeRulesText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                NotificationSettingsBadge(text: viewModel.statusBadge.0, tint: viewModel.statusBadge.1)
                            }

                            Spacer()

                            if viewModel.isSaving {
                                ProgressView()
                            }
                        }
                    }

                    if notificationService.accessState == .rejected {
                        NotificationSettingsCard {
                            NoNotificationAccessView()
                        }
                    }

                    NotificationSettingsCard {
                        NotificationRuleCard(
                            title: "Price Below",
                            subtitle: "Cheap hours tomorrow.",
                            systemImage: "bell.badge.fill",
                            tint: AppTheme.success,
                            ruleType: .priceBelow,
                            exampleLoadingRule: viewModel.exampleLoadingRule,
                            canShowExample: viewModel.canRequestExample(for: .priceBelow),
                            onExample: { Task { await viewModel.showExample(for: .priceBelow) } },
                            isEnabled: $viewModel.draft.priceBelowEnabled
                        ) {
                            ThresholdInput(label: "Alert below", value: $viewModel.draft.priceBelowThreshold)
                        }
                    }

                    NotificationSettingsCard {
                        NotificationRuleCard(
                            title: "Price Above",
                            subtitle: "Expensive hours tomorrow.",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: AppTheme.error,
                            ruleType: .priceAbove,
                            exampleLoadingRule: viewModel.exampleLoadingRule,
                            canShowExample: viewModel.canRequestExample(for: .priceAbove),
                            onExample: { Task { await viewModel.showExample(for: .priceAbove) } },
                            isEnabled: $viewModel.draft.priceAboveEnabled
                        ) {
                            ThresholdInput(label: "Warn above", value: $viewModel.draft.priceAboveThreshold)
                        }
                    }

                    NotificationSettingsCard {
                        NotificationRuleCard(
                            title: "Daily Summary",
                            subtitle: "Tomorrow's price summary.",
                            systemImage: "list.bullet.rectangle.fill",
                            tint: AppTheme.accent,
                            ruleType: .dailySummary,
                            exampleLoadingRule: viewModel.exampleLoadingRule,
                            canShowExample: viewModel.canRequestExample(for: .dailySummary),
                            onExample: { Task { await viewModel.showExample(for: .dailySummary) } },
                            isEnabled: $viewModel.draft.dailySummaryEnabled
                        ) {
                        }
                    }

                    if viewModel.uploadFailed {
                        Text("Notification settings could not be saved.".localized())
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.error)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewModel.examplePreview) { preview in
            NotificationExampleSheet(preview: preview)
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
        }
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        guard viewModel.hasUnsavedChanges, viewModel.draft.canSave else { return }

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
