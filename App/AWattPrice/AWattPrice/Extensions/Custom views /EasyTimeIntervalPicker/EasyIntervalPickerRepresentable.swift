//
//  EasyTimeIntervalPickerRepresentable.swift
//  AWattPrice
//
//  Created by Léon Becker on 18.01.21.
//

import SwiftUI

struct EasyIntervalPickerRepresentable: UIViewRepresentable {
    // Wrap a EasyTimeIntervalPicker in a SwiftUI View
    
    @Binding var selectedTimeInterval: TimeInterval
    
    let pickerMaxTimeInterval: TimeInterval
    let pickerSelectionInterval: Int

    init(_ selectedTimeInterval: Binding<TimeInterval>, maxTimeInterval: TimeInterval, selectionInterval: Int) {
        _selectedTimeInterval = selectedTimeInterval
        pickerMaxTimeInterval = maxTimeInterval
        pickerSelectionInterval = selectionInterval
    }
    
    func makeUIView(context: Context) -> EasyIntervalPicker {
        let picker = EasyIntervalPicker()
        picker.setMaxTimeInterval(pickerMaxTimeInterval)
        picker.setMinuteInterval(minuteInterval: pickerSelectionInterval)
        picker.onTimeIntervalChanged = { newSelection in
            selectedTimeInterval = newSelection
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: EasyIntervalPicker, context: Context) {}
}
