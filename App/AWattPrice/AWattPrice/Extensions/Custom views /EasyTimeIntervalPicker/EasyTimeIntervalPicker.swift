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
    var timeIntervalChanged: (Double) -> Void = {_ in }
    
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
