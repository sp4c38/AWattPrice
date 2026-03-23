//
//  LazyNavigationDestination.swift
//  AWattPrice
//
//  Created by Léon Becker on 09.02.21.
//

import SwiftUI

struct LazyNavigationDestination<Content: View>: View {
    let buildDest: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        buildDest = build
    }
    
    var body: some View {
        buildDest()
    }
}
