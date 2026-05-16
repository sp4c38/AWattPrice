//
//  ProSupporterPaywallView.swift
//  AWattPrice
//
//  Created by Codex on 14.05.26.
//

import StoreKit
import SwiftUI

private struct ProBenefit: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
}

private let proBenefits = [
    ProBenefit(
        title: "Price history",
        subtitle: "Look back at previous days directly in the price graph.",
        systemImage: "clock.arrow.circlepath",
        tint: .indigo
    ),
    ProBenefit(
        title: "Advanced insights",
        subtitle: "Cheapest windows, expensive peaks, and renewable mix.",
        systemImage: "chart.bar.xaxis",
        tint: .blue
    ),
    ProBenefit(
        title: "Smart notifications",
        subtitle: "Price alerts and daily summaries when new prices arrive.",
        systemImage: "bell.badge.fill",
        tint: .teal
    ),
    ProBenefit(
        title: "Price add-ons",
        subtitle: "Include your personal markups in displayed prices.",
        systemImage: "sum",
        tint: .purple
    ),
    ProBenefit(
        title: "Home Screen widgets",
        subtitle: "Keep prices visible at a glance outside the app.",
        systemImage: "square.grid.2x2.fill",
        tint: .cyan
    ),
    ProBenefit(
        title: "Independent development",
        subtitle: "Helps keep AWattPrice maintained in my free time.",
        systemImage: "heart.fill",
        tint: AppTheme.accent
    ),
]

struct ProSupporterPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var proStore: ProSupporterStore
    @State private var selectedPlan: ProSupporterPlan = .yearly

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if proStore.hasPro {
                    activeSupporterSection
                } else {
                    supporterNote
                    benefitsSection
                    productSection
                        .padding(.top, 10)
                }

                if let message = proStore.message {
                    messageView(message, isError: proStore.messageIsError)
                }

                legalLinks
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.screenBackground(for: .light).opacity(0.001))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done".localized()) {
                    dismiss()
                }
            }
        }
        .task {
            proStore.start()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: proStore.hasPro ? "checkmark.seal.fill" : "heart.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(proStore.hasPro ? AppTheme.success : AppTheme.accent)

            Text("AWattPrice Pro Supporter".localized())
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private var activeSupporterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Pro is active".localized())
                    .font(.headline)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.success)
            }

            Text("Thank you for supporting AWattPrice. Your Pro features are unlocked on this device.".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            restoreButton
        }
        .padding(16)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What Pro Supporter unlocks for you".localized())
                .font(.headline)

            ForEach(proBenefits) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: benefit.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(benefit.tint)
                        .frame(width: 30, height: 30)
                        .background(benefit.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.title.localized())
                            .font(.subheadline.weight(.semibold))

                        Text(benefit.subtitle.localized())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 9) {
                ForEach(ProSupporterPlan.allCases) { plan in
                    ProSupporterPlanRow(
                        plan: plan,
                        product: proStore.product(for: plan),
                        isSelected: selectedPlan == plan,
                        isLoading: proStore.purchaseInProgressProductIdentifier == plan.rawValue
                    ) {
                        selectedPlan = plan
                    }
                }
            }

            purchaseButton
            restoreButton

            if proStore.isLoadingProducts {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading Pro options".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            guard let product = proStore.product(for: selectedPlan) else { return }
            Task {
                await proStore.purchase(product)
            }
        } label: {
            HStack(spacing: 8) {
                if proStore.purchaseInProgressProductIdentifier == selectedPlan.rawValue {
                    ProgressView()
                        .tint(.white)
                }

                Text(purchaseButtonTitle)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(proStore.product(for: selectedPlan) == nil || proStore.isBusy)
        .opacity(proStore.product(for: selectedPlan) == nil || proStore.isBusy ? 0.55 : 1)
    }

    private var restoreButton: some View {
        Button {
            Task {
                await proStore.restorePurchases()
            }
        } label: {
            HStack(spacing: 8) {
                if proStore.isRestoringPurchases {
                    ProgressView()
                        .controlSize(.small)
                }

                Text("Restore Purchases".localized())
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.accent)
        .disabled(proStore.isBusy)
    }

    private var supporterNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A note from the developer".localized())
                .font(.subheadline.weight(.semibold))

            Text("Hi! I’m a student and build AWattPrice in my free time to make dynamic electricity prices easier to follow. Pro helps cover server and license costs and keeps the app running. I hope you like AWattPrice!".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button("Terms of Use".localized()) {
                    openAgreementLink((
                        "https://www.awattprice.com/terms_of_use/?lang=de",
                        "https://www.awattprice.com/terms_of_use/?lang=en"
                    ))
                }

                Text("·")
                    .foregroundStyle(.tertiary)

                Button("Privacy Policy".localized()) {
                    openAgreementLink((
                        "https://www.awattprice.com/privacy_policy/?lang=de",
                        "https://www.awattprice.com/privacy_policy/?lang=en"
                    ))
                }
            }

            Text("Monthly and yearly plans renew automatically. Lifetime is a one-time purchase.".localized())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }

    private var purchaseButtonTitle: String {
        if proStore.product(for: selectedPlan) == nil {
            return "Pro options unavailable".localized()
        }

        return String(format: "Continue with %@".localized(), selectedPlan.title.localized())
    }

    private func messageView(_ message: String, isError: Bool) -> some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isError ? AppTheme.error : AppTheme.success)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((isError ? AppTheme.error : AppTheme.success).opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProSupporterPlanRow: View {
    let plan: ProSupporterPlan
    let product: Product?
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AppTheme.accent : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(plan.title.localized())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let badge = plan.badge {
                            Text(badge.localized())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }

                    Text(plan.subtitle.localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(product?.displayPrice ?? plan.expectedPrice)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.10) : Color.secondary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(isSelected ? AppTheme.accent.opacity(0.45) : Color.secondary.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Not subscribed") {
    NavigationStack {
        ProSupporterPaywallView()
            .environmentObject(ProSupporterStore.preview(hasPro: false))
    }
}

#Preview("Subscribed") {
    NavigationStack {
        ProSupporterPaywallView()
            .environmentObject(ProSupporterStore.preview(hasPro: true))
    }
}
