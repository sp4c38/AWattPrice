//
//  WidgetBundle.swift
//  AWattPrice
//
//  Created by Léon Becker on 30.01.21.
//

import SwiftUI
import WidgetKit

@main
struct AWattPriceBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        PriceWidget()
    }
}
