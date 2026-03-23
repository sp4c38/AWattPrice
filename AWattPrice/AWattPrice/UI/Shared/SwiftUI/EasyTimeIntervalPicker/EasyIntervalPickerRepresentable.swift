//
//  EasyTimeIntervalPickerRepresentable.swift
//  AWattPrice
//
//  Created by Léon Becker on 18.01.21.
//

import SwiftUI

/// Wrap a EasyTimeIntervalPicker in a SwiftUI View
struct EasyIntervalPickerRepresentable: UIViewRepresentable {
    @Binding var selectedTimeInterval: TimeInterval

    let pickerMaxTimeInterval: TimeInterval
    let pickerSelectionInterval: Int

    init(_ selectedTimeInterval: Binding<TimeInterval>, maxTimeInterval: TimeInterval, selectionInterval: Int) {
        _selectedTimeInterval = selectedTimeInterval
        pickerMaxTimeInterval = maxTimeInterval
        pickerSelectionInterval = selectionInterval
    }

    func makeUIView(context _: Context) -> EasyIntervalPicker {
        let picker = EasyIntervalPicker()
        picker.setMaxTimeInterval(pickerMaxTimeInterval)
        picker.onTimeIntervalChanged = { newSelection in
            DispatchQueue.main.async {
                selectedTimeInterval = newSelection
            }
        }
        picker.setMinuteInterval(minuteInterval: pickerSelectionInterval)
        return picker
    }

    func updateUIView(_ picker: EasyIntervalPicker, context _: Context) {
        picker.setMaxTimeInterval(pickerMaxTimeInterval)
    }
}
