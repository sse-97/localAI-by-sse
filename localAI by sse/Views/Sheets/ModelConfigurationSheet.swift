//
//  ModelConfigurationSheet.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import SwiftUI

// MARK: - Custom Model Configuration Sheet

/// Sheet for configuring a custom model after file selection
struct ModelConfigurationSheet: View {
    let temporaryFileURL: URL
    let originalFilename: String
    let onComplete: (ModelConfig, TemplateType, String) -> Void  // Pass back templateType and systemPrompt
    let onCancel: () -> Void
    
    @State private var displayName: String
    @State private var selectedTemplate: TemplateType = .llama3  // Default template
    @State private var systemPrompt: String = StringConstants.defaultSystemPrompt
    @State private var showAdvancedOptions: Bool = false  // Not currently used, but kept for potential future use
    
    init(
        temporaryFileURL: URL,
        originalFilename: String,
        onComplete: @escaping (ModelConfig, TemplateType, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.temporaryFileURL = temporaryFileURL
        self.originalFilename = originalFilename
        self.onComplete = onComplete
        self.onCancel = onCancel
        
        // Generate a display name from original filename
        let defaultDisplayName = URL(fileURLWithPath: originalFilename)
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        _displayName = State(
            initialValue: defaultDisplayName.isEmpty ? "My Custom Model" : defaultDisplayName
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Configuration")) {
                    TextField("Display Name", text: $displayName)
                    Text("Original Filename: \(originalFilename)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Template", selection: $selectedTemplate) {
                        ForEach(TemplateType.allCases) { template in
                            Text(template.rawValue).tag(template)
                        }
                    }
                    
                    Text(selectedTemplate.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("System Prompt (Optional)")) {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    
                    HStack {
                        Spacer()
                        Button("Reset to Default") {
                            systemPrompt = StringConstants.defaultSystemPrompt
                        }
                        .font(.caption)
                        Spacer()
                    }
                }
                
                Section {
                    Button("Add Model") {
                        let finalSystemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        let template = selectedTemplate.createTemplate(
                            finalSystemPrompt.isEmpty ? nil : finalSystemPrompt
                        )
                        let modelConfigIntent = ModelConfig(
                            name: displayName.isEmpty ? "Custom Model" : displayName,
                            filename: originalFilename,
                            template: template,
                            displayName: displayName.isEmpty ? "Custom Model" : displayName,
                            isUserAdded: true,
                            fileURL: temporaryFileURL,
                            templateType: selectedTemplate,
                            systemPromptForTemplate: finalSystemPrompt
                        )
                        onComplete(modelConfigIntent, selectedTemplate, finalSystemPrompt)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    
                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(StringConstants.modelConfigSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
