//
//  UpdatedDataView.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.11.20.
//

import SwiftUI

struct UpdatedDataView: View {
    var body: some View {
        VStack {
            Text("Data updated")
                .bold()
                .foregroundColor(Color.red)
                .font(.body)
        }
        .cornerRadius(10)
        .transition(.opacity)
        .frame(maxWidth: .infinity)
    }
}

struct UpdatedDataView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatedDataView()
    }
}
