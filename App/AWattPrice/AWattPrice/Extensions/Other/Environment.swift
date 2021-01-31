//
//  Environment.swift
//  AWattPrice
//
//  Created by Léon Becker on 10.01.21.
//

import SwiftUI

class DeviceOrientationManager: ObservableObject {
    @Published var deviceOrientation = UIInterfaceOrientation.portrait
    
    init() {
        if let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
            self.deviceOrientation = orientation
        } else {
            self.deviceOrientation = UIInterfaceOrientation.portrait
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main,
            using: { _ in
                if let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
                    self.deviceOrientation = orientation
                } else {
                    self.deviceOrientation = UIInterfaceOrientation.portrait
                }
            })
    }
}

struct DeviceOrientationManagerKey: EnvironmentKey {
    static var defaultValue = DeviceOrientationManager()
}

extension EnvironmentValues {
    var networkManager: NetworkManager {
        get {
            self[NetworkManagerKey.self]
        }
        set {}
    }
    
    var deviceOrientation: DeviceOrientationManager {
        get { self[DeviceOrientationManagerKey.self] }
        set {}
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
