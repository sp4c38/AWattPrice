//
//  EasyTimeIntervalPickerRepresentable.swift
//  AWattPrice
//
//  Created by Léon Becker on 18.01.21.
//

import SwiftUI

struct EasyTimeIntervalPickerRepresentable: UIViewRepresentable {
    // Wrap a EasyTimeIntervalPicker in a SwiftUI View
    
    @Binding var selectedTimeInterval: TimeInterval
    
    let pickerMaxTimeInterval: TimeInterval
    let pickerSelectionInterval: Int
    
    init(selectedTimeInterval: Binding<TimeInterval>, maxTimeInterval: TimeInterval, selectionInterval: Int) {
        _selectedTimeInterval = selectedTimeInterval
        pickerMaxTimeInterval = maxTimeInterval
        pickerSelectionInterval = selectionInterval
    }
    
    func makeUIView(context: Context) -> EasyTimeIntervalPicker {
        let picker = EasyTimeIntervalPicker()
        picker.setMaxTimeInterval(pickerMaxTimeInterval)
        picker.setMinuteInterval(minuteInterval: pickerSelectionInterval)
        picker.onTimeIntervalChanged = { newSelection in
            selectedTimeInterval = newSelection
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: EasyTimeIntervalPicker, context: Context) {}
}
