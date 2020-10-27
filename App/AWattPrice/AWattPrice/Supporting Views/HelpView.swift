//
//  HelpView.swift
//  AWattPrice
//
//  Created by Léon Becker on 27.10.20.
//

import MessageUI
import SwiftUI

struct HelpButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
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
        ZStack(alignment: Alignment(horizontal: .center, vertical: .center)) {
            if colorScheme == .light {
                Color.red
                    .ignoresSafeArea(.all)
            } else {
                Color.black
                    .ignoresSafeArea(.all)
            }

            ZStack {
                Color.white
                    .cornerRadius(20)
                    .edgesIgnoringSafeArea(.bottom)

                VStack(alignment: .center, spacing: 50) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 60))

                    VStack {
                        Button(action: {
                            if MFMailComposeViewController.canSendMail() {
                                self.isShowingMailView.toggle()
                            } else {
                                if let alternativeUrl = HelpMailView().getAlternativeMailApp() {
                                    UIApplication.shared.open(alternativeUrl)
                                }
                            }
                        }) {
                            Text("Get help by email")
                                .font(.title3)
                                .bold()
                                .foregroundColor(Color.white)
                        }
                        .buttonStyle(HelpButtonStyle())
                    }
                    .padding([.leading, .trailing], 40)
                }
                .padding(.top, 15)
                .padding()
                .foregroundColor(Color.blue)
            }
            .padding(.top, 15)
        }
        .navigationTitle("help")
        .sheet(isPresented: $isShowingMailView) {
            HelpMailView()
                .edgesIgnoringSafeArea(.bottom)
        }
    }
}

struct GetHelpView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
//        Section {
            NavigationLink(destination: HelpView()) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                    
                    Text("help")
                        .font(.subheadline)
                }
                .foregroundColor(colorScheme == .light ? Color.black : Color.white)
            }
//        }
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
        
        NavigationView {
            HelpView()
        }
        .preferredColorScheme(.light)
    }
}
