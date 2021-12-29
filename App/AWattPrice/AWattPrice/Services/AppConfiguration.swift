//
//  AppConfiguration.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.08.21.
//

import Foundation

protocol AppConfiguration {
    var apiURL: URL { get }
}

class StagingAppConfiguration: AppConfiguration {
    var apiURL = URL(string: "https://test-awp.space8.me")!
}

class ProductionAppConfiguration: AppConfiguration {
    var apiURL = URL(string: "https://awattprice.space8.me/api/v2/")!
}
