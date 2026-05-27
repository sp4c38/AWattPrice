//
//  ProFeatureGalleryView.swift
//  AWattPrice
//

import SwiftUI
import UIKit

// MARK: - Data Model

private struct ProGalleryItem: Identifiable, Equatable {
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
        assetName: "pro_screenshot_widgets",
        featureName: "Home Screen widgets",
        systemImage: "square.grid.2x2.fill",
        tint: .cyan
    ),
    ProGalleryItem(
        assetName: "pro_screenshot_notifications",
        featureName: "Smart notifications",
        systemImage: "bell.badge.fill",
        tint: .teal
    ),
    ProGalleryItem(
        assetName: "pro_screenshot_price_history",
        featureName: "Price history",
        systemImage: "clock.arrow.circlepath",
        tint: .indigo
    ),
    ProGalleryItem(
        assetName: "pro_screenshot_energy_mix",
        featureName: "Energy mix",
        systemImage: "leaf.fill",
        tint: .green
    ),
]

// MARK: - Gallery View

struct ProFeatureGalleryView: View {
    @State private var selectedItem: ProGalleryItem?

    var body: some View {
        Button {
            selectedItem = proGalleryItems.first
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.accent)
                
                Text("See Pro in action".localized())
                    .font(.subheadline.weight(.semibold))
            
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .fullScreenCover(item: $selectedItem) { item in
            ProGalleryFullScreenViewer(initialItem: item)
        }
    }
}

// MARK: - Full Screen Viewer

private struct ProGalleryFullScreenViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID

    init(initialItem: ProGalleryItem) {
        _selection = State(initialValue: initialItem.id)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selection) {
                ForEach(proGalleryItems) { item in
                    fullscreenImage(for: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismiss()
                        }
                        .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.8), .black.opacity(0.3))
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // Only dismiss if the swipe is clearly downwards,
                    // ignoring horizontal swipes meant for the TabView.
                    if value.translation.height > 60 && abs(value.translation.width) < 60 {
                        dismiss()
                    }
                }
        )
    }

    @ViewBuilder
    private func fullscreenImage(for item: ProGalleryItem) -> some View {
        let hasImage = UIImage(named: item.assetName) != nil
        
        Group {
            if hasImage {
                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 24) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 80, weight: .medium))
                    
                    Text("Screenshot coming soon".localized())
                        .font(.title3.weight(.medium))
                }
                .foregroundStyle(item.tint)
                // Add a gradient background for the placeholder to make it look like a real card
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            item.tint.opacity(0.3),
                            item.tint.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
        // Give the fullscreen image/placeholder nice device-like rounded corners and a border
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(
            color: item.tint.opacity(0.5),
            radius: 60,
            y: 0
        )
        .shadow(
            color: item.tint.opacity(0.4),
            radius: 16,
            y: 0
        )
        // Add padding so it doesn't touch the very edges of the screen
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 64)
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
