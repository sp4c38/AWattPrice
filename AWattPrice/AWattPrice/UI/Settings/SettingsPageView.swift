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

private enum SettingsPageStyle {
    static let priceIconTint = Color.blue
    static let widgetsIconTint = Color.indigo
    static let proIconTint = AppTheme.accent
    static let helpIconTint = Color.teal
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

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
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

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
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
                    Text("\("Version".localized()) \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String) (\(currentBuild))")
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
                    "https://www.awattprice.com/terms_of_use/?lang=de",
                    "https://www.awattprice.com/terms_of_use/?lang=en"
                ))
            }

            Text("·")
                .foregroundStyle(.tertiary)

            Button("Privacy Policy".localized()) {
                openAgreementLink((
                    "https://www.awattprice.com/privacy_policy/?lang=de",
                    "https://www.awattprice.com/privacy_policy/?lang=en"
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
            
            Text("Made with love in Dresden for a renewable energy future.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsPageView: View {
    @EnvironmentObject private var proSupporterStore: ProSupporterStore

    let onPresentProPaywall: () -> Void

    init(onPresentProPaywall: @escaping () -> Void = {}) {
        self.onPresentProPaywall = onPresentProPaywall
    }

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

                            if proSupporterStore.hasPro {
                                SettingsDestinationRow(
                                    title: "Price Add-ons".localized(),
                                    subtitle: nil,
                                    systemImage: "sum",
                                    tint: SettingsPageStyle.priceIconTint
                                ) {
                                    PriceAddOnsView()
                                }
                            } else {
                                SettingsActionRow(
                                    title: "Price Add-ons".localized(),
                                    subtitle: "Pro unlocks custom price markups.".localized(),
                                    systemImage: "sum",
                                    tint: SettingsPageStyle.priceIconTint,
                                    action: onPresentProPaywall
                                )
                            }
                        }
                    }

                    Text("Extras & Help".localized())
                        .font(.system(.title3, design: .rounded).weight(.bold))

                    SettingsCard {
                        VStack(spacing: 16) {
                            if proSupporterStore.hasPro {
                                SettingsInfoRow(
                                    title: "Widgets".localized(),
                                    subtitle: "Add our widgets to your Home Screen for quick price updates.".localized(),
                                    systemImage: "square.grid.2x2.fill",
                                    tint: SettingsPageStyle.widgetsIconTint
                                )
                            } else {
                                SettingsActionRow(
                                    title: "Widgets".localized(),
                                    subtitle: nil,
                                    systemImage: "square.grid.2x2.fill",
                                    tint: SettingsPageStyle.widgetsIconTint,
                                    action: onPresentProPaywall
                                )
                            }

                            Divider()

                            SettingsActionRow(
                                title: "AWattPrice Pro Supporter".localized(),
                                subtitle: "Support the app and unlock notifications and advanced insights.".localized(),
                                systemImage: "heart.fill",
                                tint: SettingsPageStyle.proIconTint,
                                action: onPresentProPaywall
                            )

                            Divider()

                            SettingsDestinationRow(
                                title: "Help & Suggestions".localized(),
                                subtitle: nil,
                                systemImage: "questionmark.bubble.fill",
                                tint: SettingsPageStyle.helpIconTint
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
        .environmentObject(ProSupporterStore())
}
