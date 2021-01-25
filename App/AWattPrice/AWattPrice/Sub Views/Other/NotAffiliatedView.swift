//
//  NotAffiliatedView.swift
//  AWattPrice
//
//  Created by Léon Becker on 18.12.20.
//

import SwiftUI

struct NotAffiliatedView: View {
    let setFixedSize: Bool
    let showGrayedOut: Bool
    
    init(setFixedSize: Bool = false, showGrayedOut: Bool) {
        self.setFixedSize = setFixedSize
        self.showGrayedOut = showGrayedOut
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.fSubHeadline)
                .foregroundColor(Color.blue)

            Text("splashScreen.start.notAffiliatedNote")
                .font(setFixedSize ? .fSubHeadline : .subheadline)
                .ifTrue(showGrayedOut == true) { content in
                    content
                        .foregroundColor(Color.gray)
                }
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct NotAffiliatedView_Previews: PreviewProvider {
    static var previews: some View {
        NotAffiliatedView(showGrayedOut: false)
    }
}
