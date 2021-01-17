//
//  TimeIntervalPicker.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.01.21.
//

import SwiftUI

/// A time picker using UIDatePicker to select a time interval (e.g. 4 hour interval, 5 hour and 25 minutes interval,...)
 struct TimeIntervalPicker: UIViewRepresentable {
    var startDate = Date(timeIntervalSince1970: 1)
    var endDate = Date(timeIntervalSince1970: 1)
    var timeInterval: TimeInterval = 0
    
    class Coordinator {
        var currentPicker: TimeIntervalPicker

        init(_ currentPicker: TimeIntervalPicker) {
            self.currentPicker = currentPicker
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            // updates the associated values to reflect changes of the interval selection in the cheapestHourManager
            currentPicker.timeInterval = sender.date.timeIntervalSince(currentPicker.startDate)
            print(currentPicker.startDate)
            print(sender.date)
            print(currentPicker.timeInterval)
        }
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let intervalPicker = UIDatePicker()
        intervalPicker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged), for: .valueChanged)
        intervalPicker.minuteInterval = 5
        print(endDate.timeIntervalSince1970)
//        intervalPicker.minimumDate = Date(timeIntervalSince1970: 0)
//        intervalPicker.maximumDate = Date(timeIntervalSince1970: 172800)
        intervalPicker.date = endDate
        intervalPicker.datePickerMode = .countDownTimer
        intervalPicker.countDownDuration = TimeInterval(172800)
        return intervalPicker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
 }
