//
//  ParameterSettingView.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

/// View for managing LLM model parameters and application settings.
struct ParameterSettingView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isShowingResetConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                modelLicenseSection
                modelSelectionSection
                parametersSection
                conversationActionsSection
                otherActionsSection
                debugModeSection
            }
            .navigationTitle("Settings & Actions")
        }
        .alert(
            StringConstants.deleteModelTitle,
            isPresented: $viewModel.showDeleteConfirmation,
            presenting: viewModel.modelToDelete
        ) { modelToDelete in
            // Presenting the model directly to the alert closure
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteCustomModel(modelToDelete)
            }
        } message: { modelToDelete in
            Text(
                StringConstants.deleteModelMessage(
                    for: modelToDelete.displayName
                )
            )
        }
        .alert(
            StringConstants.emergencyResetTitle,
            isPresented: $isShowingResetConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Application", role: .destructive) {
                viewModel.emergencyReset()
            }
        } message: {
            Text(StringConstants.emergencyResetMessage)
        }
    }
    
    private var modelLicenseSection: some View {
        Section(header: Text("Model Licenses")) {
            VStack(alignment: .leading) {
                Text("Bundled Model").font(.headline)
                Text(
                    "Llama 3.2 3B: © Meta AI, licensed under the Llama 3 Community License"
                )
                .font(.caption)
                .padding(.bottom, 4)
            }
            .padding(.vertical, 8)
        }
    }
    
    private var modelSelectionSection: some View {
        Group {
            let bundled = viewModel.models.filter { !$0.isUserAdded }
            let custom = viewModel.models.filter { $0.isUserAdded }
            
            if !bundled.isEmpty {
                Section(header: Text("Built-in Model")) {
                    ForEach(bundled) { model in
                        modelButton(for: model)
                    }
                }
            }
            
            if !custom.isEmpty {
                Section(header: Text("Custom Models")) {
                    ForEach(custom) { model in
                        modelButton(for: model)
                            .contextMenu {  // Context menu for deleting custom models
                                Button(role: .destructive) {
                                    viewModel.modelToDelete = model
                                    viewModel.showDeleteConfirmation = true
                                } label: {
                                    Label("Delete Model", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            
            Section(header: Text("Add Custom Model")) {
                Button {
                    viewModel.isShowingDocumentPicker = true
                } label: {
                    Label(
                        "Select GGUF Model File",
                        systemImage: "plus.circle.fill"
                    )
                }
                .disabled(
                    viewModel.isGenerating || viewModel.isRestarting
                    || viewModel.isInitializing
                )
            }
        }
    }
    
    @ViewBuilder
    private func modelButton(for model: ModelConfig) -> some View {
        Button(action: {
            if viewModel.selectedModel?.id != model.id {
                viewModel.switchModel(to: model)
            }
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(model.displayName).foregroundColor(.primary)
                    if let templateType = model.templateType, model.isUserAdded
                    {
                        Text("Template: \(templateType.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if !model.isUserAdded {
                        Text(
                            "Template: \(model.templateType?.rawValue ?? "Default")"
                        )  // Show for bundled too
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if model.id == viewModel.selectedModel?.id {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
        .disabled(
            viewModel.isGenerating || viewModel.isRestarting
            || viewModel.isInitializing
            || model.id == viewModel.selectedModel?.id
        )
    }
    
    private var parametersSection: some View {
        Section(header: Text("Model Parameters")) {
            temperatureSection
            topKSection
            topPSection
            maxTokensSection
        }
    }
    
    private var temperatureSection: some View {
        VStack(alignment: .leading) {
            Text(
                "Temperature (Randomness): \(String(format: "%.2f", viewModel.modelParameters.temperature))"
            )
            .font(.subheadline)
            parameterSlider(
                value: Binding(
                    get: { Double(viewModel.modelParameters.temperature) },
                    set: { viewModel.modelParameters.temperature = Float($0) }
                ),
                range: 0.0...2.0,
                step: 0.01,
                minLabel: "0.0",
                maxLabel: "2.0"
            )
        }
        .padding(.vertical, DesignConstants.smallPadding)
    }
    
    private var topKSection: some View {
        VStack(alignment: .leading) {
            Text("Top K (Sampling): \(Int(viewModel.modelParameters.topK))")
                .font(.subheadline)
            parameterSlider(
                value: Binding(
                    get: { Double(viewModel.modelParameters.topK) },
                    set: { viewModel.modelParameters.topK = Int32($0) }
                ),
                range: 1...100,
                step: 1,
                minLabel: "1",
                maxLabel: "100"
            )
        }
        .padding(.vertical, DesignConstants.smallPadding)
    }
    
    private var topPSection: some View {
        VStack(alignment: .leading) {
            Text(
                "Top P (Nucleus Sampling): \(String(format: "%.2f", viewModel.modelParameters.topP))"
            )
            .font(.subheadline)
            parameterSlider(
                value: Binding(
                    get: { Double(viewModel.modelParameters.topP) },
                    set: { viewModel.modelParameters.topP = Float($0) }
                ),
                range: 0.0...1.0,
                step: 0.01,
                minLabel: "0.0",
                maxLabel: "1.0"
            )
        }
        .padding(.vertical, DesignConstants.smallPadding)
    }
    
    private var maxTokensSection: some View {
        VStack(alignment: .leading) {
            Text(
                "Context Window (Max Tokens): \(Int(viewModel.modelParameters.maxTokens))"
            )
            .font(.subheadline)
            // Stepper might be better for large range like this, or a TextField
            HStack {
                Text("1024").font(.caption)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.modelParameters.maxTokens) },
                        set: { viewModel.modelParameters.maxTokens = Int32($0) }
                    ),
                    in: 1024...16384,
                    step: 512
                )
                .disabled(
                    viewModel.isRestarting || viewModel.isGenerating
                    || viewModel.isInitializing || viewModel.llm == nil
                )
                Text("16384").font(.caption)
            }
            Text("Note: Affects context capacity. Apply to take effect.")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, DesignConstants.smallPadding)
    }
    
    private var otherActionsSection: some View {
        Section(header: Text("Other Actions")) {
            Button("Restart LLM") { viewModel.restart() }
                .disabled(
                    viewModel.isGenerating || viewModel.isRestarting
                    || viewModel.isInitializing || viewModel.llm == nil
                )
            
            Button("Emergency Reset", role: .destructive) {
                isShowingResetConfirmation = true
            }
            .disabled(viewModel.isInitializing)  // Disable only if in full app init
        }
    }
    
    private var conversationActionsSection: some View {
        Section(header: Text("Conversation Actions")) {
            Button(role: .destructive) {
                viewModel.clearChat()
            } label: {
                Text("Clear Conversation")
            }
            .disabled(
                viewModel.messages.isEmpty || viewModel.isGenerating
                || viewModel.isRestarting || viewModel.isInitializing
            )
            
            Button(role: .destructive) {
                viewModel.removeLastExchange()
            } label: {
                Text("Remove Last Exchange")
            }
            .disabled(
                viewModel.messages.count < 2 || viewModel.isGenerating
                || viewModel.isRestarting || viewModel.isInitializing
            )
        }
    }
    
    private var debugModeSection: some View {
        Section(header: Text("Debug Mode")) {
            Toggle(
                "Enable Debug Logging",
                isOn: $viewModel.debugModeEnabled.animation()
            )
            .onChange(of: viewModel.debugModeEnabled) { _, newValue in
                viewModel.logDebug(
                    "--- Debug mode \(newValue ? "enabled" : "disabled") by user (Settings View) ---"
                )
            }
        }
    }
    
    @ViewBuilder
    private func parameterSlider(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        minLabel: String,
        maxLabel: String
    ) -> some View {
        Slider(value: value, in: range, step: step) {
            Text("Parameter Value")  // Accessibility label for the slider itself
        } minimumValueLabel: {
            Text(minLabel).font(.caption)
        } maximumValueLabel: {
            Text(maxLabel).font(.caption)
        }
        .disabled(
            viewModel.isRestarting || viewModel.isGenerating
            || viewModel.isInitializing || viewModel.llm == nil
        )
    }
}
