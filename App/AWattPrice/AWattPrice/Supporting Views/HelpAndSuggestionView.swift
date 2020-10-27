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
            Text("help")
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
                    
                    Text("helpByEmail")
                        .font(.title3)
                        .bold()
                }
            }
            .buttonStyle(HelpAndSuggestionButtonStyle())
        }
        .padding()
        .background(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0340, brightness: 0.8985) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1015))
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
            Text("suggestion")
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
                    
                    Text("suggestionByEmail")
                        .font(.title3)
                        .bold()
                }
            }
            .buttonStyle(HelpAndSuggestionButtonStyle())
        }
        .padding()
        .background(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0340, brightness: 0.8985) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1015))
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
        ZStack(alignment: Alignment(horizontal: .center, vertical: .center)) {
            if colorScheme == .light {
                Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9686)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

            VStack {
                HelpView()
                SuggestionView()
            }
        }
        .navigationTitle("helpAndSuggestions")
    }
}

struct GetHelpView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var redirectToHelpAndSuggestionView: Int? = 0
    
    var body: some View {
        Section {
            ZStack {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                    
                    Text("helpAndSuggestions")
                        .font(.subheadline)
                    
                    Spacer()
                }
                .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                
                NavigationLink("", destination: HelpAndSuggestionView(), tag: 1, selection: $redirectToHelpAndSuggestionView)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                self.hideKeyboard()
                redirectToHelpAndSuggestionView = 1
            }
        }
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
        .onTapGesture {
            self.hideKeyboard()
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
        
        demoPreview()
    }
}
