//
//  KeyboardObserver.swift
//  AWattPrice
//
//  Created by Léon Becker on 18.12.20.
//

import Combine
import SwiftUI

class KeyboardObserver: ObservableObject {
    var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }
        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        let mergedPublishers = Publishers.MergeMany(willShow, willHide)
        
        return mergedPublishers.eraseToAnyPublisher()
    }
}

class KeyboardObserverKey: EnvironmentKey {
    static let defaultValue = KeyboardObserver()
}

extension Notification {
    var keyboardHeight: CGFloat {
        return (self.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}
