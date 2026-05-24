//
//  HelpView.swift
//  AWattPrice
//
//  Created by Léon Becker on 27.10.20.
//

import SwiftUI
import UIKit
#if !targetEnvironment(macCatalyst)
import MessageUI
#endif

private struct HelpAndSuggestionBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppTheme.screenBackground(for: colorScheme)
            .ignoresSafeArea()
    }
}

private struct HelpAndSuggestionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        AppCard(cornerRadius: 20, padding: 18, spacing: 16) {
            content
        }
    }
}

private struct SupportMailAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    let mailContent: MailContent
}

private struct SupportMailRow: View {
    let action: SupportMailAction
    let trigger: () -> Void

    var body: some View {
        Button(action: trigger) {
            HStack(spacing: 14) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: 40, height: 40)
                    .background(action.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(action.title.localized())
                    .font(.headline)
                    .foregroundStyle(.primary)

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

struct HelpAndSuggestionView: View {
    @State private var activeMailAction: SupportMailAction?

    private var helpAction: SupportMailAction {
        let content = HelpMailContent()
        content.setValues()

        return SupportMailAction(
            id: "help",
            title: "Get Help",
            systemImage: "lifepreserver.fill",
            tint: AppTheme.accent,
            mailContent: content
        )
    }

    private var suggestionAction: SupportMailAction {
        SupportMailAction(
            id: "suggestion",
            title: "Send Suggestion",
            systemImage: "sparkles",
            tint: AppTheme.accent,
            mailContent: SuggestionMailContent()
        )
    }

    var body: some View {
        ZStack {
            HelpAndSuggestionBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HelpAndSuggestionCard {
                        SupportMailRow(action: helpAction) {
                            openMail(for: helpAction)
                        }

                        Divider()

                        SupportMailRow(action: suggestionAction) {
                            openMail(for: suggestionAction)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Help & Suggestions")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $activeMailAction) { action in
            #if targetEnvironment(macCatalyst)
            EmptyView()
            #else
            MailView(mailContent: action.mailContent)
                .edgesIgnoringSafeArea(.bottom)
            #endif
        }
    }

    private func openMail(for action: SupportMailAction) {
        #if targetEnvironment(macCatalyst)
        if let alternativeUrl = MailAppURLProvider.alternativeMailApp(for: action.mailContent) {
            UIApplication.shared.open(alternativeUrl)
        }
        #else
        if MFMailComposeViewController.canSendMail() {
            activeMailAction = action
        } else if let alternativeUrl = MailAppURLProvider.alternativeMailApp(for: action.mailContent) {
            UIApplication.shared.open(alternativeUrl)
        }
        #endif
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HelpAndSuggestionView()
        }
    }
}
