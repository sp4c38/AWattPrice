//
//  ViewSizeCalculator.swift
//  AWattPrice
//
//  Created by Léon Becker on 31.01.21.
//

import SwiftUI

/// Get the width and height of a Text object.
class ViewSizeCalculator {
    private var view: AnyView?
    var viewSize: CGSize?
    
    init() {
        view = nil
        viewSize = nil
    }
}

extension ViewSizeCalculator {
    private struct ViewSizePreferenceKey: PreferenceKey {
        struct SizeBounds: Equatable {
            static func == (
                _: ViewSizeCalculator.ViewSizePreferenceKey.SizeBounds,
                _: ViewSizeCalculator.ViewSizePreferenceKey.SizeBounds
            ) -> Bool {
                return false
            }
            
            var bounds: Anchor<CGRect>
        }
        
        static var defaultValue: SizeBounds? = nil
        
        static func reduce(value: inout SizeBounds?, nextValue: () -> SizeBounds?) {
            value = nextValue()
        }
    }
}

extension ViewSizeCalculator {
    func SizeViewMaker<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let contentView = content() as? AnyView
        guard let insideView = contentView else { return contentView }
        let modifiedView = insideView
            .anchorPreference(
                key: ViewSizePreferenceKey.self,
                value: .bounds,
                transform: {
                    ViewSizePreferenceKey.SizeBounds(bounds: $0)
                }
            )
            .backgroundPreferenceValue(ViewSizePreferenceKey.self) { viewSize in
                if viewSize != nil {
                    GeometryReader { geometry in
                        self.setViewSize(sizeBounds: viewSize!, geo: geometry)
                    }
                }
            }
        view = AnyView(modifiedView)
        return view
    }
    
    private func setViewSize(
        sizeBounds: ViewSizePreferenceKey.SizeBounds, geo: GeometryProxy
    ) -> some View {
        viewSize = geo[sizeBounds.bounds].size
        return Color.clear
    }
}

extension ViewSizeCalculator {
    func getViewSize() -> CGSize? {
        guard let size = viewSize else { return nil }
        return size
    }
}
