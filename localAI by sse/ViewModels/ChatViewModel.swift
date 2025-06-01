//
//  ChatViewModel.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import Combine
import Foundation
import LLM
import SwiftUI

// MARK: - ViewModel
final class ChatViewModel: ObservableObject {
    // MARK: Published UI State Properties
    @Published var messages: [Message] = []
    @Published var isGenerating: Bool = false
    @Published var isRestarting: Bool = false  // Covers model switching and explicit restarts
    @Published var isInitializing: Bool = true  // Initial app launch loading
    @Published var contextUsage: Double = 0
    @Published var tokenCount: Int = 0
    @Published var modelInfo: String = ""
    @Published var generationSpeed: Double = 0
    @Published var memoryUsage: Double = 0  // This will represent total device memory
    @Published var generatedTokens: Int = 0
    @Published var modelParameters: ModelParameters = .default
    @Published var debugModeEnabled: Bool = false
    @Published var debugInfo: String = ""
    @Published var shouldAutoScrollDebug: Bool = true
    @Published var selectedModel: ModelConfig?
    @Published var copiedMessageId: UUID? = nil
    @Published var isShowingDocumentPicker: Bool = false
    @Published var modelToDelete: ModelConfig? = nil
    @Published var showDeleteConfirmation: Bool = false
    @Published var availableModels: [ModelConfig] = []
    @Published var userAlert: UserAlert? = nil
    @Published var isOSVersionIncompatible = false
    @Published var hasShownContentDisclaimer: Bool = UserDefaults.standard.bool(
        forKey: "hasShownContentDisclaimer"
    )
    
    // MARK: Custom Model Configuration State
    @Published var pickedTemporaryModelFileURL: URL? = nil
    @Published var originalPickedModelFilename: String? = nil
    @Published var isShowingModelConfigSheet: Bool = false
    @Published var isShowingPrivacyPolicy: Bool = false
    
    // MARK: Public Properties
    public var llm: LLM?
    
    // MARK: Internal Properties (accessible to extensions)
    internal var generationStartTime: Date?
    internal var llmEventCancellable: AnyCancellable?
    internal var copyConfirmationTask: Task<Void, Never>? = nil
    
    internal let bundledModels: [ModelConfig] = [
        ModelConfig(
            name: "Llama 3.2 3B Instruct Q4 K M",  // Technical name
            filename: "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
            template: .llama3(StringConstants.defaultSystemPrompt),
            displayName: "Llama 3.2 3B",
            isUserAdded: false,
            fileURL: nil,
            templateType: .llama3,  // For consistency, though not strictly needed for bundled
            systemPromptForTemplate: StringConstants.defaultSystemPrompt
        )
    ]
    
    // MARK: - Initialization
    init() {
        // Check OS version compatibility
        if #available(iOS 17.6, *) {
            // App is running on a compatible OS version
        } else {
            isOSVersionIncompatible = true
        }
        
        availableModels = bundledModels
        loadUserModelsFromUserDefaults()
        
        let savedModelFilename = UserDefaults.standard.selectedModelFilename
        if let filename = savedModelFilename,
           let savedModel = availableModels.first(where: {
               $0.filename == filename
           })
        {
            selectedModel = savedModel
            logDebug(
                "--- Loaded previously selected model: \(savedModel.displayName) ---"
            )
        } else {
            selectedModel = availableModels.first  // Default to the first available model (bundled or user)
            if let firstModel = selectedModel {
                UserDefaults.standard.selectedModelFilename = firstModel.filename
                logDebug("--- Default model selected: \(firstModel.displayName) ---")
            }
        }
        // Initial load of the selected (or default) model
        loadActiveModel(modelConfig: selectedModel, initialLoad: true)
    }
    
    // MARK: - Debug Logging Helper
    func logDebug(_ message: String) {
        // Ensure thread safety for debugInfo updates, though @MainActor on the property helps
        Task { @MainActor in
            if self.debugModeEnabled {  // Check again inside Task in case it changed
                let timestamp = DateFormatter.localizedString(
                    from: Date(),
                    dateStyle: .none,
                    timeStyle: .medium
                )
                self.debugInfo += "[\(timestamp)] \(message)\n"
            }
        }
    }
    
    /// Computed property for sorted models: bundled first, then user-added, both sorted by display name.
    var models: [ModelConfig] {
        availableModels.sorted {
            if !$0.isUserAdded && $1.isUserAdded { return true }  // Bundled before user-added
            if $0.isUserAdded && !$1.isUserAdded { return false }  // User-added after bundled
            return $0.displayName.localizedCaseInsensitiveCompare(
                $1.displayName
            ) == .orderedAscending  // Sort by name
        }
    }
}
