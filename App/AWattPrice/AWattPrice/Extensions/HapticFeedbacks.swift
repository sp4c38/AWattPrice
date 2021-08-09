//
//  HapticFeedbacks.swift
//  AWattPrice
//
//  Created by Léon Becker on 22.01.21.
//

import SwiftUI

func playErrorHapticFeedback() {
    let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    notificationFeedbackGenerator.prepare()
    notificationFeedbackGenerator.notificationOccurred(.error)
}

func playSuccessHapticFeedback() {
    let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    notificationFeedbackGenerator.prepare()
    notificationFeedbackGenerator.notificationOccurred(.success)
}
