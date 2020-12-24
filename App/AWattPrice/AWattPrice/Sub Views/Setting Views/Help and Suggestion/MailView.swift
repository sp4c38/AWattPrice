//
//  HelpMailView.swift
//  AWattPrice
//
//  Created by Léon Becker on 27.10.20.
//

import SwiftUI
import MessageUI

class MailContent {
    var recipientEmails: String
    var subject: String
    var encodedSubject: String
    var body: String
    var encodedBody: String
    
    init(recipientEmails: String, subject: String, encodedSubject: String, body: String, encodedBody: String) {
        self.recipientEmails = recipientEmails
        self.subject = subject
        self.encodedSubject = encodedSubject
        self.body = body
        self.encodedBody = encodedBody
    }
}

class HelpMailContent: MailContent {
    init() {
        var recipientEmails = "contact-awattprice@space8.me"
        var subject = "AWattPrice Hilfe"
        var encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        var messageBody = ""
        
        if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            messageBody += "\n\nApp Versionsnummer: "
            
            if let currentAppName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                messageBody += "\(currentAppName) "
            }
            messageBody += "\(currentVersion)"
        }
        
        if let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            messageBody += " (\(currentBuild))"
        }
        
        if Locale.current.languageCode == "en" {
            recipientEmails = "contact-awattprice@space8.me"
            subject = "AWattPrice Help"
            encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            messageBody = ""
            
            if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                messageBody += "\n\nApp version number: "
                
                if let currentAppName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                    messageBody += "\(currentAppName) "
                }
                messageBody += "\(currentVersion)"
            }
            
            if let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                messageBody += " (\(currentBuild))"
            }
        }
        
        let body = messageBody
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!

        super.init(
            recipientEmails: recipientEmails,
            subject: subject,
            encodedSubject: encodedSubject,
            body: body,
            encodedBody: encodedBody)
    }
}

class SuggestionMailContent: MailContent {
    init() {
        var recipientEmails = "contact-awattprice@space8.me"
        var subject = "AWattPrice Vorschlag"
        var encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        
        var body = ""
        var encodedBody = ""
        
        if Locale.current.languageCode == "en" {
            recipientEmails = "contact-awattprice@space8.me"
            subject = "AWattPrice Suggestion"
            encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            
            body = ""
            encodedBody = ""
        }

        super.init(
            recipientEmails: recipientEmails,
            subject: subject,
            encodedSubject: encodedSubject,
            body: body,
            encodedBody: encodedBody)
    }
}

struct MailView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    let mailContent: MailContent
    
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
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposerViewController = MFMailComposeViewController()
        mailComposerViewController.mailComposeDelegate = context.coordinator
        mailComposerViewController.setSubject(mailContent.subject)
        mailComposerViewController.setToRecipients([mailContent.recipientEmails])
        mailComposerViewController.setMessageBody(mailContent.body, isHTML: false)
        
        return mailComposerViewController
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(presentationMode: presentationMode)
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        
    }
    
    func getAlternativeMailApp() -> URL? {
        let gmailUrl = URL(string: "googlegmail://co?to=\(mailContent.recipientEmails)&subject=\(mailContent.encodedSubject)&body=\(mailContent.encodedBody)")
        let outlookUrl = URL(string: "ms-outlook://compose?to=\(mailContent.recipientEmails)&subject=\(mailContent.encodedSubject)")
        let yahooMail = URL(string: "ymail://mail/compose?to=\(mailContent.recipientEmails)&subject=\(mailContent.encodedSubject)&body=\(mailContent.encodedBody)")
        let sparkUrl = URL(string: "readdle-spark://compose?recipient=\(mailContent.recipientEmails)&subject=\(mailContent.encodedSubject)&body=\(mailContent.encodedBody)")
        let defaultUrl = URL(string: "mailto:\(mailContent.recipientEmails)?subject=\(mailContent.encodedSubject)&body=\(mailContent.encodedBody)")
        
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
