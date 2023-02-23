//
//  ScrollView.swift
//  LiveViewNative
//
//  Created by Shadowfacts on 2/9/22.
//

import SwiftUI

struct ScrollView<R: CustomRegistry>: View {
    @ObservedElement private var element: ElementNode
    private let context: LiveContext<R>
    
    init(element: ElementNode, context: LiveContext<R>) {
        self.context = context
    }
    
    public var body: some View {
        SwiftUI.ScrollViewReader { proxy in
            SwiftUI.ScrollView(
                element.attributeValue(for: "axes").flatMap(Axis.Set.init) ?? .vertical,
                showsIndicators: element.attributeBoolean(for: "shows-indicators")
            ) {
                context.buildChildren(of: element)
            }
            .onAppear {
                guard let scrollPosition = element.attributeValue(for: "scroll-position")
                else { return }
                proxy.scrollTo(scrollPosition, anchor: scrollPositionAnchor)
            }
            .onChange(of: element.attributeValue(for: "scroll-position")) { newValue in
                guard let newValue else { return }
                proxy.scrollTo(newValue, anchor: scrollPositionAnchor)
            }
        }
    }
    
    private var scrollPositionAnchor: UnitPoint? {
        element.attributeValue(for: "scroll-position-anchor")?
            .data(using: .utf8)
            .flatMap { try? JSONDecoder().decode(UnitPoint.self, from: $0) }
    }
}
