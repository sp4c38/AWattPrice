//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import SwiftUI

private extension Double {
    var settingsCentText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: self)) ?? "0.00") + " ct/kWh"
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        AppCard(cornerRadius: 20, padding: 18, spacing: 16) {
            content
        }
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

private struct SettingsAppVersionView: View {
    var body: some View {
        HStack(spacing: 14) {
            AppIconImage()
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

private struct SettingsLegalLinksView: View {
    var body: some View {
        HStack(spacing: 12) {
            Button("Terms of Use".localized()) {
                openAgreementLink((
                    "https://awattprice.space8.me/terms_of_use/german.html",
                    "https://awattprice.space8.me/terms_of_use/english.html"
                ))
            }

            Text("·")
                .foregroundStyle(.tertiary)

            Button("Privacy Policy".localized()) {
                openAgreementLink((
                    "https://awattprice.space8.me/privacy_policy/german.html",
                    "https://awattprice.space8.me/privacy_policy/english.html"
                ))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsMadeWithLoveView: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "heart")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text("Made with love in Dresden for a renewable future")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsPageView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Electricity Price".localized())
                        .font(.system(.title3, design: .rounded).weight(.bold))

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 14) {
                            RegionView()

                            Divider()

                            SettingsDestinationRow(
                                title: "Price Add-ons".localized(),
                                subtitle: nil,
                                systemImage: "sum",
                                tint: AppTheme.accent
                            ) {
                                PriceAddOnsView()
                            }
                        }
                    }

                    Text("Alerts & Help".localized())
                        .font(.system(.title3, design: .rounded).weight(.bold))

                    SettingsCard {
                        VStack(spacing: 16) {
                            SettingsDestinationRow(
                                title: "Help & Suggestions".localized(),
                                subtitle: nil,
                                systemImage: "questionmark.bubble.fill",
                                tint: AppTheme.accent
                            ) {
                                HelpAndSuggestionView()
                            }
                        }
                    }

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SettingsAppVersionView()

                            Text("splashScreen.start.notAffiliatedNote")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Divider()
                            
                            SettingsLegalLinksView()
                            
                            SettingsMadeWithLoveView()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .appScreenBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsPageView()
        .environmentObject(SettingsManager.shared)
        .environmentObject(NotificationService())
        .environmentObject(EnergyDataService())
}
