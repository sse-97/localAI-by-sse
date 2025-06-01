//
//  ChatView.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

/// The main chat interface view where users interact with the LLM.
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageInput: String = ""
    @FocusState private var inputFocused: Bool
    
    private var isInputDisabled: Bool {
        viewModel.isGenerating || viewModel.isRestarting
        || viewModel.isInitializing || viewModel.llm == nil
    }
    private var isSendButtonDisabled: Bool {
        let trimmedInput = messageInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return (trimmedInput.isEmpty && !viewModel.isGenerating)
        || viewModel.isRestarting || viewModel.isInitializing
        || viewModel.llm == nil
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if viewModel.messages.isEmpty && !viewModel.isRestarting
                    && !viewModel.isInitializing && viewModel.llm != nil
                {
                    emptyStateView  // Show empty state if chat is empty and model is loaded
                } else {
                    chatHistoryView(scrollViewProxy: proxy)
                }
                Divider()
                inputAreaView
            }
            .overlay {  // Overlay for model switching/restarting
                if viewModel.isRestarting && !viewModel.isInitializing {  // Show only for restarts/switches, not initial load
                    restartingOverlayView(
                        title: "Initializing Model..."
                    )
                }
            }
            // Animations for smoother transitions
            .animation(.easeInOut(duration: 0.3), value: viewModel.isRestarting)
            .animation(.default, value: viewModel.messages.count)  // Default animation for message changes
        }
        .onTapGesture {  // Dismiss keyboard on tap outside input area
            hideKeyboard()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignConstants.largePadding) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor.opacity(0.7))
                .padding()
            Text("Start a Conversation").font(.title2).fontWeight(.medium)
            Text(
                (viewModel.llm == nil && !viewModel.isRestarting
                 && !viewModel.isInitializing)
                ? (viewModel.modelInfo.isEmpty
                   ? "Model not available. Check settings."
                   : viewModel.modelInfo)  // Show model info if LLM is nil
                : "Send a message to begin chatting with the AI."
            )
            .foregroundColor(.secondary).multilineTextAlignment(.center)
            .padding(.horizontal)
            if let modelName = viewModel.selectedModel?.displayName,
               viewModel.llm != nil
            {
                Text("Current model: \(modelName)").font(.caption)
                    .foregroundColor(.secondary).padding(
                        .top,
                        DesignConstants.mediumPadding
                    )
            }
            Spacer()
        }
        .padding().frame(maxHeight: .infinity)  // Ensure it takes full available space
    }
    
    private func chatHistoryView(scrollViewProxy: ScrollViewProxy) -> some View
    {
        ScrollView {
            LazyVStack(spacing: 0) {  // Use LazyVStack for performance with many messages
                ForEach(viewModel.messages) { message in
                    MessageView(
                        message: message,
                        isGenerating: viewModel.isGenerating,
                        isLastMessage: message.id
                        == viewModel.messages.last?.id,
                        onCopy: { contentToCopy in
                            viewModel.copyToClipboard(
                                contentToCopy,
                                messageId: message.id
                            )
                        },
                        copiedMessageId: viewModel.copiedMessageId
                    )
                    .id(message.id)  // Ensure each message has a unique ID for scrolling
                }
            }
            .padding(.vertical)  // Padding inside the ScrollView content
        }
        .onChange(of: viewModel.messages.count) { _, _ in  // Use new syntax if iOS 17+
            scrollToBottom(proxy: scrollViewProxy, animated: true)
        }
        .onChange(of: viewModel.messages.last?.content) { _, newContent in  // Use new syntax if iOS 17+
            // Scroll smoothly as AI types, but only if it's the AI's message
            if !(viewModel.messages.last?.isUser ?? true) {
                scrollToBottom(proxy: scrollViewProxy, animated: false)  // Less aggressive animation for streaming
            }
        }
        .onAppear {  // Scroll to bottom when view appears
            scrollToBottom(proxy: scrollViewProxy, animated: false)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessageID = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation(.spring()) {  // Spring animation for a natural feel
                proxy.scrollTo(lastMessageID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }
    
    private var inputAreaView: some View {
        HStack(alignment: .bottom, spacing: DesignConstants.mediumPadding) {
            TextField("Message...", text: $messageInput, axis: .vertical)
                .lineLimit(1...5)  // Allow multi-line input up to 5 lines
                .padding(DesignConstants.mediumPadding)
                .background(Color.systemGray6.cornerRadius(20))  // Rounded background for TextField
                .focused($inputFocused)
                .disabled(isInputDisabled)
                .submitLabel(.send)  // Show "Send" on keyboard return key
                .onSubmit(handleSendMessage)  // Handle send on return key press
            
            Button(action: {
                if viewModel.isGenerating {
                    viewModel.stop()
                } else {
                    handleSendMessage()
                }
            }) {
                Image(
                    systemName: viewModel.isGenerating
                    ? "stop.circle.fill" : "arrow.up.circle.fill"
                )
                .font(.system(size: DesignConstants.iconSize * 1.2))  // Slightly larger icon
                .foregroundColor(
                    isSendButtonDisabled && !viewModel.isGenerating
                    ? .gray.opacity(0.5)
                    : (viewModel.isGenerating ? .red : .accentColor)
                )
            }
            .disabled(isSendButtonDisabled && !viewModel.isGenerating)  // Disable if input is empty (and not generating) or other blocking states
            .buttonStyle(.plain)  // Use plain button style for custom appearance
            .accessibilityLabel(
                viewModel.isGenerating ? "Stop generation" : "Send message"
            )
            .animation(.easeInOut, value: viewModel.isGenerating)  // Animate icon change
        }
        .padding(DesignConstants.standardPadding)
        .background(.thinMaterial)  // Use thin material for a modern look
    }
    
    private func restartingOverlayView(title: String) -> some View {
        ZStack {
            // Semi-transparent background to dim the content behind
            Color.black.opacity(0.4).ignoresSafeArea().transition(
                .opacity.animation(.easeInOut)
            )
            VStack(spacing: DesignConstants.largePadding) {
                ProgressView().scaleEffect(1.5).tint(.white)  // Larger, white spinner
                Text(title)
                    .font(.headline).foregroundColor(.white)
            }
            .padding(DesignConstants.largePadding * 2)
            .background(.ultraThinMaterial)  // Material background for the overlay content
            .cornerRadius(DesignConstants.messageBubbleCornerRadius)
        }
    }
    
    private func handleSendMessage() {
        let trimmedInput = messageInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedInput.isEmpty, !isInputDisabled else { return }
        
        Task {
            await viewModel.sendMessage(text: trimmedInput)
        }
        messageInput = ""  // Clear input field
        inputFocused = false  // Dismiss keyboard if needed
    }
    
    private func hideKeyboard() {
        inputFocused = false
    }
}
