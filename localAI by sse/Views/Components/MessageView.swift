//
//  MessageView.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import SwiftUI

// MARK: - Chat UI Components

/// A view that displays a single message (either from the user or the AI).
struct MessageView: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: Message
    let isGenerating: Bool
    let isLastMessage: Bool  // Is this the absolute last message in the chat?
    let onCopy: (String) -> Void
    let copiedMessageId: UUID?
    
    // Determines if this specific message bubble should show a typing indicator
    private var isTypingIndicator: Bool {
        !message.isUser && message.content.isEmpty && isGenerating && isLastMessage
    }
    
    private var displayText: String {
        isTypingIndicator ? "Typing..." : message.content
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()  // Push user messages to the right
                Text(message.content)
                    .messageBubble(isUserMessage: true)
            } else {
                botMessageContent
                Spacer()  // Keep bot messages to the left
            }
        }
        .padding(.horizontal, DesignConstants.standardPadding)
        .padding(.vertical, DesignConstants.smallPadding)
        .contextMenu {
            // Only allow copying non-empty AI messages
            if !message.isUser && !message.content.isEmpty && !isTypingIndicator {
                Button {
                    onCopy(message.content)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            message.isUser
            ? "User message: \(message.content)"
            : "AI message: \(displayText)"
        )
    }
    
    @ViewBuilder
    private var botMessageContent: some View {
        HStack(alignment: .bottom, spacing: DesignConstants.mediumPadding) {
            Text(displayText)
                .messageBubble(isUserMessage: false)
                .overlay(alignment: .bottomTrailing) {  // For "Copied!" confirmation
                    if !message.isUser && message.id == copiedMessageId {
                        Text("Copied!")
                            .font(.caption2).fontWeight(.bold)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(Color.white)
                            .clipShape(Capsule())
                            .transition(.opacity.animation(.default))
                            .padding(5)  // Padding around the "Copied!" capsule
                            .id("copyConfirmation-\(message.id)")  // Ensure unique ID for transition
                    }
                }
            
            if isTypingIndicator {
                ProgressView()  // Show spinner next to "Typing..."
                    .scaleEffect(DesignConstants.progressIndicatorScale)
                    .padding(.bottom, DesignConstants.mediumPadding)  // Align with text baseline
            }
        }
    }
}
