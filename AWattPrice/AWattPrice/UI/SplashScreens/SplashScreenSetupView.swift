//
//  SplashScreenSetupView.swift
//  AWattPrice
//
//  Created by Léon Becker on 16.12.20.
//


import SwiftUI

/// A checkmark which animates in.
private struct AnimatingCheckmark: View {
    struct CheckmarkLine: Shape {
        var startPoint: CGPoint
        var endPoint: CGPoint
        let lineWidth: CGFloat

        var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get {
                AnimatablePair(endPoint.x, endPoint.y)
            }

            set {
                endPoint.x = newValue.first
                endPoint.y = newValue.second
            }
        }

        func path(in _: CGRect) -> Path {
            var path = Path()

            if endPoint.x != startPoint.x && endPoint.y != startPoint.y {
                path.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
                path.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y))

                path = path.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }

            return path
        }
    }

    @State var trimAmount: CGFloat = 0.01
    @State var firstLineStartPoint = CGPoint(x: 0, y: 0)
    @State var firstLineEndPoint = CGPoint(x: 0, y: 0)
    @State var secondLineStartPoint = CGPoint(x: 0, y: 0)
    @State var secondLineEndPoint = CGPoint(x: 0, y: 0)

    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height

        let checkmarkWidth = width / 3
        let checkmarkStartWidth = (width - checkmarkWidth) / 2
        let checkmarkStartHeight: CGFloat = (height / 3) - (checkmarkWidth / 2)

        let lineWidth: CGFloat = checkmarkWidth / 17

        return ZStack {
            CheckmarkLine(startPoint: firstLineStartPoint, endPoint: firstLineEndPoint, lineWidth: lineWidth)

            CheckmarkLine(startPoint: secondLineStartPoint, endPoint: secondLineEndPoint, lineWidth: lineWidth)

            Circle()
                .trim(from: 0.0, to: trimAmount)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: checkmarkWidth, height: checkmarkWidth)
                .position(x: width / 2, y: checkmarkStartHeight + (checkmarkWidth / 2))
        }
        .foregroundColor(Color.green)
        .onAppear {
            firstLineStartPoint = CGPoint(x: 0.294 * checkmarkWidth + checkmarkStartWidth, y: 0.530 * checkmarkWidth + checkmarkStartHeight)

            firstLineEndPoint = firstLineStartPoint

            secondLineStartPoint = CGPoint(x: 0.437 * checkmarkWidth + checkmarkStartWidth, y: 0.710 * checkmarkWidth + checkmarkStartHeight)
            secondLineEndPoint = secondLineStartPoint

            withAnimation(Animation.easeOut(duration: 1.5)) {
                trimAmount = 1
            }

            withAnimation(Animation.easeIn(duration: 0.5)) {
                firstLineEndPoint = secondLineStartPoint
            }

            withAnimation(Animation.easeOut(duration: 1).delay(0.5)) {
                secondLineEndPoint = CGPoint(x: 0.695 * checkmarkWidth + checkmarkStartWidth, y: 0.308 * checkmarkWidth + checkmarkStartHeight)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            makeView(geometry)
        }
    }
}

private struct SetupCompleteOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            AnimatingCheckmark()
                .frame(width: 330, height: 330)
        }
        .transition(.opacity)
    }
}

/// Splash screen which handles the input of settings which are required for the main functionality of the app.
struct SplashScreenSetupView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var settingsManager: SettingsManager

    @StateObject private var viewModel: MarketAreaTaxSelectionViewModel
    @State private var showCompletionOverlay = false
    @State private var fadeOutSetup = false

    init() {
        _viewModel = StateObject(wrappedValue: MarketAreaTaxSelectionViewModel(
            settingsManager: SettingsManager.shared,
            notificationService: NotificationService(),
            energyDataService: EnergyDataService()
        ))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select your electricity price market area".localized())
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                MarketAreaMapSelectionView(viewModel: viewModel, height: 460)
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                Button(action: finishSetup) {
                    Text("Enter app")
                }
                .buttonStyle(ContinueButtonStyle())
                .disabled(showCompletionOverlay || viewModel.isLoading)
                .padding(.bottom, 16)
                .padding([.leading, .trailing], 16)
            }

            if viewModel.isLoading || viewModel.isLoadingAreas {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if showCompletionOverlay {
                SetupCompleteOverlay()
            }
        }
        .opacity(fadeOutSetup ? 0 : 1)
        .ignoresSafeArea(.keyboard)
        .navigationTitle("Setup")
        .background((colorScheme == .light ? Color(red: 0.95, green: 0.95, blue: 0.97) : Color.black).ignoresSafeArea(.all))
        .onAppear {
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
            viewModel.selectedMarketAreaKey = settingsManager.setting.marketAreaKey
            viewModel.loadAreasIfNeeded()
            viewModel.focusSelectedArea()
        }
    }

    private func finishSetup() {
        guard showCompletionOverlay == false else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            showCompletionOverlay = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeInOut(duration: 0.45)) {
                fadeOutSetup = true
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            settingsManager.setting.onboarded = true
            settingsManager.saveChanges()
        }
    }
}

struct SplashScreenSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SplashScreenSetupView()
                .environmentObject(SettingsManager.shared)
                .environmentObject(NotificationService())
                .environmentObject(EnergyDataService())
                .preferredColorScheme(.light)
        }
    }
}
