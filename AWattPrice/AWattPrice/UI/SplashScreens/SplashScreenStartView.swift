//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//


import SwiftUI

private struct SplashDotCarpet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var start = Date.now

    private let columns = 38
    private let rows = 64

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(start)

            Canvas { graphicsContext, size in
                let topInset = -size.height * 0.14
                let carpetHeight = size.height * 1.34
                let centerX = size.width * 0.5
                let topWidth = size.width * 0.92
                let bottomWidth = size.width * 1.72

                for row in 0..<rows {
                    let depth = CGFloat(row) / CGFloat(rows - 1)
                    let easedDepth = CGFloat(pow(Double(depth), 1.18))
                    let rowY = topInset + easedDepth * carpetHeight
                    let rowWidth = topWidth + (bottomWidth - topWidth) * easedDepth
                    let spacing = rowWidth / CGFloat(columns - 1)
                    let wave = sin(elapsed * 1.25 + Double(row) * 0.42) * 6 * Double(0.35 + depth)
                    let rowDrift = sin(elapsed * 0.36 + Double(row) * 0.18) * 12 * Double(0.25 + depth)

                    for column in 0..<columns {
                        let xProgress = CGFloat(column) / CGFloat(columns - 1)
                        let centered = xProgress - 0.5
                        let curveLift = Double(centered * centered) * 34 * Double(depth)
                        let x = centerX - rowWidth / 2 + CGFloat(column) * spacing + CGFloat(rowDrift)
                        let y = rowY + CGFloat(wave) + CGFloat(curveLift)
                        guard y >= -40, y <= size.height + 40 else { continue }

                        let phase = elapsed * 1.8 + Double(column) * 0.32 + Double(row) * 0.21
                        let shimmer = 0.52 + 0.48 * sin(phase)
                        let edgeFade = 1 - min(abs(centered) * 1.65, 0.74)
                        let distanceFade = 0.38 + 0.62 * depth
                        let opacity = min(max((0.26 + 0.58 * shimmer) * Double(edgeFade) * Double(distanceFade), 0.11), 0.84)
                        let titleXFade = max(0, 1 - abs(x - centerX) / (size.width * 0.46))
                        let titleYFade = max(0, 1 - abs(y - size.height * 0.56) / (size.height * 0.14))
                        let titleProtection = pow(Double(titleXFade * titleYFade), 0.7)
                        let protectedOpacity = opacity * (1 - 0.74 * titleProtection)
                        let dotSize = CGFloat(1.25 + 2.45 * Double(depth) + 0.82 * max(shimmer, 0))
                        let color = Color(
                            red: isDark ? 0.32 : 0.04,
                            green: isDark ? 0.68 : 0.34,
                            blue: isDark ? 1.0 : 0.82,
                            opacity: protectedOpacity * (isDark ? 0.7 : 0.5)
                        )

                        graphicsContext.fill(
                            Path(ellipseIn: CGRect(
                                x: x - dotSize / 2,
                                y: y - dotSize / 2,
                                width: dotSize,
                                height: dotSize
                            )),
                            with: .color(color)
                        )
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}


/**
 Start of all splash screens. Presents and describes the main functionalities of the app briefly.
 */
struct SplashScreenStartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsFeatures = false
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 184

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var titleColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var appNameColor: Color {
        Color(hue: 0.5648, saturation: 1.0000, brightness: colorScheme == .dark ? 0.92 : 0.62)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                SplashDotCarpet()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .blur(radius: 0.12)

                VStack {
                    Spacer(minLength: 5)

                    VStack(spacing: 20) {
                        AppIconImage(hasBorder: false)
                            .frame(width: min(iconSize, 220), height: min(iconSize, 220))
                            .shadow(color: Color.cyan.opacity(colorScheme == .dark ? 0.22 : 0.12), radius: 24, y: 10)

                        VStack(spacing: 8) {
                            Text("Welcome to")
                                .font(
                                    .custom("SFCompactDisplay-Black", size: 32, relativeTo: .title)
                                )
                                .foregroundStyle(titleColor.opacity(colorScheme == .dark ? 0.88 : 0.82))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text("AWattPrice")
                                .foregroundStyle(appNameColor)
                                .font(
                                    .custom("SFCompactDisplay-Black", size: 60, relativeTo: .largeTitle)
                                )
                                .fontWeight(.black)
                                .tracking(1)
                                .shadow(color: backgroundColor.opacity(colorScheme == .dark ? 0.88 : 0.96), radius: 9, y: 1)
                                .shadow(color: appNameColor.opacity(colorScheme == .dark ? 0.38 : 0.24), radius: 11, y: 4)
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
                    .buttonStyle(ContinueButtonStyle())
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
