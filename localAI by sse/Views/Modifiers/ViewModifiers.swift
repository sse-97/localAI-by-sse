//
//  ViewModifiers.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import SwiftUI

// MARK: - View Modifiers

/// A `ViewModifier` to apply a standard message bubble appearance.
struct MessageBubbleStyle: ViewModifier {
    let isUserMessage: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(DesignConstants.standardPadding)
            .foregroundColor(isUserMessage ? .black : .primary)
            .background(
                isUserMessage
                ? Color.accentColor
                : Color.secondarySystemBackground
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignConstants.messageBubbleCornerRadius
                )
            )
            .textSelection(.enabled)
    }
}

extension View {
    func messageBubble(isUserMessage: Bool) -> some View {
        modifier(MessageBubbleStyle(isUserMessage: isUserMessage))
    }
}
