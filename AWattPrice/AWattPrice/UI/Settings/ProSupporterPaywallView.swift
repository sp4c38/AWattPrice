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
        title: "Family Sharing",
        subtitle: "Share Pro with your family members at no extra cost.",
        systemImage: "figure.and.child.holdinghands",
        tint: .orange
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
    @State private var displayedHasPro: Bool?
    @State private var highlightedBenefitIndex: Int?

    var body: some View {
        ZStack {
            ZStack(alignment: .topLeading) {
                if displayedProIsActive {
                    paywallScrollView(hasPro: true)
                        .transition(.opacity)
                } else {
                    paywallScrollView(hasPro: false)
                        .transition(.opacity)
                }
            }
            .onAppear {
                displayedHasPro = proStore.hasPro
            }
            .onChange(of: proStore.hasPro) { _, hasPro in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    displayedHasPro = hasPro
                }
            }

        }
        .proSupporterPurchaseConfetti(trigger: $purchaseCelebrationID)
        .background(AppTheme.screenBackground(for: .light).opacity(0.001))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done".localized()) {
                    guard proStore.isBusy == false else { return }
                    dismiss()
                }
                .disabled(proStore.isBusy)
            }
        }
        .interactiveDismissDisabled(proStore.isBusy)
        .task {
            if runsInPreview == false {
                proStore.start()
            }
        }
    }

    private var runsInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var displayedProIsActive: Bool {
        displayedHasPro ?? proStore.hasPro
    }

    private func paywallScrollView(hasPro: Bool) -> some View {
        ScrollView {
            paywallContent(hasPro: hasPro)
        }
        .id(hasPro)
    }

    private func paywallContent(hasPro: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            header(hasPro: hasPro)

            if hasPro {
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

    private func header(hasPro: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            headerIcon(hasPro: hasPro)

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle(hasPro: hasPro).localized())
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                if hasPro {
                    Text("Thank you for supporting AWattPrice!".localized())
                        .font(.subheadline)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, hasPro ? 14 : 0)
        .padding(.vertical, hasPro ? 12 : 0)
        .background {
            if hasPro {
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
    private func headerIcon(hasPro: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ActiveProBoltIcon()
                .frame(width: 42, height: 42)

            if hasPro {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.success)
                    .padding(2)
                    .background(Color(.systemBackground), in: Circle())
                    .offset(x: 5, y: 5)
            }
        }
        .accessibilityHidden(true)
    }

    private func headerTitle(hasPro: Bool) -> String {
        hasPro ? "Pro is active" : "AWattPrice Pro Supporter"
    }

    private var activeSupporterExperience: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefitsList(title: "Unlocked for you", itemSpacing: 20)
                .padding(.top, 3)
            restoreButton
        }
        .task(id: reduceMotion) {
            await runBenefitHighlightAnimation()
        }
    }

    private var benefitsSection: some View {
        benefitsList(title: "What you get with Pro Supporter")
            .task(id: reduceMotion) {
                await runBenefitHighlightAnimation()
            }
    }

    private func benefitsList(title: String, itemSpacing: CGFloat = 16) -> some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Text(title.localized())
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

