//
//  ListItem.swift
//  AWattPrice
//
//  Created by Léon Becker on 31.10.20.
//

import SwiftUI


struct CustomInsetGroupedList<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9686) : Color.black)
        .ignoresSafeArea()
    }
}

struct CustomInsetGroupedListItem<Content: View>: View { // All content which is parsed must only conform to View
    @Environment(\.colorScheme) var colorScheme
    let header: Text
    let footer: Text
    let content: Content
    var backgroundColor: Color?
    
    init(header: Text = Text(""), footer: Text = Text(""), @ViewBuilder content: () -> Content, backgroundColor: Color? = nil) {
        self.header = header
        self.footer = footer
        self.content = content()
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            header
                .textCase(.uppercase)
                .font(.caption)
                .foregroundColor(Color(hue: 0.7083, saturation: 0.0312, brightness: 0.5020))
            
            VStack {
                content
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor != nil ? backgroundColor : (colorScheme == .light ? Color.white : Color(hue: 0.6667, saturation: 0.0667, brightness: 0.1176)))
            .cornerRadius(10)
            
            footer
                .font(.caption2)
                .foregroundColor(Color(hue: 0.7083, saturation: 0.0312, brightness: 0.5020))
        }
        .padding([.leading, .trailing], 30)
    }
    
    func customBackgroundColor(_ color: Color) -> Self {
        var copy = self
        copy.backgroundColor = color
        return copy
    }
}

struct ListItem_Previews: PreviewProvider {
    static var previews: some View {
        CustomInsetGroupedList {
            CustomInsetGroupedListItem(
                header: Text("Test Header"),
                footer: Text("d")
            ) {
                VStack {
                    Text("Test Text")
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
