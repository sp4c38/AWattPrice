//
//  HelpView.swift
//  AWattPrice
//
//  Created by Léon Becker on 27.10.20.
//

import MessageUI
import SwiftUI

struct HelpAndSuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.3 : 1)
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .padding([.top, .bottom], 16)
            .padding([.leading, .trailing], 5)
            .background(Color.blue)
            .cornerRadius(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 5)
            )
        
    }
}

struct HelpView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var isShowingMailView = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("settingsPage.help")
                .bold()
                .font(.title)
            
            Button(action: {
                if MFMailComposeViewController.canSendMail() {
                    self.isShowingMailView.toggle()
                } else {
                    if let alternativeUrl = MailView(mailContent: HelpMailContent()).getAlternativeMailApp() {
                        UIApplication.shared.open(alternativeUrl)
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("settingsPage.helpByEmail")
                        .font(.title3)
                        .bold()
                }
            }
            .buttonStyle(HelpAndSuggestionButtonStyle())
        }
        .padding()
        .background(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9686) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
        .cornerRadius(20)
        .padding()
        .sheet(isPresented: $isShowingMailView) {
            MailView(mailContent: HelpMailContent())
                .edgesIgnoringSafeArea(.bottom)
        }
    }
}

struct SuggestionView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var isShowingMailView = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("settingsPage.suggestion")
                .bold()
                .font(.title)
            
            Button(action: {
                if MFMailComposeViewController.canSendMail() {
                    self.isShowingMailView.toggle()
                } else {
                    if let alternativeUrl = MailView(mailContent: SuggestionMailContent()).getAlternativeMailApp() {
                        UIApplication.shared.open(alternativeUrl)
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image("suggestion")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 25, height: 25)
                    
                    Text("settingsPage.suggestionByEmail")
                        .font(.title3)
                        .bold()
                }
            }
            .buttonStyle(HelpAndSuggestionButtonStyle())
        }
        .padding()
        .background(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9686) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
        .cornerRadius(20)
        .padding()
        .sheet(isPresented: $isShowingMailView) {
            MailView(mailContent: SuggestionMailContent())
                .edgesIgnoringSafeArea(.bottom)
        }
    }
}

struct HelpAndSuggestionView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            HelpView()
            SuggestionView()
        }
        .navigationTitle("settingsPage.helpAndSuggestions")
    }
}

struct GetHelpView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var redirectToHelpAndSuggestionView: Int? = 0
    
    var body: some View {
        CustomInsetGroupedListItem {
            HStack(spacing: 0) {
                NavigationLink("", destination: HelpAndSuggestionView(), tag: 1, selection: $redirectToHelpAndSuggestionView)
                    .frame(width: 0, height: 0)
                    .hidden()
                
                HStack {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                    
                    Text("settingsPage.helpAndSuggestions")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                }
            }
            .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            .contentShape(Rectangle())
            .onTapGesture {
                redirectToHelpAndSuggestionView = 1
            }
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
    }
}

struct demoPreview: View {
    var body: some View {
        NavigationView {
            List {
                GetHelpView()
            }
            .listStyle(InsetGroupedListStyle())
        }
        .preferredColorScheme(.light)
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
//        NavigationView {
//            List {
//                HelpView
//            }
//            .listStyle(InsetGroupedListStyle())
//            .navigationTitle("Settings")
//        }
//        .preferredColorScheme(.light)
        
        HelpAndSuggestionView()
            .preferredColorScheme(.dark)
    }
}
