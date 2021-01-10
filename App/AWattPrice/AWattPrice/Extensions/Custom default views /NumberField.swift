//
//  NumberField.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.12.20.
//

import SwiftUI

struct NumberField: UIViewRepresentable {
    typealias UIViewType = UITextField

    @Binding var text: String // Changes only when keyboard hides / done button is pressed

    var currentText: String // Changes at every character change
    var textFieldView: UITextField
    var placeholder: String
    var plusMinusButton: Bool
    var withDecimalSeperator: Bool

    init(text pText: Binding<String>, placeholder pPlaceholder: String, plusMinusButton pPlusMinusButton: Bool = false, withDecimalSeperator: Bool) {
        _text = pText
        currentText = pText.wrappedValue
        textFieldView = UITextField()
        placeholder = pPlaceholder
        plusMinusButton = pPlusMinusButton
        self.withDecimalSeperator = withDecimalSeperator
    }

    func makeUIView(context: Context) -> UIViewType {
        let newUIView = textFieldView

        newUIView.keyboardType = withDecimalSeperator ? .decimalPad : .numberPad
        newUIView.text = text
        newUIView.placeholder = placeholder
        newUIView.textAlignment = .left
        newUIView.delegate = context.coordinator

        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 44))

        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(newUIView.doneButtonTapped(button:)))
        if plusMinusButton {
            let plusMinusButton = UIBarButtonItem(title: "+ / -", style: .plain, target: context.coordinator, action: #selector(context.coordinator.plusMinusPressed(button:)))
            toolBar.setItems([plusMinusButton, space, doneButton], animated: true)
        } else {
            toolBar.setItems([space, doneButton], animated: true)
        }

        newUIView.inputAccessoryView = toolBar
        return newUIView
    }

    func updateUIView(_ uiView: UIViewType, context _: Context) {
        uiView.text = text
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NumberField

        init(_ textField: NumberField) {
            parent = textField
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.text = textField.text ?? ""

            if parent.withDecimalSeperator == true {
                if let doubleValue = parent.text.doubleValue?.priceString {
                    parent.text = doubleValue
                }
            }
        }

        @objc func plusMinusPressed(button _: UIBarButtonItem) {
            if parent.textFieldView.text != nil {
                let fieldText = parent.textFieldView.text!
                if fieldText.hasPrefix("-") {
                    let offsetIndex = fieldText.index(parent.currentText.startIndex, offsetBy: 1)
                    let newString = String(fieldText[offsetIndex...])
                    parent.textFieldView.text = newString
                } else {
                    parent.textFieldView.text = "-" + fieldText
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

extension UITextField {
    @objc func doneButtonTapped(button _: UIBarButtonItem) {
        resignFirstResponder()
    }
}
