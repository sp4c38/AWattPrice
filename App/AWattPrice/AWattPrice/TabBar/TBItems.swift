//
//  TBItems.swift
//  AWattPrice
//
//  Created by Léon Becker on 28.11.20.
//

import SwiftUI

class TBItem {
    let uuid = UUID().uuidString
    var imageName: String
    var itemSubtitle: String

    init(imageName: String, itemSubtitle: String) {
        self.imageName = imageName
        self.itemSubtitle = itemSubtitle
    }
}

class TBItems: ObservableObject {
    let items = [
        TBItem(imageName: "gear", itemSubtitle: "settingsPage.settings"),
        TBItem(imageName: "bolt", itemSubtitle: "electricityPage.tabBarTitle"),
        TBItem(imageName: "rectangle.and.text.magnifyingglass", itemSubtitle: "cheapestPricePage.cheapestPrice"),
    ]

    @Published var selectedItemIndex: Int = 1

    func changeSelected(_ newIndex: Int) {
        selectedItemIndex = newIndex
    }
}
