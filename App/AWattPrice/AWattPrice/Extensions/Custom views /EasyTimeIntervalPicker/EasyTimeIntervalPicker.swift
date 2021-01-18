//
//  EasyTimeIntervalPicker.swift
//  AWattPrice
//
//  Created by Léon Becker on 18.01.21.
//

import UIKit

class EasyTimeIntervalPicker: UIPickerView, UIPickerViewDelegate, UIPickerViewDataSource {
    // Class initialization with main attributes
    
    var timeInterval: TimeInterval = 0
    var onTimeIntervalChanged: (Double) -> Void = {_ in }
    
    private let componentViewWidth: CGFloat = 80
    private let componentViewHeight: CGFloat = 32
    
    private let componentHoursID = 0
    private let componentMinutesID = 1
    
    private let largeInteger = 400 // Used to simulate infinite wheel effect.
    
    // Prepopulate with some default values
    private var maxTimeInterval: TimeInterval = TimeInterval(10800)
    private var allowZeroTimeInterval: Bool = false
    private var step: Int = 5
    private var countOfMinuteSteps: Int = 12 // How many steps fit within one hour.
    private var countOfHours: Int = 3 // How many hours do we display.
    private var maxMinutesRemainder: Int = 60 // Used to limit upper-bound selection.
    private var showingHoursPlural: Bool = true
    
    private var hoursLabel: UILabel?
    private var minLabel: UILabel?

    func setValuesAfterSuper() {
        self.dataSource = self
        self.delegate = self
        
        self.hoursLabel = newStaticLabelWithText(text: NSLocalizedString("hours", comment: ""))
        self.minLabel = newStaticLabelWithText(text: NSLocalizedString("min", comment: ""))
        self.addSubview(self.hoursLabel!)
        self.addSubview(self.minLabel!)
        self.updateStaticLabelsPositions()
        self.reloadAllComponents()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setValuesAfterSuper()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

extension EasyTimeIntervalPicker {
    private func newStaticLabelWithText(text: String) -> UILabel {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 75, height: componentViewHeight))
        label.text = text
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        return label
    }

    private func updateStaticLabelsPositions() {
        // Position the static labels
        let y: CGFloat = ((self.frame.height / 2) - 14.5)
        let x1 = (self.frame.width / 2) - 45
        let x2 = (self.frame.width / 2) + 66

        self.hoursLabel!.frame = CGRect(x: x1, y: y, width: 75, height: componentViewHeight)
        self.minLabel!.frame = CGRect(x: x2, y: y, width: 75, height: componentViewHeight)
    }
}

extension EasyTimeIntervalPicker {
    // Public methods
    
    func setMaxTimeInterval(_ newMaxTimeInterval: TimeInterval) {
        maxTimeInterval = newMaxTimeInterval

        let hours = Int(newMaxTimeInterval / 3600)
        let minutes = Int(newMaxTimeInterval / 60) - (hours * 60)
        maxMinutesRemainder = minutes
        countOfHours = hours
        reloadAllComponents()
        
        self.timeInterval = min(self.timeInterval, self.maxTimeInterval)
    }
    
    func setMinuteInterval(minuteInterval: Int) {
        var minuteInterval = minuteInterval
        let validMinuteIntervals = [1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30]
        if !validMinuteIntervals.contains(minuteInterval) {
            minuteInterval = 1 // Minute interval wasn't valid, use the default one
        }
        
        step = minuteInterval
        countOfMinuteSteps = 60 / step
        self.reloadComponent(componentMinutesID)
        
        let timeIntervalInMinutes = Int(self.timeInterval / 60)
        let minutes = timeIntervalInMinutes % 60
        var newMinutesRow = Int(minutes / step)

        if allowZeroTimeInterval == false && newMinutesRow == 0 {
            newMinutesRow += 1
        }
        
        if countOfHours > 0 {
            newMinutesRow += (countOfMinuteSteps * (largeInteger / 2))
        }

        self.selectRow(newMinutesRow, inComponent: componentMinutesID, animated: false)
    }
}

extension EasyTimeIntervalPicker {
    // Picker Datasources
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case componentHoursID:
            return countOfHours + 1 // We have to account for the "0 hours" row.
        case componentMinutesID:
            if countOfHours > 0 {
                return countOfMinuteSteps * largeInteger
            } else {
                return (maxMinutesRemainder / step) + 1 // The "+1" is to account for the 0 at the beginning.
            }
        default:
            break
        }
        return 0
    }


    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var viewWithLabel = view
        if viewWithLabel == nil {
            viewWithLabel = UIView.init(frame: CGRect(x: 0, y: 0, width: componentViewWidth, height: componentViewHeight))
            let label = UILabel.init(frame: CGRect(x: 11, y: 0, width: 30, height: componentViewHeight))
            label.font = UIFont.systemFont(ofSize: 23)
            label.textAlignment = .right
            viewWithLabel!.addSubview(label)
        }

        var number = 0
        if component == componentHoursID {
            number = row
        } else if component == componentMinutesID {
            number = (row % countOfMinuteSteps) * step
        }
        let label: UILabel = viewWithLabel!.subviews[0] as! UILabel
        label.text = String(format: "%lu", number)

        return viewWithLabel!
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return componentViewHeight
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return 106
    }
}

extension EasyTimeIntervalPicker {
    // Delegate functions
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        var hours = pickerView.selectedRow(inComponent: componentHoursID)
        var currentlySelectedMinsRow = pickerView.selectedRow(inComponent: componentMinutesID)
        var mins = (currentlySelectedMinsRow % countOfMinuteSteps) * step
        
        if allowZeroTimeInterval == false && hours == 0 && mins == 0 {
            mins += step
            self.selectRow(currentlySelectedMinsRow + 1, inComponent: componentMinutesID, animated: true)
        }
        
        if component == componentHoursID && hours == countOfHours {
            if mins > maxMinutesRemainder {
                // Limit to maxMinutesRemainder, because we are at the max hour and exceeded minutes.
                var changeOfMinutes = maxMinutesRemainder - mins
                if changeOfMinutes > 30 {
                    changeOfMinutes -= 60
                }
                var changeInSteps = changeOfMinutes / step
                if changeInSteps == 0 {
                    // We are over limit, but when devided by step, it gets rounded off to zero -> scroll down anyway
                    changeInSteps -= 1
                }
                mins += changeOfMinutes
                self.selectRow(currentlySelectedMinsRow + changeInSteps, inComponent: componentMinutesID, animated: true)
                currentlySelectedMinsRow += changeInSteps
            }
        } else if component == componentMinutesID && countOfHours == hours {
            // It was scrolled in the minutes component and we are at the highest hour.
            // If we are over maxMinutesRemainder, scroll the hour down.
            if mins > maxMinutesRemainder {
                hours -= 1
                self.selectRow(hours, inComponent: componentHoursID, animated: true)
            }
        }
        let newTimeInterval = TimeInterval((mins + (hours * 60)) * 60)
        self.onTimeIntervalChanged(TimeInterval(newTimeInterval))
        self.timeInterval = newTimeInterval
    }
}
