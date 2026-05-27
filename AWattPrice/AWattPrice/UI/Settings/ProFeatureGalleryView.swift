//
//  ProFeatureGalleryView.swift
//  AWattPrice
//

import SwiftUI
import UIKit

// MARK: - Data Model

private struct ProGalleryItem: Identifiable {
    let id = UUID()
    /// The name of the image asset in the asset catalog.
    /// If no image with this name exists, a placeholder is shown.
    let assetName: String
    let featureName: String
    let systemImage: String
    let tint: Color
}

/// The Pro features that have a meaningful screenshot to show.
/// To add a screenshot: add a PNG/JPEG to the asset catalog with the matching `assetName`.
private let proGalleryItems: [ProGalleryItem] = [
    ProGalleryItem(
        assetName: "pro_screenshot_price_history",
        featureName: "Price history",
        systemImage: "clock.arrow.circlepath",
        tint: .indigo
    ),
    ProGalleryItem(
        assetName: "pro_screenshot_price_addons",
        featureName: "Price add-ons",
        systemImage: "sum",
        tint: .purple
    ),
    ProGalleryItem(
        assetName: "pro_screenshot_insights",
        featureName: "Advanced insights",
        systemImage: "chart.bar.xaxis",
        tint: .blue
    ),
    ProGalleryItem(
        assetName: "pro_screenshot_notifications",
        featureName: "Smart notifications",
        systemImage: "bell.badge.fill",
        tint: .teal
    ),
    ProGalleryItem(
        assetName: "pro_screenshot_widgets",
        featureName: "Home Screen widgets",
        systemImage: "square.grid.2x2.fill",
        tint: .cyan
    ),
]

// MARK: - Gallery View

struct ProFeatureGalleryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("See Pro in action".localized())
                .font(.headline)
                .padding(.leading, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(proGalleryItems) { item in
                        ProGalleryCard(item: item)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.vertical, 4) // room for card shadows
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        }
    }
}

// MARK: - Card

private struct ProGalleryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let item: ProGalleryItem

    /// Fixed card width. The remaining ~20pt of screen edge acts as a "peek" hint.
    private let cardWidth: CGFloat = 220
    /// Phone-like portrait aspect ratio (9:19.5).
    private let aspectRatio: CGFloat = 9.0 / 19.5

    private var cardHeight: CGFloat { cardWidth / aspectRatio }

    var body: some View {
        VStack(spacing: 8) {
            screenshotArea
            caption
        }
    }

    // MARK: Screenshot area

    @ViewBuilder
    private var screenshotArea: some View {
        // UIImage(named:) is used only to detect whether an asset has been
        // added yet. SwiftUI's Image(assetName) is used for display so it
        // automatically picks the light or dark variant from the asset catalog.
        let hasImage = UIImage(named: item.assetName) != nil

        ZStack {
            if hasImage {
                Image(item.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            } else {
                placeholderContent
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.07),
                    lineWidth: 1
                )
        )
        .shadow(
            color: item.tint.opacity(colorScheme == .dark ? 0.18 : 0.12),
            radius: 12,
            y: 5
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.08),
            radius: 6,
            y: 3
        )
    }

    // MARK: Placeholder

    private var placeholderContent: some View {
        ZStack {
            // Gradient background matching the feature tint
            LinearGradient(
                colors: [
                    item.tint.opacity(colorScheme == .dark ? 0.30 : 0.14),
                    item.tint.opacity(colorScheme == .dark ? 0.12 : 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 14) {
                // Large centred icon
                Image(systemName: item.systemImage)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(item.tint.opacity(0.60))

                Text("Screenshot coming soon".localized())
                    .font(.caption2)
                    .foregroundStyle(item.tint.opacity(0.50))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Caption

    private var caption: some View {
        HStack(spacing: 6) {
            Image(systemName: item.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(item.tint)

            Text(item.featureName.localized())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: cardWidth, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("Gallery") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            ProFeatureGalleryView()
        }
        .padding(.top, 20)
    }
}
