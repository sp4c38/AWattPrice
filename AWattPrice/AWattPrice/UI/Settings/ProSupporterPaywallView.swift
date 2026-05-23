//
//  ProSupporterPaywallView.swift
//  AWattPrice
//
//  Created by Codex on 14.05.26.
//

import StoreKit
import SwiftUI
import UIKit

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
    @State private var purchaseCelebrationID = 0
    @State private var highlightedBenefitIndex: Int?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if proStore.hasPro {
                        activeSupporterExperience
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

        }
        .proSupporterPurchaseConfetti(trigger: $purchaseCelebrationID)
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
            if runsInPreview == false {
                proStore.start()
            }
        }
    }

    private var runsInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            headerIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle.localized())
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                if proStore.hasPro {
                    Text("Thank you for supporting AWattPrice!".localized())
                        .font(.subheadline)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, proStore.hasPro ? 14 : 0)
        .padding(.vertical, proStore.hasPro ? 12 : 0)
        .background {
            if proStore.hasPro {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.success.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.success.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }

    @ViewBuilder
    private var headerIcon: some View {
        if proStore.hasPro {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.success)
                .symbolEffect(.bounce, options: .nonRepeating, value: purchaseCelebrationID)
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "heart.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
        }
    }

    private var headerTitle: String {
        proStore.hasPro ? "Pro is active" : "AWattPrice Pro Supporter"
    }

    private var activeSupporterExperience: some View {
        VStack(alignment: .leading, spacing: 16) {
            ActiveSupporterBenefits(highlightedBenefitIndex: highlightedBenefitIndex)
            restoreButton
        }
        .task(id: reduceMotion) {
            await runBenefitHighlightAnimation()
        }
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
                        index: index,
                        isActive: highlightedBenefitIndex == index
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
        .task(id: reduceMotion) {
            await runBenefitHighlightAnimation()
        }
    }

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if proStore.availablePlans.isEmpty {
                unavailableProductsView
            } else {
                VStack(spacing: 9) {
                    ForEach(proStore.availablePlans) { plan in
                        if let product = proStore.product(for: plan) {
                            ProSupporterPlanRow(
                                plan: plan,
                                product: product,
                                isSelected: selectedPlan == plan,
                                isLoading: proStore.purchaseInProgressProductIdentifier == plan.rawValue
                            ) {
                                selectPlan(plan)
                            }
                        }
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
        .onChange(of: proStore.availablePlans.map(\.id)) { _, _ in
            selectAvailablePlanIfNeeded()
        }
    }

    private var unavailableProductsView: some View {
        Group {
            if proStore.isLoadingProducts {
                EmptyView()
            } else if proStore.message != nil {
                EmptyView()
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text("Pro options unavailable".localized())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            purchase(selectedPlan)
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
                        .tint(AppTheme.accent)
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
            
            Text("Hi! I’m a student and developing AWattPrice in my spare time. The goal is to make dynamic electricity prices easier to follow. Pro helps cover server and license costs and keeps the app running. I hope you like the app!".localized())
                .font(.subheadline)
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

            Text("Monthly and yearly plans renew automatically. Lifetime is a one-time purchase. All purchases include free family sharing.".localized())
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

    private func selectAvailablePlanIfNeeded() {
        guard proStore.product(for: selectedPlan) == nil,
              let firstAvailablePlan = proStore.availablePlans.first else {
            return
        }

        selectedPlan = firstAvailablePlan
    }

    private func purchase(_ plan: ProSupporterPlan) {
        Task { @MainActor in
            let hadProBeforePurchase = proStore.hasPro

            await proStore.purchase(plan)

            guard hadProBeforePurchase == false,
                  proStore.hasPro,
                  proStore.messageIsError == false else {
                return
            }

            showPurchaseCelebration()
        }
    }

    private func showPurchaseCelebration() {
        guard reduceMotion == false else { return }
        purchaseCelebrationID += 1
    }

    @MainActor
    private func runBenefitHighlightAnimation() async {
        highlightedBenefitIndex = nil
        guard reduceMotion == false else { return }

        try? await Task.sleep(nanoseconds: 450_000_000)

        while Task.isCancelled == false {
            for index in proBenefits.indices {
                guard Task.isCancelled == false else { return }
                highlightedBenefitIndex = index
                try? await Task.sleep(nanoseconds: 340_000_000)
                guard Task.isCancelled == false else { return }
                highlightedBenefitIndex = nil
                try? await Task.sleep(nanoseconds: 110_000_000)
            }

            try? await Task.sleep(nanoseconds: 2_500_000_000)
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

private extension View {
    func proSupporterPurchaseConfetti(trigger: Binding<Int>) -> some View {
        overlay {
            ProSupporterCelebrationEmitter(trigger: trigger)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct ProSupporterCelebrationEmitter: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var trigger: Int

    func makeUIView(context: Context) -> ProSupporterCelebrationView {
        ProSupporterCelebrationView()
    }

    func updateUIView(_ view: ProSupporterCelebrationView, context: Context) {
        guard trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger

        guard trigger > 0,
              reduceMotion == false else {
            view.cancel()
            return
        }

        view.playWhenReady()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastTrigger = 0
    }
}

private struct ProSupporterCelebrationConfig {
    let burstDuration: TimeInterval = 3.2
    let cleanupDelay: TimeInterval = 6.8
    let emitterWidth: CGFloat = 420
    let emitterTopRatio: CGFloat = 0.18
    let minimumEmitterY: CGFloat = 120
    let maximumEmitterY: CGFloat = 220
    let spawnPointSpacing: CGFloat = 104

    let heartBirthRate: Float = 30
    let boltBirthRate: Float = 34

    let heartScale: CGFloat = 0.52
    let boltScale: CGFloat = 0.54

    let emojiLifetime: Float = 4.35
    let emojiVelocity: CGFloat = 340
    let gravity: CGFloat = 315
}

private final class ProSupporterCelebrationView: UIView {
    private let config = ProSupporterCelebrationConfig()
    private var replicator: CAReplicatorLayer?
    private var emitter: CAEmitterLayer?
    private var stopWorkItem: DispatchWorkItem?
    private var cleanupWorkItem: DispatchWorkItem?
    private var hasQueuedPlayback = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        playQueuedBurstIfReady()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        positionEmitter()
        playQueuedBurstIfReady()
    }

    func playWhenReady() {
        cancel()

        guard canPlayNow else {
            hasQueuedPlayback = true
            setNeedsLayout()

            DispatchQueue.main.async { [weak self] in
                self?.playQueuedBurstIfReady()
            }
            return
        }

        startBurst()
    }

    func cancel() {
        hasQueuedPlayback = false
        stopWorkItem?.cancel()
        cleanupWorkItem?.cancel()
        replicator?.removeFromSuperlayer()
        replicator = nil
        emitter = nil
    }

    private var canPlayNow: Bool {
        window != nil && bounds.width > 1 && bounds.height > 1
    }

    private func playQueuedBurstIfReady() {
        guard hasQueuedPlayback,
              canPlayNow else {
            return
        }

        hasQueuedPlayback = false
        startBurst()
    }

    private func startBurst() {
        stopWorkItem?.cancel()
        cleanupWorkItem?.cancel()
        replicator?.removeFromSuperlayer()

        let replicator = CAReplicatorLayer()
        let emitter = makeEmitter()
        self.replicator = replicator
        self.emitter = emitter

        replicator.addSublayer(emitter)
        layer.addSublayer(replicator)
        positionEmitter()

        emitter.emitterCells = celebrationCells()
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1

        ProSupporterCelebrationHaptics.play()

        let stopWorkItem = DispatchWorkItem { [weak emitter] in
            emitter?.birthRate = 0
        }
        self.stopWorkItem = stopWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.burstDuration, execute: stopWorkItem)

        let cleanupWorkItem = DispatchWorkItem { [weak self, weak replicator] in
            guard let self,
                  self.replicator === replicator else {
                return
            }

            replicator?.removeFromSuperlayer()
            self.replicator = nil
            self.emitter = nil
        }
        self.cleanupWorkItem = cleanupWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.cleanupDelay, execute: cleanupWorkItem)
    }

    private func makeEmitter() -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .point
        emitter.emitterMode = .points
        emitter.renderMode = .unordered
        return emitter
    }

    private func positionEmitter() {
        guard let replicator, let emitter else { return }

        let y = min(max(bounds.height * config.emitterTopRatio, config.minimumEmitterY), config.maximumEmitterY)
        let spacing = min(config.spawnPointSpacing, bounds.width * 0.38)

        replicator.frame = bounds
        replicator.instanceCount = 2
        replicator.instanceTransform = CATransform3DMakeTranslation(spacing, 0, 0)

        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX - spacing / 2, y: y)
        emitter.emitterSize = CGSize(width: min(bounds.width * 0.76, config.emitterWidth), height: 26)
    }

    private func celebrationCells() -> [CAEmitterCell] {
        [
            emojiCell("❤️", birthRate: config.heartBirthRate, scale: config.heartScale),
            emojiCell("⚡️", birthRate: config.boltBirthRate, scale: config.boltScale)
        ]
    }

    private func emojiCell(_ emoji: String, birthRate: Float, scale: CGFloat) -> CAEmitterCell {
        let cell = baseCell()
        cell.contents = CelebrationParticleImage.image(for: emoji).cgImage
        cell.birthRate = birthRate
        cell.lifetime = config.emojiLifetime
        cell.lifetimeRange = 0.25
        cell.velocity = config.emojiVelocity
        cell.velocityRange = 140
        cell.scale = scale
        cell.scaleRange = 0.08
        cell.spin = 4.2
        cell.spinRange = 6
        return cell
    }

    private func baseCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi * 0.95
        cell.yAcceleration = config.gravity
        cell.xAcceleration = 0
        return cell
    }
}

private enum CelebrationParticleImage {
    private static let heart = emoji("❤️")
    private static let bolt = emoji("⚡️")

    static func image(for value: String) -> UIImage {
        value == "❤️" ? heart : bolt
    }

    private static func emoji(_ value: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false

        let size = CGSize(width: 40, height: 40)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .paragraphStyle: paragraphStyle
            ]

            value.draw(
                in: CGRect(x: 0, y: 4, width: size.width, height: size.height),
                withAttributes: attributes
            )
        }
    }
}

private enum ProSupporterCelebrationHaptics {
    static func play() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.65)
    }
}

