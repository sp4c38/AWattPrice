//
//  TimeIntervalPicker.swift
//  AwattarApp
//
//  Created by Léon Becker on 20.09.20.
//

import SwiftUI

struct TimeIntervalPicker: UIViewRepresentable {
    // Time Interval Picker which uses UIDatePicker
    
    @ObservedObject var cheapestHourCalculator: CheapestHourCalculator

    class Coordinator {
        var selectedInterval: TimeIntervalPicker

        init(_ selectedInterval: TimeIntervalPicker) {
            self.selectedInterval = selectedInterval
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            self.selectedInterval.cheapestHourCalculator.lengthOfUsageDate = sender.date
            self.selectedInterval.cheapestHourCalculator.checkIntervalFitsInRange()
        }
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let intervalPicker = UIDatePicker()
        intervalPicker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged), for: .valueChanged)
        return intervalPicker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.minuteInterval = 5
        picker.date = cheapestHourCalculator.lengthOfUsageDate
        picker.datePickerMode = .countDownTimer
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}
