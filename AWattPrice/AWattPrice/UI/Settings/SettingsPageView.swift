//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import SwiftUI

private extension Region {
    var settingsLabel: String {
        switch self {
        case .DE:
            return "Germany".localized()
        case .AT:
            return "Austria".localized()
        }
    }

    var settingsFlag: String {
        switch self {
        case .DE:
            return "DE"
        case .AT:
            return "AT"
        }
    }
}

private extension Double {
    var settingsCentText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: self)) ?? "0.00") + " ct/kWh"
    }
}

private struct SettingsPageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.95, blue: 0.92),
                Color(red: 0.95, green: 0.97, blue: 0.99),
                Color.white,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 220, height: 220)
                .offset(x: 70, y: -80)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.blue.opacity(0.08))
                .frame(width: 240, height: 240)
                .offset(x: -90, y: 120)
        }
        .ignoresSafeArea()
    }
}

private struct SettingsSectionLabel: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 20, y: 8)
    }
}

private struct SettingsBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct SettingsDestinationRow<Destination: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let tint: Color
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsActionRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsHeaderCard: View {
    let regionText: String
    let vatEnabled: Bool
    let baseFeeText: String

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.system(size: 38, weight: .bold, design: .rounded))

                HStack(spacing: 10) {
                    SettingsBadge(text: regionText, tint: .orange)
                    SettingsBadge(text: vatEnabled ? "VAT On".localized() : "VAT Off".localized(), tint: .blue)
                    SettingsBadge(text: baseFeeText, tint: .green)
                }
            }
        }
    }
}

private struct SettingsAppVersionView: View {
    var body: some View {
        HStack(spacing: 14) {
            Image("BigAppIcon")
                .resizable()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("AWattPrice")
                    .font(.headline)

                if let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                    Text("\("Version".localized()) \(AppContext.shared.currentAppVersion) (\(currentBuild))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

struct NotAffiliatedView: View {
    let setFixedSize: Bool
    let showGrayedOut: Bool

    init(setFixedSize: Bool = false, showGrayedOut: Bool) {
        self.setFixedSize = setFixedSize
        self.showGrayedOut = showGrayedOut
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.fSubHeadline)
                .foregroundColor(Color.blue)

            Text("splashScreen.start.notAffiliatedNote")
                .font(setFixedSize ? .fSubHeadline : .subheadline)
                .foregroundColor(showGrayedOut ? Color.gray : nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsNotAffiliatedView: View {
    var body: some View {
        NotAffiliatedView(showGrayedOut: true)
    }
}

struct SettingsPageView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var notificationService: NotificationService

    private var regionSummary: String {
        "\(settingsManager.setting.region.settingsFlag) \(settingsManager.setting.region.settingsLabel)"
    }

    private var baseFeeSummary: String {
        settingsManager.setting.baseFeePrice.settingsCentText
    }

    private var priceGuardSubtitle: String {
        if settingsManager.setting.priceDropsBelowEnabled {
            let threshold = settingsManager.setting.priceDropsBelowThreshold.priceString ?? "0"
            return String(format: "Below %@ ct/kWh".localized(), threshold)
        }

        switch notificationService.accessState {
        case .granted:
            return "Set alert threshold".localized()
        case .rejected:
            return "Notifications off".localized()
        default:
            return "Not configured".localized()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsPageBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SettingsHeaderCard(
                            regionText: regionSummary,
                            vatEnabled: settingsManager.setting.taxEnabled,
                            baseFeeText: baseFeeSummary
                        )

                        SettingsSectionLabel(
                            title: "Energy Setup".localized(),
                            subtitle: nil
                        )

                        SettingsCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Live Price Source")
                                            .font(.headline)
                                    }

                                    Spacer()

                                    SettingsBadge(text: regionSummary, tint: .orange)
                                }

                                RegionTaxSelectionView()

                                Divider()

                                SettingsDestinationRow(
                                    title: "Base Fee".localized(),
                                    subtitle: nil,
                                    systemImage: "eurosign.circle.fill",
                                    tint: .green
                                ) {
                                    BaseFeeView()
                                }
                            }
                        }

                        SettingsSectionLabel(
                            title: "Alerts & Help".localized(),
                            subtitle: nil
                        )

                        SettingsCard {
                            VStack(spacing: 16) {
                                SettingsDestinationRow(
                                    title: "Price Guard".localized(),
                                    subtitle: priceGuardSubtitle,
                                    systemImage: "bell.badge.fill",
                                    tint: .red
                                ) {
                                    NotificationSettingView()
                                }

                                Divider()

                                SettingsDestinationRow(
                                    title: "Help & Suggestions".localized(),
                                    subtitle: nil,
                                    systemImage: "questionmark.bubble.fill",
                                    tint: .blue
                                ) {
                                    HelpAndSuggestionView()
                                }
                            }
                        }

                        SettingsSectionLabel(
                            title: "Legal & About".localized(),
                            subtitle: nil
                        )

                        SettingsCard {
                            VStack(spacing: 16) {
                                SettingsActionRow(
                                    title: "Terms of Use".localized(),
                                    subtitle: nil,
                                    systemImage: "doc.text.fill",
                                    tint: .indigo
                                ) {
                                    openAgreementLink((
                                        "https://awattprice.space8.me/terms_of_use/german.html",
                                        "https://awattprice.space8.me/terms_of_use/english.html"
                                    ))
                                }

                                Divider()

                                SettingsActionRow(
                                    title: "Privacy Policy".localized(),
                                    subtitle: nil,
                                    systemImage: "hand.raised.fill",
                                    tint: .teal
                                ) {
                                    openAgreementLink((
                                        "https://awattprice.space8.me/privacy_policy/german.html",
                                        "https://awattprice.space8.me/privacy_policy/english.html"
                                    ))
                                }
                            }
                        }

                        SettingsCard {
                            VStack(alignment: .leading, spacing: 18) {
                                SettingsAppVersionView()
                                Divider()
                                SettingsNotAffiliatedView()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsPageView()
        .environmentObject(SettingsManager.shared)
        .environmentObject(NotificationService())
        .environmentObject(EnergyDataService())
}