private struct ActiveSupporterBenefits: View {
    @Environment(\.colorScheme) private var colorScheme

    let highlightedBenefitIndex: Int?

    private let columns = [
        GridItem(.adaptive(minimum: 145), spacing: 10, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unlocked for you".localized())
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(Array(proBenefits.enumerated()), id: \.element.id) { index, benefit in
                    ActiveBenefitTile(
                        benefit: benefit,
                        index: index,
                        isActive: highlightedBenefitIndex == index
                    )
                }
            }
        }
    }
}

private struct ActiveBenefitTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let benefit: ProBenefit
    let index: Int
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            AnimatedBenefitIcon(
                systemImage: benefit.systemImage,
                tint: benefit.tint,
                index: index,
                isActive: isActive
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(benefit.title.localized())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(benefit.subtitle.localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(13)
        .background(AppTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(benefit.tint.opacity(isActive ? 0.30 : 0.12), lineWidth: 1)
        }
    }
}

private struct AnimatedBenefitIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let systemImage: String
    let tint: Color
    let index: Int
    let isActive: Bool

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
    let product: Product
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
                    Text(product.displayPrice)
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

private struct ProSupporterConfettiPreviewHarness: View {
    @State private var confettiTrigger = 0

    var body: some View {
        NavigationStack {
            ProSupporterPaywallView()
                .environmentObject(ProSupporterStore.preview(hasPro: true))
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                confettiTrigger += 1
            } label: {
                Label("Play confetti", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .proSupporterPurchaseConfetti(trigger: $confettiTrigger)
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

#Preview("Confetti animation") {
    ProSupporterConfettiPreviewHarness()
}
