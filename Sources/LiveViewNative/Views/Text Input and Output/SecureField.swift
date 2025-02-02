//
//  SecureField.swift
//  
//
//  Created by Carson Katri on 1/12/23.
//

import SwiftUI

struct SecureField<R: RootRegistry>: TextFieldProtocol {
    @ObservedElement var element: ElementNode
    let context: LiveContext<R>
    @FormState var value: String?
    @FocusState private var isFocused: Bool
    
    let focusEvent = Event("phx-focus", type: "focus")
    let blurEvent = Event("phx-blur", type: "blur")
    
    init(element: ElementNode, context: LiveContext<R>) {
        self.context = context
    }
    
    var body: some View {
        SwiftUI.SecureField(
            text: textBinding,
            prompt: prompt
        ) {
            label
        }
            .focused($isFocused)
            .onChange(of: isFocused, perform: handleFocus)
            .applyTextFieldStyle(textFieldStyle)
            .applyAutocorrectionDisabled(disableAutocorrection)
#if os(iOS) || os(tvOS)
            .textInputAutocapitalization(autocapitalization)
            .applyKeyboardType(keyboard)
#endif
            .applySubmitLabel(submitLabel)
            .preference(key: ProvidedBindingsKey.self, value: ["phx-focus", "phx-blur"])
    }
}

