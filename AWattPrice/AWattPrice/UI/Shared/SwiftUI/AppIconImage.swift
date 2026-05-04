//
//  AppIconImage.swift
//  AWattPrice
//

import SwiftUI
import UIKit

struct AppIconImage: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let image = Self.appIcon(for: colorScheme)

        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                    ? Color(red: 0.40, green: 0.40, blue: 0.42, opacity: 1.0)
                    : Color(red: 0.83, green: 0.83, blue: 0.84, opacity: 1.0),
                    lineWidth: 1
                )

            if let image {
                Image(uiImage: image)
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .padding()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func appIcon(for colorScheme: ColorScheme) -> UIImage? {
        imageFromIconComposerSource(for: colorScheme) ?? primaryAppIcon()
    }

    private static func imageFromIconComposerSource(for colorScheme: ColorScheme) -> UIImage? {
        let imageName = colorScheme == .dark ? "App Icon v3 Dark" : "App Icon v3"

        if let image = UIImage(named: imageName) {
            return image
        }

        guard
            let imageURL = Bundle.main.url(
                forResource: imageName,
                withExtension: "png",
                subdirectory: "AppIcon.icon/Assets"
            )
        else {
            return nil
        }

        return UIImage(contentsOfFile: imageURL.path)
    }

    private static func primaryAppIcon() -> UIImage? {
        guard
            let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let iconName = iconFiles.last
        else {
            return nil
        }

        return UIImage(named: iconName)
    }
}

