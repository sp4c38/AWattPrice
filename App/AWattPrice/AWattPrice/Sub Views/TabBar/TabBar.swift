//
//  TabBar.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.12.20.
//

import SwiftUI

struct TBBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height))

        return path
    }
}

struct TabBar: View {
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var tabBarItems: TBItems

    var body: some View {
        ZStack {
            TBBarShape()
                .foregroundColor(colorScheme == .light ?
                    Color(red: 0.96, green: 0.96, blue: 0.96) :
                    Color(red: 0.07, green: 0.07, blue: 0.07)
                )
                .edgesIgnoringSafeArea(.all)

            HStack {
                ForEach(0 ..< tabBarItems.items.count, id: \.self) { tabBarItemIndex in
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: tabBarItems.items[tabBarItemIndex].imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)

                            Text(tabBarItems.items[tabBarItemIndex].itemSubtitle.localized())
                                .font(.fCaption)
                        }
                        .foregroundColor(
                            tabBarItemIndex == tabBarItems.selectedItemIndex ?
                                Color.blue : Color(red: 0.56, green: 0.56, blue: 0.56)
                        )
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        tabBarItems.changeSelected(tabBarItemIndex)
                    }
                }
            }
        }
        .frame(height: 60)
    }
}

struct TabBar_Previews: PreviewProvider {
    static var previews: some View {
        TabBar()
            .environmentObject(TBItems())
    }
}
