//
//  AppContext.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.08.21.
//

import Foundation

class AppContext {
    static var shared = AppContext()
    
    var config: AppConfiguration = {
        #if DEBUG
        return StagingAppConfiguration()
        #else
        return ProductionAppConfiguration()
        #endif
    }()
}
