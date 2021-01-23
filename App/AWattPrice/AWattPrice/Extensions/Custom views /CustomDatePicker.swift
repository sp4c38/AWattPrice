//
//  ComparisonDatePicker.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.11.20.
//

import SwiftUI

struct ComparisonDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    var range: ClosedRange<Date>

    init(selection: Binding<Date>, in range: ClosedRange<Date>) {
        _selection = selection
        self.range = range
    }

    class Coordinator: NSObject {
        @Binding var selection: Date

        init(selection: Binding<Date>) {
            _selection = selection
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            selection = sender.date
        }
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.minuteInterval = 1
        datePicker.semanticContentAttribute = .forceRightToLeft
        datePicker.subviews.first?.semanticContentAttribute = .forceRightToLeft
        datePicker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged
        )
        return datePicker
    }

    func updateUIView(_ uiView: UIDatePicker, context _: Context) {
        uiView.date = selection
        uiView.minimumDate = range.lowerBound
        uiView.maximumDate = range.upperBound
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }
}
