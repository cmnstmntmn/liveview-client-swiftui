//
//  MultiDatePicker.swift
//  LiveViewNative
//
//  Created by Shadowfacts on 3/8/23.
//

#if os(iOS)
import SwiftUI

struct MultiDatePicker<R: RootRegistry>: View {
    private let context: LiveContext<R>
    @ObservedElement private var element
    @Attribute("start") private var start: Date?
    @Attribute("end") private var end: Date?
    @LiveBinding(attribute: "value-binding") private var dates: [SelectedDate] = []
    @State private var dateComponents = Set<DateComponents>()
    @State private var skipSettingDateComponents = false
    
    init(context: LiveContext<R>) {
        self.context = context
    }
    
    var body: some View {
        picker
            .onChange(of: dateComponents) { newValue in
                // otherwise this causes a loop which makes it impossible to deselect dates
                // using a Binding that maps between the [SelectedDate] and Set<DateComponents> representation doesn't work for the same reason
                skipSettingDateComponents = true
                dates = newValue.map { SelectedDate(dateComponents: $0) }
            }
            .onChange(of: dates) { newValue in
                if skipSettingDateComponents {
                    skipSettingDateComponents = false
                } else {
                    dateComponents = Set(newValue.map(\.dateComponents))
                }
            }
    }
    
    @ViewBuilder
    private var picker: some View {
        if let start, let end {
            SwiftUI.MultiDatePicker(selection: $dateComponents, in: start..<end) {
                context.buildChildren(of: element)
            }
        } else if let start {
            SwiftUI.MultiDatePicker(selection: $dateComponents, in: start...) {
                context.buildChildren(of: element)
            }
        } else if let end {
            SwiftUI.MultiDatePicker(selection: $dateComponents, in: ..<end) {
                context.buildChildren(of: element)
            }
        } else {
            SwiftUI.MultiDatePicker(selection: $dateComponents) {
                context.buildChildren(of: element)
            }
        }
    }
    
    struct SelectedDate: Codable, Equatable, Hashable {
        let dateComponents: DateComponents
        
        init(dateComponents: DateComponents) {
            self.dateComponents = dateComponents
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let date = try Date(string, strategy: .elixirDate)
            self.dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            let date = dateComponents.date!
            try container.encode(date.formatted(.elixirDate))
        }
    }
}
#endif
