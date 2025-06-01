//
//  ContentView.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

/// The main content view that orchestrates the entire application interface
struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingGlobalResetConfirmation = false  // For the toolbar reset option
    
    var body: some View {
        mainContent
            .environmentObject(viewModel)
            .sheet(
                isPresented: $viewModel.isShowingModelConfigSheet,
                onDismiss: handleSheetDismiss
            ) {
                modelConfigurationSheetContent
            }
            .sheet(isPresented: $viewModel.isShowingDocumentPicker) {
                DocumentPicker { url, filename in
                    viewModel.handlePickedModelFile(temporaryFileURL: url, originalFilename: filename)
                }
            }
            .alert(item: $viewModel.userAlert) { alertContent in
                Alert(
                    title: Text(alertContent.title),
                    message: Text(alertContent.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(errorOverlayContent)
            .overlay(errorBannerContent)
            .alert(
                StringConstants.emergencyResetTitle,
                isPresented: $isShowingGlobalResetConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Reset Application", role: .destructive) {
                    viewModel.emergencyReset()
                }
            } message: {
                Text(StringConstants.emergencyResetMessage)
            }
            .alert(
                "Important Information",
                isPresented: contentDisclaimerBinding
            ) {
                Button("I Understand") {
                    viewModel.hasShownContentDisclaimer = true
                    UserDefaults.standard.set(
                        true,
                        forKey: "hasShownContentDisclaimer"
                    )
                }
            } message: {
                Text(
                    "This app uses AI models to generate content. While we implement safeguards, AI may occasionally produce unexpected or inappropriate responses. Content is generated locally on your device and not monitored."
                )
            }
    }
    
    // MARK: - Computed Properties
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if viewModel.isOSVersionIncompatible {
                VersionIncompatibleView()
            } else if viewModel.isInitializing {
                LoadingView(modelInfo: viewModel.modelInfo)
            } else if viewModel.llm == nil && !viewModel.isRestarting {
                // If LLM is nil and not currently in a restart (model switch) process, show error.
                // viewModel.modelInfo might contain a specific error message.
                ModelErrorView(
                    errorMessage: viewModel.modelInfo.isEmpty
                    ? StringConstants.defaultModelLoadErrorMessage
                    : viewModel.modelInfo
                )
            } else {
                tabViewContent
            }
        }
    }
    
    @ViewBuilder
    private var modelConfigurationSheetContent: some View {
        // Content of the sheet for model configuration
        if let tempURL = viewModel.pickedTemporaryModelFileURL,
           let originalFilename = viewModel.originalPickedModelFilename
        {
            ModelConfigurationSheet(
                temporaryFileURL: tempURL,
                originalFilename: originalFilename,
                onComplete: {
                    configuredModelIntent,
                    templateType,
                    systemPrompt in
                    viewModel.processConfiguredModel(
                        configuredModelIntent,
                        templateType: templateType,
                        systemPrompt: systemPrompt
                    )
                },
                onCancel: {
                    viewModel.isShowingModelConfigSheet = false  // Dismiss the sheet
                    viewModel.cleanupTemporaryFile()  // Clean up temp file state
                }
            )
        } else {
            // Fallback if sheet is shown without necessary data (should not happen with current logic)
            VStack {
                Text(
                    "Error: Missing model file information for configuration."
                )
                .padding()
                Button("Dismiss") {
                    viewModel.isShowingModelConfigSheet = false
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var errorOverlayContent: some View {
        Group {
            if let currentError = viewModel.currentError {
                ErrorOverlayView(
                    error: currentError,
                    onRecovery: { action in
                        viewModel.executeRecoveryAction(action)
                    },
                    onDismiss: { viewModel.clearCurrentError() }
                )
            }
        }
    }
    
    @ViewBuilder
    private var errorBannerContent: some View {
        Group {
            if let bannerError = viewModel.bannerError {
                VStack {
                    ErrorBannerView(
                        error: bannerError,
                        onDismiss: { viewModel.clearBannerError() },
                        onRetry: { action in
                            viewModel.executeRecoveryAction(action)
                        }
                    )
                    .padding(.horizontal)
                    Spacer()
                }
                .animation(.easeInOut, value: bannerError)
            }
        }
    }
    
    private var contentDisclaimerBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                !viewModel.hasShownContentDisclaimer
                && !viewModel.isInitializing
            },
            set: { newValue in
                if !newValue {
                    viewModel.hasShownContentDisclaimer = true
                    UserDefaults.standard.set(
                        true,
                        forKey: "hasShownContentDisclaimer"
                    )
                }
            }
        )
    }
    
    private func handleSheetDismiss() {
        // This onDismiss is for the sheet itself.
        // If the user cancels ModelConfigurationSheet, its onCancel should call cleanupTemporaryFile.
        // If they complete, processConfiguredModel is called.
        // This ensures cleanup if the sheet is dismissed by swipe without interaction.
        if viewModel.pickedTemporaryModelFileURL != nil {  // If a file was picked but not processed
            viewModel.logDebug(
                "--- ModelConfigurationSheet dismissed, cleaning up any pending temporary file state. ---"
            )
            viewModel.cleanupTemporaryFile()
        }
    }
    
    private var tabViewContent: some View {
        TabView {
            NavigationView {
                ChatView(viewModel: viewModel)
                    .navigationTitle(
                        viewModel.selectedModel?.displayName ?? "AI Chat"
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { navigationToolbarContent }  // Common toolbar for ChatView
            }
            .tabItem { Label("Chat", systemImage: "message.fill") }.tag(0)
            
            NavigationView { SystemMonitorView(viewModel: viewModel) }
                .tabItem {
                    Label(
                        "Monitor",
                        systemImage: "gauge.with.dots.needle.33percent"
                    )
                }.tag(1)
            
            NavigationView { ParameterSettingView(viewModel: viewModel) }
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }.tag(2)
            
            NavigationView { PrivacyPolicyView() }
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }.tag(3)
        }
        // Apply alert for model deletion confirmation at a higher level if needed,
        // but ParameterSettingView handles its own specific alert.
    }
    
    @ToolbarContentBuilder
    private var navigationToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {  // Usually top-right
            Menu {
                // Section for switching models
                modelSwitchMenu
                
                Divider()
                
                // Common chat actions
                chatActionButtons
                
                Divider()
                
                // Debug toggle
                Toggle(
                    "Debug Mode",
                    isOn: $viewModel.debugModeEnabled.animation()
                )
                .onChange(of: viewModel.debugModeEnabled) { _, newValue in
                    viewModel.logDebug(
                        "--- Debug mode \(newValue ? "enabled" : "disabled") by user (Toolbar Menu) ---"
                    )
                }
                
                Divider()
                
                // Emergency Reset
                Button(role: .destructive) {
                    isShowingGlobalResetConfirmation = true
                } label: {
                    Label(
                        StringConstants.emergencyResetTitle,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }
                .disabled(viewModel.isInitializing)  // Disable if app is in initial loading state
                
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .imageScale(.large)  // Make icon slightly larger and easier to tap
            }
            .disabled(viewModel.isInitializing)  // Disable entire menu during initial load
        }
    }
    
    @ViewBuilder private var modelSwitchMenu: some View {
        let bundled = viewModel.models.filter { !$0.isUserAdded }
        let custom = viewModel.models.filter { $0.isUserAdded }
        
        Menu("Switch Model") {
            if !bundled.isEmpty {
                Section("Built-in Models") {
                    ForEach(bundled) { model in
                        modelMenuItem(for: model)
                    }
                }
            }
            if !custom.isEmpty {
                Section("Custom Models") {
                    ForEach(custom) { model in
                        modelMenuItem(for: model)
                    }
                }
            }
            if bundled.isEmpty && custom.isEmpty {
                Text("No models available").disabled(true)
            }
        }
        .disabled(
            viewModel.isGenerating || viewModel.isRestarting
            || viewModel.isInitializing
        )
    }
    
    @ViewBuilder
    private func modelMenuItem(for model: ModelConfig) -> some View {
        Button(action: {
            if viewModel.selectedModel?.id != model.id {
                viewModel.switchModel(to: model)
            }
        }) {
            HStack {
                Text(model.displayName)
                if model.id == viewModel.selectedModel?.id {
                    Spacer()
                    Image(systemName: "checkmark")  // Indicate selected model
                }
            }
        }
        // Disable if busy or if this model is already selected
        .disabled(
            viewModel.isGenerating || viewModel.isRestarting
            || viewModel.isInitializing
            || model.id == viewModel.selectedModel?.id
        )
    }
    
    @ViewBuilder private var chatActionButtons: some View {
        Group {
            Button(role: .destructive) {
                viewModel.clearChat()
            } label: {
                Label("Clear Chat", systemImage: "trash")
            }
            .disabled(
                viewModel.messages.isEmpty || viewModel.isGenerating
                || viewModel.isRestarting || viewModel.isInitializing
            )
            
            if viewModel.isGenerating {
                Button(role: .destructive) {
                    viewModel.stop()
                } label: {
                    Label("Stop Generation", systemImage: "stop.fill")
                }
                .disabled(!viewModel.isGenerating)  // Should always be enabled if isGenerating is true
            } else {
                Button {
                    viewModel.restart()
                } label: {
                    Label("Restart LLM", systemImage: "arrow.clockwise")
                }
                .disabled(
                    viewModel.isRestarting || viewModel.isInitializing
                    || viewModel.llm == nil
                )
            }
        }
    }
}
