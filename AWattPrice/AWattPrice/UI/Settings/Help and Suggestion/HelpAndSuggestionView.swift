//
//  HelpView.swift
//  AWattPrice
//
//  Created by Léon Becker on 27.10.20.
//

import MessageUI
import SwiftUI

private struct HelpAndSuggestionBackground: View {
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
        .ignoresSafeArea()
    }
}

private struct HelpAndSuggestionCard<Content: View>: View {
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
            tint: .blue,
            mailContent: content
        )
    }

    private var suggestionAction: SupportMailAction {
        SupportMailAction(
            id: "suggestion",
            title: "Send Suggestion",
            systemImage: "sparkles",
            tint: .orange,
            mailContent: SuggestionMailContent()
        )
    }

    var body: some View {
        ZStack {
            HelpAndSuggestionBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HelpAndSuggestionCard {
                        Text("Help & Suggestions")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                    }

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
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeMailAction) { action in
            MailView(mailContent: action.mailContent)
                .edgesIgnoringSafeArea(.bottom)
        }
    }

    private func openMail(for action: SupportMailAction) {
        if MFMailComposeViewController.canSendMail() {
            activeMailAction = action
        } else if let alternativeUrl = MailView(mailContent: action.mailContent).getAlternativeMailApp() {
            UIApplication.shared.open(alternativeUrl)
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HelpAndSuggestionView()
        }
    }
}
