//
//  AppConfiguration.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.08.21.
//

import Foundation

protocol AppConfiguration {
    var apiURL: URL { get }
    var vatAmount: Double { get }
}

class StagingAppConfiguration: AppConfiguration {
    var apiURL = URL(string: "https://test-awp.space8.me")!
    var vatAmount = 1.19
}

class ProductionAppConfiguration: AppConfiguration {
    var apiURL = URL(string: "https://awattprice.space8.me")!
    var vatAmount = 1.19
}
