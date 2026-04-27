//
//  NetworkManager.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.01.21.
//

import Network
import SwiftUI

class NetworkManager: ObservableObject {
    @Published var networkStatus = NWPath.Status.unsatisfied
    var monitorer: NWPathMonitor

    var isOffline: Bool {
        networkStatus != .satisfied
    }

    init(waitUntilFirstStatusWasRetrieved: Bool = false) {
        let semaphore = DispatchSemaphore(value: 0)
        
        monitorer = NWPathMonitor()
        monitorer.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.networkStatus = path.status
            }
            semaphore.signal()
        }
        monitorer.start(queue: DispatchQueue(label: "NetworkMonitorer"))
        
        if waitUntilFirstStatusWasRetrieved {
            semaphore.wait()
        }
    }
}

struct NetworkManagerKey: EnvironmentKey {
    static var defaultValue = NetworkManager()
}
