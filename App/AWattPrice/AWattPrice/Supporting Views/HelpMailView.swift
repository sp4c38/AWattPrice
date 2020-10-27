//
//  HelpMailView.swift
//  AWattPrice
//
//  Created by Léon Becker on 27.10.20.
//

import SwiftUI
import MessageUI

struct HelpMailView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentationMode: PresentationMode
        
        init(presentationMode: Binding<PresentationMode>) {
            _presentationMode = presentationMode
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer {
                presentationMode.dismiss()
            }
            
            guard error == nil else {
                return
            }
        }
        
        
    }
    
    struct HelpMail {
        let recipientEmails: String
        let subject: String
        let encodedSubject: String
        var body: String = ""
        var encodedBody: String = ""
        
        init() {
            self.recipientEmails = "support@space8.me"
            self.subject = "AWattPrice Help"
            self.encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        
            var messageBody = ""
            
            if let currentAppName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                messageBody += "\n\nApp name: \(currentAppName)\n"
            }
            
            if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                messageBody += "App version number: \(currentVersion)"
            }
            
            if let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                messageBody += " (\(currentBuild))"
            }
            
            self.body = messageBody
            self.encodedBody = self.body.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            print(self.encodedBody)
        }
    }

    var helpMail = HelpMail()
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposerViewController = MFMailComposeViewController()
        mailComposerViewController.mailComposeDelegate = context.coordinator
        mailComposerViewController.setSubject(helpMail.subject)
        mailComposerViewController.setToRecipients([helpMail.recipientEmails])
        mailComposerViewController.setMessageBody(helpMail.body, isHTML: false)
        
        return mailComposerViewController
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(presentationMode: presentationMode)
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        
    }
    
    func getAlternativeMailApp() -> URL? {
        let gmailUrl = URL(string: "googlegmail://co?to=\(helpMail.recipientEmails)&subject=\(helpMail.encodedSubject)&body=\(helpMail.encodedBody)")
        let outlookUrl = URL(string: "ms-outlook://compose?to=\(helpMail.recipientEmails)&subject=\(helpMail.encodedSubject)")
        let yahooMail = URL(string: "ymail://mail/compose?to=\(helpMail.recipientEmails)&subject=\(helpMail.encodedSubject)&body=\(helpMail.encodedBody)")
        let sparkUrl = URL(string: "readdle-spark://compose?recipient=\(helpMail.recipientEmails)&subject=\(helpMail.encodedSubject)&body=\(helpMail.encodedBody)")
        let defaultUrl = URL(string: "mailto:\(helpMail.recipientEmails)?subject=\(helpMail.encodedSubject)&body=\(helpMail.encodedBody)")
        
        if let gmailUrl = gmailUrl, UIApplication.shared.canOpenURL(gmailUrl) {
            return gmailUrl
        } else if let sparkUrl = sparkUrl, UIApplication.shared.canOpenURL(sparkUrl) {
            return sparkUrl
        } else if let outlookUrl = outlookUrl, UIApplication.shared.canOpenURL(outlookUrl) {
            return outlookUrl
        } else if let yahooMail = yahooMail, UIApplication.shared.canOpenURL(yahooMail) {
            return yahooMail
        } else {
            return defaultUrl
        }
    }
}
