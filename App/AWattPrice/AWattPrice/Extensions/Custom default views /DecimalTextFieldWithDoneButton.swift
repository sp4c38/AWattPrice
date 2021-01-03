//
//  DecimalTextFieldWithDoneButton.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.12.20.
//

import SwiftUI

struct DecimalTextFieldWithDoneButton: UIViewRepresentable {
    typealias UIViewType = UITextField
    
    @Binding var text: String // Changes only when keyboard hides / done button is pressed
    
    var currentText: String // Changes at every character change
    var textFieldView: UITextField
    var placeholder: String
    var plusMinusButton: Bool
    
    init(text pText: Binding<String>, placeholder pPlaceholder: String, plusMinusButton pPlusMinusButton: Bool = false) {        self._text = pText
        
        self.currentText = pText.wrappedValue
        self.textFieldView = UITextField()
        self.placeholder = pPlaceholder
        self.plusMinusButton = pPlusMinusButton
    }
    
    func makeUIView(context: Context) -> UIViewType {
        let newUIView = textFieldView
        
        newUIView.keyboardType = .decimalPad
        newUIView.text = self.text
        newUIView.placeholder = self.placeholder
        newUIView.textAlignment = .left
        newUIView.delegate = context.coordinator
        
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(newUIView.doneButtonTapped(button:)))
        if self.plusMinusButton {
            let plusMinusButton = UIBarButtonItem(title: "+ / -", style: .plain, target: context.coordinator, action: #selector(context.coordinator.plusMinusPressed(button:)))
            toolBar.setItems([plusMinusButton, space, doneButton], animated: true)
        } else {
            toolBar.setItems([space, doneButton], animated: true)
        }
        
        newUIView.inputAccessoryView = toolBar
        return newUIView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.text = self.text
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DecimalTextFieldWithDoneButton
        
        init(_ textField: DecimalTextFieldWithDoneButton) {
            self.parent = textField
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            self.parent.text = textField.text ?? ""
            
            if let powerOutputString = parent.text.doubleValue?.priceString {
                self.parent.text = powerOutputString
            }
        }
        
        @objc func plusMinusPressed(button: UIBarButtonItem) {
            if self.parent.textFieldView.text != nil {
                let fieldText = self.parent.textFieldView.text!
                if fieldText.hasPrefix("-") {
                    let offsetIndex = fieldText.index(self.parent.currentText.startIndex, offsetBy: 1)
                    let newString = String(fieldText[offsetIndex...])
                    self.parent.textFieldView.text = newString
                } else {
                    self.parent.textFieldView.text = "-" + fieldText
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

extension UITextField {
    @objc func doneButtonTapped(button: UIBarButtonItem) -> Void {
        self.resignFirstResponder()
    }
}
