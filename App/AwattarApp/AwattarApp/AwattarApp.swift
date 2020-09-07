//
//  AwattarAppApp.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

@main
struct AwattarApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(EnergyData())
        }
    }
}
