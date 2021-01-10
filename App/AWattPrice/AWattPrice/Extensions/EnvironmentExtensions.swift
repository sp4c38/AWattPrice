//
//  EnvironmentExtensions.swift
//  AWattPrice
//
//  Created by Léon Becker on 10.01.21.
//

import Network
import SwiftUI

class NetworkManager: ObservableObject {
    @Published var networkStatus = NWPath.Status.unsatisfied
    var monitorer: NWPathMonitor

    init() {
        monitorer = NWPathMonitor()
        monitorer.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.networkStatus = path.status
            }
        }
        monitorer.start(queue: DispatchQueue(label: "NetworkMonitorer"))
    }
}

struct NetworkManagerKey: EnvironmentKey {
    static var defaultValue = NetworkManager()
}

class NotificationAccess {
    var access = false
}

class NotificationAccessKey: EnvironmentKey {
    static var defaultValue = NotificationAccess()
}

extension EnvironmentValues {
    var networkManager: NetworkManager {
        get {
            self[NetworkManagerKey.self]
        }
        set {}
    }

    var notificationAccess: NotificationAccess {
        get { self[NotificationAccessKey.self] }
        set { self[NotificationAccessKey.self] = newValue }
    }

    var deviceType: UIUserInterfaceIdiom {
        get { UIDevice.current.userInterfaceIdiom }
        set {}
    }

    var keyboardObserver: KeyboardObserver {
        get { self[KeyboardObserverKey.self] }
        set {}
    }
}
