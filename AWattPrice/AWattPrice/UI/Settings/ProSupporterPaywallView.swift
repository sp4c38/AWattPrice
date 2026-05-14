//
//  ProSupporterPaywallView.swift
//  AWattPrice
//
//  Created by Codex on 14.05.26.
//

import StoreKit
import SwiftUI

enum ProSupporterPaywallContext {
    case insights
    case notifications
    case settings

    var title: String {
        switch self {
        case .insights:
            return "Unlock advanced insights"
        case .notifications:
            return "Unlock smart notifications"
        case .settings:
            return "AWattPrice Pro Supporter"
        }
    }

    var subtitle: String {
        switch self {
        case .insights:
            return "Plan electricity usage with richer price windows, renewable mix, history, and detailed comparisons."
        case .notifications:
            return "Get price alerts and daily summaries when new electricity prices are available."
        case .settings:
            return "Support AWattPrice and unlock smarter planning, notifications, and advanced insights."
        }
    }
}

private struct ProBenefit: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
}

private let proBenefits = [
    ProBenefit(
        title: "Smart price notifications",
        subtitle: "Receive price-below, price-above, and daily summary alerts.",
        systemImage: "bell.badge.fill"
    ),
    ProBenefit(
        title: "Advanced insights",
        subtitle: "See cheapest and most expensive windows, price ranges, and renewable mix details.",
        systemImage: "chart.bar.xaxis"
    ),
    ProBenefit(
        title: "Support independent development",
        subtitle: "Help keep AWattPrice maintained by a student building it in his free time.",
        systemImage: "heart.fill"
    ),
]

struct ProSupporterPaywallView: View {
    @EnvironmentObject private var proStore: ProSupporterStore
    @State private var selectedPlan: ProSupporterPlan = .yearly

    let context: ProSupporterPaywallContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if proStore.hasPro {
                    activeSupporterCard
                } else {
                    benefitsCard
                    productSelectionCard
                    supporterNote
                }

                if let message = proStore.message {
                    messageView(message, isError: proStore.messageIsError)
                }

                legalLinks
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .appScreenBackground()
        .navigationTitle("AWattPrice Pro")
        .navigationBarTitleDisplayMode(.large)
        .task {
            proStore.start()
        }
    }

    private var header: some View {
        AppCard(cornerRadius: 22, padding: 20, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: proStore.hasPro ? "checkmark.seal.fill" : "bolt.heart.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(context.title.localized())
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(context.subtitle.localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var activeSupporterCard: some View {
        AppCard(cornerRadius: 20, padding: 18, spacing: 14) {
            Label {
                Text("Pro Supporter is active".localized())
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
    }

    private var benefitsCard: some View {
        AppCard(cornerRadius: 20, padding: 18, spacing: 16) {
            ForEach(proBenefits) { benefit in
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: benefit.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
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

    private var productSelectionCard: some View {
        AppCard(cornerRadius: 20, padding: 18, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose your support".localized())
                    .font(.headline)

                Text("No free trial. No launch discount. Just a fair way to support the app.".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
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
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
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
            .padding(.vertical, 11)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.accent)
        .disabled(proStore.isBusy)
    }

    private var supporterNote: some View {
        AppCard(cornerRadius: 20, padding: 18, spacing: 8) {
            Text("Built by one student".localized())
                .font(.headline)

            Text("AWattPrice is an independent side project built in free time. Pro helps cover running costs and makes future improvements easier to keep shipping.".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button("Terms of Use".localized()) {
                    openAgreementLink((
                        "https://www.awattprice.com/terms_of_use/german.html",
                        "https://www.awattprice.com/terms_of_use/english.html"
                    ))
                }

                Text("·")
                    .foregroundStyle(.tertiary)

                Button("Privacy Policy".localized()) {
                    openAgreementLink((
                        "https://www.awattprice.com/privacy_policy/german.html",
                        "https://www.awattprice.com/privacy_policy/english.html"
                    ))
                }
            }

            Text("Subscriptions renew automatically unless canceled in your Apple Account settings. Lifetime is a one-time purchase.".localized())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    private var purchaseButtonTitle: String {
        if proStore.product(for: selectedPlan) == nil {
            return "Pro options unavailable"
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

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title.localized())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let badge = plan.badge {
                            Text(badge.localized())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppTheme.accent.opacity(0.12), in: Capsule())
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.10) : Color.secondary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? AppTheme.accent.opacity(0.55) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ProSupporterPaywallView(context: .settings)
            .environmentObject(ProSupporterStore())
    }
}
