//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//


import SwiftUI

private struct SplashEnergyBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.06, blue: 0.12),
                        Color(red: 0.06, green: 0.14, blue: 0.22),
                        Color(red: 0.08, green: 0.11, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, size in
                    for index in 0..<5 {
                        var path = Path()
                        let progress = CGFloat(index) / 4
                        let yBase = size.height * (0.22 + progress * 0.48)
                        let amplitude = size.height * (0.018 + progress * 0.016)
                        let phaseOffset = phase * (0.7 + Double(progress) * 0.28)

                        path.move(to: CGPoint(x: -20, y: yBase))

                        for step in 0...48 {
                            let x = CGFloat(step) / 48 * (size.width + 40) - 20
                            let wave = sin((Double(step) * 0.32) + phaseOffset)
                            path.addLine(to: CGPoint(x: x, y: yBase + CGFloat(wave) * amplitude))
                        }

                        context.stroke(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [
                                    Color.cyan.opacity(0.02),
                                    Color.cyan.opacity(0.24),
                                    Color.blue.opacity(0.05)
                                ]),
                                startPoint: CGPoint(x: 0, y: yBase),
                                endPoint: CGPoint(x: size.width, y: yBase)
                            ),
                            lineWidth: 1.6
                        )
                    }
                }
                .blur(radius: 0.4)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.clear,
                        Color.black.opacity(0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
    }
}

private struct SplashIconStage: View {
    let iconSize: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(phase * 1.2)
            let rotation = Angle.degrees(phase.truncatingRemainder(dividingBy: 12) / 12 * 360)
            let lift = CGFloat(sin(phase * 0.8)) * 6

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.34 + pulse * 0.12),
                                Color.blue.opacity(0.14),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: iconSize * 0.95
                        )
                    )
                    .frame(width: iconSize * 1.9, height: iconSize * 1.9)
                    .blur(radius: 18)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.cyan.opacity(0.18),
                                Color.white.opacity(0.70),
                                Color.blue.opacity(0.24),
                                Color.cyan.opacity(0.18)
                            ],
                            center: .center,
                            angle: rotation
                        ),
                        lineWidth: 3
                    )
                    .frame(width: iconSize * 1.22, height: iconSize * 1.22)
                    .blur(radius: 0.3)

                AppIconImage(hasBorder: false)
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: Color.cyan.opacity(0.24), radius: 26, y: 10)
                    .offset(y: lift)
            }
            .accessibilityHidden(true)
        }
    }
}

private struct SplashContinueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.fBody.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.48, blue: 0.68),
                        Color(red: 0.08, green: 0.26, blue: 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .shadow(color: Color(red: 0.03, green: 0.40, blue: 0.80).opacity(configuration.isPressed ? 0.18 : 0.32), radius: configuration.isPressed ? 8 : 16, y: configuration.isPressed ? 4 : 9)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

/**
 Start of all splash screens. Presents and describes the main functionalities of the app briefly.
 */
struct SplashScreenStartView: View {
    @State private var showsFeatures = false
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 184

    var body: some View {
        NavigationStack {
            ZStack {
                SplashEnergyBackground()

                VStack {
                    Spacer(minLength: 5)

                    VStack(spacing: 20) {
                        SplashIconStage(iconSize: min(iconSize, 220))

                        VStack(spacing: 8) {
                            Text("Welcome to")
                                .font(
                                    .custom("SFCompactDisplay-Black", size: 32, relativeTo: .title)
                                )
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text("AWattPrice")
                                .bold()
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, Color.cyan.opacity(0.95)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .font(
                                    .custom("SFCompactDisplay-Black", size: 50, relativeTo: .largeTitle)
                                )
                                .shadow(color: Color.cyan.opacity(0.34), radius: 18, y: 6)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }

                    Spacer(minLength: 16)

                    Button(action: {
                        showsFeatures = true
                    }) {
                        Text("Continue")
                    }
                    .buttonStyle(SplashContinueButtonStyle())
                }
                .padding([.leading, .trailing], 20)
                .padding(.bottom, 16)
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showsFeatures) {
                SplashScreenFeaturesAndConsentView()
            }
        }
    }
}

struct SplashScreenStartView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenStartView()
            .preferredColorScheme(.light)
    }
}