private struct ActiveProBoltIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var strikeProgress: CGFloat = 0
    @State private var flashOpacity: CGFloat = 0
    @State private var boltOpacity: CGFloat = 0
    @State private var boltScale: CGFloat = 0.76
    @State private var revealGlowOpacity: CGFloat = 0
    @State private var revealGlowScale: CGFloat = 0.45
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            ZStack {
                ActiveProBoltShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.80),
                                Color(red: 1.0, green: 0.96, blue: 0.18).opacity(0.62),
                                Color(red: 1.0, green: 0.58, blue: 0.00).opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        ActiveProBoltShape()
                            .stroke(Color.white.opacity(0.94), lineWidth: 2.4)
                            .shadow(color: Color(red: 1.0, green: 0.92, blue: 0.08).opacity(0.92), radius: 5)
                            .shadow(color: Color(red: 1.0, green: 0.44, blue: 0.00).opacity(0.46), radius: 9)
                    }
                    .scaleEffect(reduceMotion ? 0.9 : revealGlowScale)
                    .opacity(reduceMotion ? 0 : revealGlowOpacity)
                    .blur(radius: 0.35)

                ZStack {
                    ActiveProBoltShape()
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.white.opacity(0.42), radius: 3)
                        .shadow(color: Color(red: 1.0, green: 0.48, blue: 0.00).opacity(0.36), radius: 8, y: 2)

                    ActiveProBoltShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.86, blue: 0.20),
                                    Color(red: 1.0, green: 0.55, blue: 0.00),
                                    Color(red: 0.88, green: 0.24, blue: 0.00)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    ActiveProBoltShape()
                        .stroke(Color(red: 0.46, green: 0.14, blue: 0.00).opacity(0.18), lineWidth: 0.65)

                    ActiveProBoltShape()
                        .stroke(Color.white.opacity(0.36), lineWidth: 0.5)
                        .blendMode(.screen)
                }
                .opacity(reduceMotion ? 1 : boltOpacity)
                .scaleEffect(reduceMotion ? 1 : boltScale)

                ActiveProLightningTraceShape()
                    .trim(from: 0, to: reduceMotion ? 0 : strikeProgress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 4.6, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.94, blue: 0.08).opacity(0.94), radius: 8)
                    .shadow(color: Color(red: 1.0, green: 0.44, blue: 0.00).opacity(0.62), radius: 11)
                    .opacity(reduceMotion ? 0 : max(0, 1 - boltOpacity * 0.9))

                ActiveProBoltShape()
                    .fill(Color.white.opacity(reduceMotion ? 0 : flashOpacity))
                    .blur(radius: 6)
                    .scaleEffect(1.36)
            }
            .frame(width: 42, height: 42)
        }
        .frame(width: 112, height: 112)
        .frame(width: 42, height: 42)
        .onAppear(perform: startAnimationIfNeeded)
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func startAnimationIfNeeded() {
        guard animationTask == nil else { return }
        animationTask?.cancel()

        guard reduceMotion == false else {
            strikeProgress = 1
            boltOpacity = 1
            boltScale = 1
            flashOpacity = 0
            revealGlowOpacity = 0
            revealGlowScale = 1
            return
        }

        strikeProgress = 0
        flashOpacity = 0
        boltOpacity = 0
        boltScale = 0.76
        revealGlowOpacity = 0
        revealGlowScale = 0.86

        animationTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)

                // Draw the initial trace before entering the loop.
                withAnimation(.easeInOut(duration: 0.85)) {
                    strikeProgress = 1
                }
                try await Task.sleep(nanoseconds: 720_000_000)
                try Task.checkCancellation()

                while Task.isCancelled == false {
                    // Entry state: trace drawn, bolt invisible (boltOpacity == 0).

                    withAnimation(.easeOut(duration: 0.12)) {
                        flashOpacity = 0.96
                    }

                    try await Task.sleep(nanoseconds: 180_000_000)
                    try Task.checkCancellation()

                    withAnimation(.easeOut(duration: 0.16)) {
                        flashOpacity = 0
                    }

                    withAnimation(.easeOut(duration: 0.16)) {
                        revealGlowOpacity = 0.92
                        revealGlowScale = 1.12
                    }

                    // Bolt is invisible here, so snapping scale is imperceptible.
                    boltScale = 0.76
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.46)) {
                        boltOpacity = 1
                        boltScale = 1.14
                    }

                    try await Task.sleep(nanoseconds: 160_000_000)
                    try Task.checkCancellation()

                    withAnimation(.easeOut(duration: 0.68)) {
                        revealGlowOpacity = 0
                        revealGlowScale = 2.35
                    }

                    withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                        boltScale = 1
                    }

                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    try Task.checkCancellation()

                    // Transition: trace opacity is ~0.1 while bolt is fully opaque,
                    // so snapping strikeProgress to 0 is imperceptible.
                    strikeProgress = 0
                    revealGlowScale = 0.86

                    // Start bolt fade, then let it get going before drawing the trace.
                    withAnimation(.easeIn(duration: 0.65)) {
                        boltOpacity = 0
                        boltScale = 0.88
                    }

                    try await Task.sleep(nanoseconds: 450_000_000)
                    try Task.checkCancellation()

                    withAnimation(.easeInOut(duration: 0.85)) {
                        strikeProgress = 1
                    }

                    try await Task.sleep(nanoseconds: 720_000_000)
                    try Task.checkCancellation()
                }
            } catch {
                return
            }
        }
    }
}

private enum ActiveProBoltGeometry {
    static let points = [
        CGPoint(x: 0.62, y: 0.02),
        CGPoint(x: 0.17, y: 0.55),
        CGPoint(x: 0.43, y: 0.55),
        CGPoint(x: 0.31, y: 0.98),
        CGPoint(x: 0.86, y: 0.35),
        CGPoint(x: 0.57, y: 0.38)
    ]

    static func path(in rect: CGRect, closeSubpath: Bool) -> Path {
        var path = Path()

        for (index, point) in points.enumerated() {
            let resolvedPoint = CGPoint(
                x: rect.minX + point.x * rect.width,
                y: rect.minY + point.y * rect.height
            )

            if index == 0 {
                path.move(to: resolvedPoint)
            } else {
                path.addLine(to: resolvedPoint)
            }
        }

        if closeSubpath {
            path.closeSubpath()
        }

        return path
    }
}

private struct ActiveProBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        ActiveProBoltGeometry.path(in: rect, closeSubpath: true)
    }
}

private struct ActiveProLightningTraceShape: Shape {
    func path(in rect: CGRect) -> Path {
        ActiveProBoltGeometry.path(in: rect, closeSubpath: true)
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

    /// One full sweep takes this many seconds.
    private let period: TimeInterval = 2.6

    var body: some View {
        if isDisabled {
            Color.clear
        } else if reduceMotion {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        } else {
            ZStack {
                // Subtle persistent border so the button always looks polished.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)

                // Animated sheen drawn with Canvas — no layout shapes, no
                // rectangles, clips automatically to its own bounds.
                TimelineView(.animation) { timeline in
                    let t = CGFloat(
                        timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: period) / period
                    )
                    Canvas { ctx, size in
                        // Half-width of the soft gradient band.
                        let hw = size.width * 0.22
                        // Center of the band sweeps from off-screen left to
                        // off-screen right so the loop is seamless.
                        let cx = -hw + (size.width + hw * 2) * t

                        // A diagonal gradient (startPoint top-left of band,
                        // endPoint bottom-right) gives the classic angled-
                        // sheen look without any rotated shapes.
                        ctx.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .linearGradient(
                                Gradient(stops: [
                                    .init(color: .white.opacity(0.00), location: 0),
                                    .init(color: .white.opacity(0.28), location: 0.5),
                                    .init(color: .white.opacity(0.00), location: 1),
                                ]),
                                startPoint: CGPoint(x: cx - hw, y: 0),
                                endPoint:   CGPoint(x: cx + hw, y: size.height)
                            )
                        )
                    }
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
