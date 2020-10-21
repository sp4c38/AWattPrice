//
//  TimeIntervalPicker.swift
//  AwattarApp
//
//  Created by Léon Becker on 20.09.20.
//

import SwiftUI

/// A time picker using UIDatePicker to select a time interval (e.g. 4 hour interval, 5 hour and 25 minutes interval,...)
struct TimeIntervalPicker: UIViewRepresentable {
    @ObservedObject var cheapestHourManager: CheapestHourManager

    class Coordinator {
        var selectedInterval: TimeIntervalPicker

        init(_ selectedInterval: TimeIntervalPicker) {
            self.selectedInterval = selectedInterval
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            // updates the associated values to reflect changes of the interval selection in the cheapestHourManager
            self.selectedInterval.cheapestHourManager.lengthOfUsageDate = sender.date
            self.selectedInterval.cheapestHourManager.checkIntervalFitsInRange()
        }
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let intervalPicker = UIDatePicker()
        // coordinator is needed to reflect changes of the interval selection in the cheapestHourManager
        intervalPicker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged), for: .valueChanged)
        return intervalPicker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.minuteInterval = 5
        picker.date = cheapestHourManager.lengthOfUsageDate
        picker.datePickerMode = .countDownTimer
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}
