//
//  DecimalTextFieldWithDoneButton.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.12.20.
//

import SwiftUI

struct DecimalTextFieldWithDoneButton: UIViewRepresentable {
    typealias UIViewType = UITextField
    
    var currentText: String // Changes at every character change
    @Binding var text: String // Changes only when keyboard hides / done button is pressed
    var placeholder: String
    var plusMinusButton: Bool
    
    init(text pText: Binding<String>, placeholder pPlaceholder: String, plusMinusButton pPlusMinusButton: Bool = false) {
        self.placeholder = pPlaceholder
        self.plusMinusButton = pPlusMinusButton
        self._text = pText
        self.currentText = pText.wrappedValue
    }
    
    func makeUIView(context: Context) -> UIViewType {
        let newUIView = UIViewType()
        
        newUIView.keyboardType = .decimalPad
        newUIView.text = self.text
        newUIView.placeholder = self.placeholder
        newUIView.textAlignment = .left
        newUIView.delegate = context.coordinator
        
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: newUIView.frame.size.width, height: 44))
        
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
                parent.text = powerOutputString
            }
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            self.parent.currentText = textField.text ?? ""
            return true
        }
        
        @objc func plusMinusPressed(button: UIBarButtonItem) {
            if self.parent.currentText.hasPrefix("-") {
                print("a1")
                let offsetIndex = self.parent.currentText.index(self.parent.currentText.startIndex, offsetBy: 1)
                let newString = String(self.parent.currentText[offsetIndex...])
                self.parent.text = newString
                self.parent.currentText = newString
            } else {
                print("a2")
                self.parent.text = "-" + self.parent.currentText
                self.parent.currentText = "-" + self.parent.currentText
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
