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
        TBItem(imageName: "bolt", itemSubtitle: "!E. Price"),
        TBItem(imageName: "rectangle.and.text.magnifyingglass", itemSubtitle: "!S. Prices")
    ]
    
    @Published var selectedItemIndex: Int = 0
    
    func changeSelected(_ newIndex: Int) {
        self.selectedItemIndex = newIndex
    }
}
