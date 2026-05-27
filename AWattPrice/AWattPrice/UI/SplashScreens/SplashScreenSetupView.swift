//
//  SplashScreenSetupView.swift
//  AWattPrice
//
//  Created by Léon Becker on 16.12.20.
//


import SwiftUI

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.32, y: rect.height * 0.54))
        path.addLine(to: CGPoint(x: rect.width * 0.45, y: rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.width * 0.68, y: rect.height * 0.38))
        return path
    }
}

/// A checkmark which animates in.
private struct AnimatingCheckmark: View {
    @State private var circleTrim: CGFloat = 0.0
    @State private var checkmarkTrim: CGFloat = 0.0
    @State private var scale: CGFloat = 0.8

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let size = min(width, height)
            let checkmarkWidth = size * 0.42
            let lineWidth = checkmarkWidth * 0.065

            let gradient = LinearGradient(
                colors: [
                    Color(red: 0.00, green: 0.68, blue: 0.60),
                    Color(red: 0.14, green: 0.72, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                Circle()
                    .trim(from: 0.0, to: circleTrim)
                    .stroke(
                        gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: checkmarkWidth, height: checkmarkWidth)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)

                CheckmarkShape()
                    .trim(from: 0.0, to: checkmarkTrim)
                    .stroke(
                        gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: checkmarkWidth, height: checkmarkWidth)
            }
            .scaleEffect(scale)
            .position(x: width / 2, y: height / 2)
            .onAppear {
                withAnimation(.spring(response: 1.15, dampingFraction: 0.82)) {
                    circleTrim = 1.0
                    scale = 1.0
                }
                withAnimation(.spring(response: 0.88, dampingFraction: 0.76).delay(0.75)) {
                    checkmarkTrim = 1.0
                }
            }
        }
    }
}

private struct SetupCompleteOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.screenBackground(for: colorScheme))
                .ignoresSafeArea()

            AnimatingCheckmark()
                .frame(width: 330, height: 330)
        }
        .transition(.opacity)
    }
}


private struct SetupLoadingOverlay: View {
    let message: LocalizedStringKey

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .appCardStyle(cornerRadius: 18, padding: 0)
    }
}

/// Splash screen which handles the input of settings which are required for the main functionality of the app.
struct SplashScreenSetupView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var settingsManager: SettingsManager

    @ObservedObject var viewModel: MarketAreaTaxSelectionViewModel
    @State private var showCompletionOverlay = false
    @State private var fadeOutSetup = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Select your electricity price market area".localized())
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                MarketAreaMapSelectionView(viewModel: viewModel)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                Button(action: finishSetup) {
                    Text("Enter app")
                }
                .buttonStyle(ContinueButtonStyle())
                .disabled(showCompletionOverlay || viewModel.isLoading || viewModel.isLoadingAreas)
                .padding(.bottom, 16)
                .padding([.leading, .trailing], 16)
            }

            if viewModel.isLoading || viewModel.isLoadingAreas {
                SetupLoadingOverlay(message: viewModel.isLoadingAreas ? "Loading price zones…" : "Saving price zone…")
            }

            if showCompletionOverlay {
                SetupCompleteOverlay()
            }
        }
        .opacity(fadeOutSetup ? 0 : 1)
        .ignoresSafeArea(.keyboard)
        .navigationTitle("Setup")
        .navigationBarBackButtonHidden(showCompletionOverlay)
        .background(AppTheme.screenBackground(for: colorScheme).ignoresSafeArea(.all))
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
            withAnimation(.easeInOut(duration: 0.5)) {
                settingsManager.setting.onboarded = true
            }
            settingsManager.saveChanges()
        }
    }
}

struct SplashScreenSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SplashScreenSetupView(viewModel: MarketAreaTaxSelectionViewModel(
                settingsManager: SettingsManager.shared,
                notificationService: NotificationService(),
                energyDataService: EnergyDataService()
            ))
                .environmentObject(SettingsManager.shared)
                .environmentObject(NotificationService())
                .environmentObject(EnergyDataService())
                .preferredColorScheme(.light)
        }
    }
}

struct AnimatingCheckmark_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AnimatingCheckmark()
                .frame(width: 330, height: 330)
                .background(Color(uiColor: .systemBackground))
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            AnimatingCheckmark()
                .frame(width: 330, height: 330)
                .background(Color(uiColor: .systemBackground))
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
