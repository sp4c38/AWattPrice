//
//  AWattPriceWidgetBundle.swift
//  AWattPriceWidget
//
//  Created by Léon Becker on 25.06.23.
//

import WidgetKit
import SwiftUI

@main
struct AWattPriceWidgetBundle: WidgetBundle {
    var body: some Widget {
        CurrentPriceWidget()
        PricesWidget()
        PriceBarChartWidget()
        RenewableMixWidget()
        CheapestTimesWidget()
    }
}
