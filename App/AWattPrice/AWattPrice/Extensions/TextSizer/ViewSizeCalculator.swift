////
////  ViewSizeCalculator.swift
////  AWattPrice
////
////  Created by Léon Becker on 31.01.21.
////
//
//import SwiftUI
//
///// Get the width and height of a Text object.
//class ViewSizeCalculator {
//    private var view: AnyView?
//    var viewSize: CGSize?
//    private var viewSemaphore = DispatchSemaphore(value: 0)
//
//    init() {
//        view = nil
//        viewSize = nil
//    }
//}
//
//extension ViewSizeCalculator {
//    private struct ViewSizePreferenceKey: PreferenceKey {
//        struct SizeBounds: Equatable {
//            static func == (
//                _: ViewSizeCalculator.ViewSizePreferenceKey.SizeBounds,
//                _: ViewSizeCalculator.ViewSizePreferenceKey.SizeBounds
//            ) -> Bool {
//                return false
//            }
//
//            var bounds: Anchor<CGRect>
//        }
//
//        static var defaultValue: SizeBounds? = nil
//
//        static func reduce(value: inout SizeBounds?, nextValue: () -> SizeBounds?) {
//            value = nextValue()
//        }
//    }
//}
//
//extension ViewSizeCalculator {
//    func SizeViewMaker<Content: View>(@ViewBuilder content: () -> Content) -> AnyView {
//        viewSemaphore = DispatchSemaphore(value: 0)
//
//        let bodyView = AnyView(content())
//
//        bodyView
//            .anchorPreference(
//                key: ViewSizePreferenceKey.self,
//                value: .bounds,
//                transform: {
//                    ViewSizePreferenceKey.SizeBounds(bounds: $0)
//                }
//            )
//            .backgroundPreferenceValue(ViewSizePreferenceKey.self) { viewSize in
//                if viewSize != nil {
//                    GeometryReader { geometry in
//                        self.setViewSize(sizeBounds: viewSize!, geo: geometry)
//                    }
//                }
//            }
//
//        viewSemaphore.wait()
//        mSemaphore.signal()
//
//        print("started wait")
//        print("end wait")
//        view = AnyView(modifiedView)
//        return view!
//    }
//
//    private func setViewSize(
//        sizeBounds: ViewSizePreferenceKey.SizeBounds, geo: GeometryProxy
//    ) -> some View {
//        viewSize = geo[sizeBounds.bounds].size
//        print("RAN")
//        viewSemaphore.signal()
//        return Color.clear
//    }
//}
//
//extension ViewSizeCalculator {
//    func getViewSize() -> CGSize? {
//        guard let size = viewSize else { return nil }
//        return size
//    }
//}
