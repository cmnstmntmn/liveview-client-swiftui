//
//  ViewModel.swift
// LiveViewNative
//
//  Created by Shadowfacts on 1/12/22.
//

import Foundation
import Combine
import LiveViewNativeCore

/// The working-copy data model for a ``LiveView``.
///
/// In a view in the LiveView tree, a model can be obtained using `@EnvironmentObject`.
public class LiveViewModel: ObservableObject {
    private var forms = [String: FormModel]()
    var cachedNavigationTitle: NavigationTitleModifier?
    
    private(set) var bindingValues = [String: Any]()
    let bindingUpdatedByServer = PassthroughSubject<(String, Any), Never>()
    let bindingUpdatedByClient = PassthroughSubject<(String, Any), Never>()
    
    /// Get or create a ``FormModel`` for the given `<live-form>`.
    ///
    /// - Important: The element parameter must be the form element. To get the form model for an element within a form, use the ``LiveContext`` or the `\.formModel` environment value.
    public func getForm(elementID id: String) -> FormModel {
        if let form = forms[id] {
            return form
        } else {
            let model = FormModel(elementID: id)
            forms[id] = model
            return model
        }
    }
    
    /// Called whenever the document changes to update form models with their current data from the DOM and remove any models for no-longer-present forms.
    func updateForms(nodes: NodeDepthFirstChildrenSequence) {
        var formIDs = Set<String>()
        for node in nodes {
            guard case .element(let elementData) = node.data,
                  elementData.namespace == nil && elementData.tag == "live-form" else {
                continue
            }
            let id = node["id"]!.value!
            formIDs.insert(id)
            forms[id]?.updateFromElement(ElementNode(node: node, data: elementData))
        }
        for id in forms.keys where !formIDs.contains(id) {
            forms.removeValue(forKey: id)
        }
    }
    
    func updateBindings(payload: Payload) {
        for (key, value) in payload {
            bindingValues[key] = value
            bindingUpdatedByServer.send((key, value))
        }
    }
    
    func setBinding(_ name: String, to encodedValue: Any) {
        bindingValues[name] = encodedValue
        bindingUpdatedByClient.send((name, encodedValue))
    }
}

/// A form model stores the working copy of the data for a specific `<form>` element.
///
/// To obtain a form model, use ``LiveViewModel/getForm(elementID:)`` or the `\.formModel` environment key.
public class FormModel: ObservableObject, CustomDebugStringConvertible {
    let elementID: String
    @_spi(LiveForm) public var pushEventImpl: ((String, String, Any, Int?) async throws -> Void)!
    var changeEvent: String?
    var submitEvent: String?
    /// The form data for this form.
    @Published internal private(set) var data = [String: any FormValue]()
    var formFieldWillChange = PassthroughSubject<String, Never>()
    
    init(elementID: String) {
        self.elementID = elementID
    }
    
    @_spi(LiveForm) public func updateFromElement(_ element: ElementNode) {
        changeEvent = element.attributeValue(for: "phx-change")
        submitEvent = element.attributeValue(for: "phx-submit")
    }
    
    /// Sends a phx-change event (if configured) to the server with the current form data.
    ///
    /// This method has no effect if the `<form>` does not have a `phx-change` event configured.
    ///
    /// See ``LiveViewCoordinator/pushEvent(type:event:value:)`` for more information.
    @MainActor
    public func sendChangeEvent() async throws {
        if let changeEvent = changeEvent {
            try await pushFormEvent(changeEvent)
        }
    }
    
    /// Sends a phx-submit event (if configured) to the server with the current form data.
    ///
    /// This method has no effect if the `<form>` does not have a `phx-submit` event configured.
    ///
    /// See ``LiveViewCoordinator/pushEvent(type:event:value:)`` for more information.
    @MainActor
    public func sendSubmitEvent() async throws {
        if let submitEvent = submitEvent {
            try await pushFormEvent(submitEvent)
        }
    }
    
    @MainActor
    private func pushFormEvent(_ event: String) async throws {
        let urlQueryEncodedData = data.map { k, v in
            // todo: in what cases does addingPercentEncoding return nil? do we care?
            "\(k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)=\(v.formValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        }.joined(separator: "&")

        try await pushEventImpl("form", event, urlQueryEncodedData, nil)
    }
    
    public var debugDescription: String {
        return "FormModel(element: #\(elementID), id: \(ObjectIdentifier(self))"
    }
    
    /// Access the stored value, if there is one, for the form field of the given name.
    ///
    /// Setting a field to `nil` removes it.
    ///
    /// Setting a field automatically sends a change event if one was configured on the `<live-form>` element.
    public subscript(name: String) -> (any FormValue)? {
        get {
            return data[name]
        }
        set(newValue) {
            if let existing = data[name],
               let newValue = newValue {
                if !existing.isEqual(to: newValue) {
                    formFieldWillChange.send(name)
                }
            } else if data[name] != nil || newValue != nil {
                // something -> nil or nil -> something
                formFieldWillChange.send(name)
            } else {
                // nothing to do
                return
            }
            data[name] = newValue
            Task {
                try? await sendChangeEvent()
            }
        }
    }
    
    /// Clears all data in this form.
    public func clear() {
        for field in data.keys {
            formFieldWillChange.send(field)
        }
        data = [:]
    }
    
}
