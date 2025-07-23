//
//  TextFieldForm.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/28/23.
//

import SwiftUI

/** This is a simple `Form` containing a single `TextField` input. On appear, it will pull focus and submit the `onSubmit` callback when the "Done" button is pressed */
struct TextFieldForm: View {
    @Environment(\.presentationMode) private var presentation
    
    /** The editable text of the input `TextField` */
    @State var text: String
    
    /** Title of the input */
    let title: String
    
    /** Text shown under TextField*/
    let helperText: String?
    
    /** Called when "Done" button pressed with new value */
    let onSubmit: (_ name: String) -> Void
    
    // State vars to pull focus on appear
    enum FocusedField {
        case name
    }
    @FocusState private var focusedField: FocusedField?
        
    var body: some View {
        Form {
            Section {
                TextField(title, text: $text)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        self.onSubmit(text)
                        self.presentation.wrappedValue.dismiss()
                    }
                    .submitLabel(.done)
            } footer: {
                helperText != nil ? Text(helperText!) : nil
            }
        }
        .onAppear {
            UITextField.appearance().clearButtonMode = .whileEditing
            focusedField = .name
        }
        .defaultFocus($focusedField, .name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title)
    }
}

#Preview {
    TextFieldForm(
        text: "Test",
        title: "Device Nickname",
        helperText: "Please enter a nickname to be used to identify this device throughout the app.",
        onSubmit: { _ in }
    )
}
