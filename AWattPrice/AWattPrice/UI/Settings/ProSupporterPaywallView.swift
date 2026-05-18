//
//  ProSupporterPaywallView.swift
//  AWattPrice
//
//  Created by Codex on 14.05.26.
//

import StoreKit
import SwiftUI
import EffectsLibrary

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
        title: "Price add-ons",
        subtitle: "Include your provider’s fees and taxes in displayed prices.",
        systemImage: "sum",
        tint: .purple
    ),
    ProBenefit(
        title: "Advanced insights",
        subtitle: "Cheapest windows, expensive peaks, and renewable mix infos.",
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
        title: "Home Screen widgets",
        subtitle: "Keep prices visible at a glance outside the app.",
        systemImage: "square.grid.2x2.fill",
        tint: .cyan
    ),
    ProBenefit(
        title: "Development",
        subtitle: "Helps keep AWattPrice maintained.",
        systemImage: "heart.fill",
        tint: .green
    ),
]

struct ProSupporterPaywallView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var proStore: ProSupporterStore
    @State private var selectedPlan: ProSupporterPlan = .yearly
    @State private var showsPurchaseConfetti = false
    @State private var purchaseConfettiID = 0

    var body: some View {
        ZStack {
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

            if showsPurchaseConfetti && reduceMotion == false {
                PurchaseConfettiOverlay()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsPurchaseConfetti)
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
                .foregroundStyle(proStore.hasPro ? AppTheme.success : .green)

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
            Text("What you get with Pro Supporter".localized())
                .font(.headline)

            ForEach(Array(proBenefits.enumerated()), id: \.element.id) { index, benefit in
                HStack(alignment: .top, spacing: 12) {
                    AnimatedBenefitIcon(
                        systemImage: benefit.systemImage,
                        tint: benefit.tint,
                        index: index
                    )

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
                        selectPlan(plan)
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
            purchase(product)
        } label: {
            HStack(spacing: 8) {
                if proStore.purchaseInProgressProductIdentifier == selectedPlan.rawValue {
                    ProgressView()
                        .tint(.white)
                }

                Text(purchaseButtonTitle)
                    .contentTransition(.opacity)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                ElectricCTAHighlight(isDisabled: purchaseButtonIsDisabled)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .disabled(purchaseButtonIsDisabled)
        .opacity(purchaseButtonIsDisabled ? 0.55 : 1)
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
                .font(.headline)
            
            Text("Hi! I’m a student and developing AWattPrice in my free time. The goal is to make dynamic electricity prices easier to follow. Pro helps cover server and license costs and keeps the app running. I hope you like the app!".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.blue.opacity(0.16), lineWidth: 1)
        )
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

    private var purchaseButtonIsDisabled: Bool {
        proStore.product(for: selectedPlan) == nil || proStore.isBusy
    }

    private func selectPlan(_ plan: ProSupporterPlan) {
        guard selectedPlan != plan else { return }

        if reduceMotion {
            selectedPlan = plan
        } else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                selectedPlan = plan
            }
        }
    }

    private func purchase(_ product: Product) {
        Task { @MainActor in
            let hadProBeforePurchase = proStore.hasPro

            await proStore.purchase(product)

            guard hadProBeforePurchase == false,
                  proStore.hasPro,
                  proStore.messageIsError == false else {
                return
            }

            showPurchaseConfetti()
        }
    }

    private func showPurchaseConfetti() {
        guard reduceMotion == false else { return }

        purchaseConfettiID += 1
        let currentConfettiID = purchaseConfettiID

        showsPurchaseConfetti = true

        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)

            await MainActor.run {
                guard purchaseConfettiID == currentConfettiID else { return }
                showsPurchaseConfetti = false
            }
        }
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

private struct PurchaseConfettiOverlay: View {
    private let config = ConfettiConfig(
        content: [
            .shape(.circle, UIColor.systemOrange, 0.75),
            .shape(.triangle, UIColor.systemGreen, 0.70),
            .shape(.square, UIColor.systemCyan, 0.70),
            .shape(.circle, UIColor.systemYellow, 0.65)
        ],
        intensity: .medium,
        lifetime: .short,
        initialVelocity: .medium,
        fadeOut: .fast,
        spreadRadius: .high,
        emitterPosition: .top,
        clipsToBounds: true,
        fallDirection: .downwards
    )

    var body: some View {
        ConfettiView(config: config)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct AnimatedBenefitIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isActive = false

    let systemImage: String
    let tint: Color
    let index: Int

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(isActive && reduceMotion == false ? 0.38 : 0.16), lineWidth: 1)
            }
            .offset(y: isActive && reduceMotion == false ? -4 : 0)
            .rotationEffect(.degrees(isActive && reduceMotion == false ? (index.isMultiple(of: 2) ? -3 : 3) : 0))
            .scaleEffect(isActive && reduceMotion == false ? 1.05 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.58), value: isActive)
            .accessibilityHidden(true)
            .task(id: reduceMotion) {
                isActive = false
                guard reduceMotion == false else { return }

                let initialDelay = UInt64(450_000_000 * UInt64(index + 1))
                try? await Task.sleep(nanoseconds: initialDelay)

                while Task.isCancelled == false {
                    isActive = true
                    try? await Task.sleep(nanoseconds: 340_000_000)
                    isActive = false
                    try? await Task.sleep(nanoseconds: 5_200_000_000)
                }
            }
    }
}

private struct ElectricCTAHighlight: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isDisabled: Bool

    private let duration: TimeInterval = 3.2

    var body: some View {
        if isDisabled {
            Color.clear
        } else if reduceMotion {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        } else {
            TimelineView(.animation) { context in
                let progress = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: duration) / duration

                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.34)
                        .rotationEffect(.degrees(-12))
                        .offset(x: (geometry.size.width * CGFloat(progress)) - (geometry.size.width * 0.28))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

private struct ProSupporterPlanRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .scaleEffect(isSelected && reduceMotion == false ? 1.08 : 1)

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
                    .shadow(
                        color: isSelected ? AppTheme.accent.opacity(reduceMotion ? 0.08 : 0.16) : .clear,
                        radius: reduceMotion ? 4 : 8,
                        y: reduceMotion ? 1 : 3
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(isSelected ? AppTheme.accent.opacity(0.58) : Color.secondary.opacity(0.10), lineWidth: isSelected ? 1.4 : 1)
                    )
            )
            .scaleEffect(isSelected && reduceMotion == false ? 1.01 : 1)
            .animation(selectionAnimation, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.86)
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
