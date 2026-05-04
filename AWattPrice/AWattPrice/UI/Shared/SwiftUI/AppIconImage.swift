//
//  AppIconImage.swift
//  AWattPrice
//

import SwiftUI
import UIKit

struct AppIconImage: View {
    private let image: UIImage?

    init() {
        image = Self.primaryAppIcon()
    }

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
        } else {
            Image(systemName: "app")
                .resizable()
        }
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

