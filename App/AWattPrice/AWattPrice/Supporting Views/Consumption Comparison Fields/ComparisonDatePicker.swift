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
        self._selection = selection
        self.range = range
    }
    
    class Coordinator: NSObject {
        @Binding var selection: Date
        
        init(selection: Binding<Date>) {
            self._selection = selection
        }
        
        @objc func dateChanged(_ sender: UIDatePicker) {
            self.selection = sender.date
        }
    }
    
    func makeUIView(context: Context) -> UIDatePicker {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.minuteInterval = 1
        datePicker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        
        return datePicker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = self.selection
        uiView.minimumDate = range.lowerBound
        uiView.maximumDate = range.upperBound
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }
}

struct ComparisonDatePicker_PreviewsView: View {
    var body: some View {
        VStack(spacing: 0) {
            ComparisonDatePicker(selection: .constant(Date()), in: Date()...Date())
                .frame(width: 160, height: 40)
        }
    }
}

struct ComparisonDatePicker_Previews: PreviewProvider {
    static var previews: some View {
        ComparisonDatePicker_PreviewsView()
    }
}
