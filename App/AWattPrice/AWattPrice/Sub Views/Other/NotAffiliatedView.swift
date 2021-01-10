//
//  NotAffiliatedView.swift
//  AWattPrice
//
//  Created by Léon Becker on 18.12.20.
//

import SwiftUI

struct NotAffiliatedView: View {
    var showGrayedOut: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.headline)
                .foregroundColor(Color.blue)

            Text("splashScreen.start.notAffiliatedNote")
                .font(.subheadline)
                .ifTrue(showGrayedOut == true) { content in
                    content
                        .foregroundColor(Color.gray)
                }
        }
    }
}

struct NotAffiliatedView_Previews: PreviewProvider {
    static var previews: some View {
        NotAffiliatedView(showGrayedOut: false)
    }
}
