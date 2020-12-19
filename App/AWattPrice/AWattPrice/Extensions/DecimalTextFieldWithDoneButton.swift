//
//  DecimalTextFieldWithDoneButton.swift
//  AWattPrice
//
//  Created by Léon Becker on 19.12.20.
//

import SwiftUI

struct DecimalTextFieldWithDoneButton: UIViewRepresentable {
    typealias UIViewType = UITextField
    
    @Binding var text: String
    let placeholder: String
    
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
        
        toolBar.setItems([space, doneButton], animated: true)
        
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
