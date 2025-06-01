//
//  ChatViewModel+LLMInteraction.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import Combine
import Foundation
import LLM
import SwiftUI

// MARK: - ChatViewModel: LLM Interaction & State
extension ChatViewModel {
    /// Loads or reloads the specified LLM. Handles UI state for initialization or restarting.
    func loadActiveModel(modelConfig: ModelConfig?, initialLoad: Bool = false) {
        // Set UI state: initializing for first load, restarting for subsequent loads/switches.
        Task { @MainActor in
            if initialLoad {
                if !self.isInitializing { self.isInitializing = true }  // Ensure it's true
                self.isRestarting = false  // Not restarting if it's an initial load
            } else {
                self.isRestarting = true
                self.isInitializing = false  // Not initializing if it's a restart/switch
            }
            // Clear previous model info immediately for better UX
            self.modelInfo = "Loading \(modelConfig?.displayName ?? "model")..."
            self.llm = nil  // Explicitly nil out old LLM instance
            self.llmEventCancellable?.cancel()  // Cancel any existing subscriptions
            self.llmEventCancellable = nil
        }
        
        guard
            let modelToLoad = modelConfig ?? selectedModel ?? availableModels.first
        else {
            Task { @MainActor in
                self.modelInfo = "Error: No model available to load."
                self.llm = nil
                if initialLoad { self.isInitializing = false }
                self.isRestarting = false;            logDebug(
                "--- Critical Error: No model configuration available to load. ---"
            )
            self.handleModelLoadingError(.fileNotFound(filename: "selectedModel"))
            }
            return
        }
        
        // Update selectedModel if it's different or not set
        if self.selectedModel?.id != modelToLoad.id {
            Task { @MainActor in self.selectedModel = modelToLoad }
        }
        
        logDebug(
            "--- Attempting to load model: \(modelToLoad.displayName) (Filename: \(modelToLoad.filename)) ---"
        )
        
        let modelFileFinalURL: URL?
        if modelToLoad.isUserAdded, let userFileURL = modelToLoad.fileURL {
            modelFileFinalURL = userFileURL
            logDebug("--- Loading user model from: \(userFileURL.path) ---")
        } else {
            // Bundled model: construct URL from Bundle.main
            let filenameWithoutExtension = URL(
                fileURLWithPath: modelToLoad.filename
            ).deletingPathExtension().lastPathComponent
            let fileExtension = URL(fileURLWithPath: modelToLoad.filename).pathExtension
            // Bundled models should always have .gguf, but this is defensive.
            let extToUse = fileExtension.isEmpty ? "gguf" : fileExtension
            
            modelFileFinalURL = Bundle.main.url(
                forResource: filenameWithoutExtension,
                withExtension: extToUse
            )
            logDebug(
                "--- Loading bundled model: \(modelToLoad.filename) (Resolved as: \(filenameWithoutExtension).\(extToUse)) ---"
            )
        }
        
        guard let validModelUrl = modelFileFinalURL else {
            Task { @MainActor in
                self.modelInfo = "Failed to construct URL for \(modelToLoad.displayName)."
                self.llm = nil
                if initialLoad { self.isInitializing = false }
                self.isRestarting = false;            logDebug(
                "--- Model URL could not be constructed for \(modelToLoad.displayName). ---"
            )
            self.handleModelLoadingError(.urlConstructionFailed(filename: modelToLoad.displayName))
            }
            return
        }
        
        guard FileManager.default.fileExists(atPath: validModelUrl.path) else {
            Task { @MainActor in
                self.modelInfo = "Model file not found for \(modelToLoad.displayName) at \(validModelUrl.path)."
                self.llm = nil
                if initialLoad { self.isInitializing = false }
                self.isRestarting = false
                logDebug(
                    "--- Model file does not exist at path: \(validModelUrl.path) for \(modelToLoad.displayName). ---"
                )
                self.handleFileSystemError(.pathDoesNotExist(path: validModelUrl.path))
            }
            return
        }
        
        // Perform LLM initialization on a background thread
        Task.detached(priority: .userInitiated) {
            // Brief pause: This can sometimes help if the LLM library needs a moment
            // to release resources from a previous instance, especially if deinit is async.
            // Ideally, the LLM library would provide a synchronous deinit or a completion handler.
            if !initialLoad {
                self.logDebug(
                    "--- Brief pause before re-initializing LLM to allow resource cleanup. ---"
                )
                try? await Task.sleep(for: .milliseconds(200))  // Slightly increased for safety
            }
            
            // Ensure template is correctly using the specific system prompt for this model
            let templateForLLM: Template
            if let type = modelToLoad.templateType,
               let prompt = modelToLoad.systemPromptForTemplate
            {
                templateForLLM = type.createTemplate(
                    prompt.isEmpty ? nil : prompt
                )
            } else {  // Fallback for older bundled configs or if somehow nil
                templateForLLM = modelToLoad.template
            }
            self.logDebug(
                "--- Initializing LLM with template: \(templateForLLM.systemPrompt ?? "Default System Prompt") ---"
            )
            
            let newLlm = LLM(from: validModelUrl, template: templateForLLM)  // Use the specifically prepared template
            
            // Switch back to main actor to update UI and state
            await MainActor.run {
                self.llm = newLlm
                if let unwrappedLlm = self.llm {
                    self.modelInfo = modelToLoad.displayName  // Display name of the loaded model
                    // Apply current modelParameters to the new LLM instance
                    unwrappedLlm.temp = self.modelParameters.temperature
                    unwrappedLlm.topK = self.modelParameters.topK
                    unwrappedLlm.topP = self.modelParameters.topP
                    // Max tokens (context window) might be part of LLM init or a property to set.
                    // If LLM.maxTokens is settable: unwrappedLlm.maxTokens = self.modelParameters.maxTokens
                    // Otherwise, modelParameters.maxTokens is for UI display and context calculation.
                    
                    self.setupLLMObservers()
                    self.logDebug(
                        "--- Model loaded successfully: \(modelToLoad.displayName) from \(validModelUrl.path) ---"
                    )
                } else {
                    self.modelInfo = "Failed to initialize \(modelToLoad.displayName)."
                    self.logDebug(
                        "--- LLM initialization failed for: \(modelToLoad.displayName) from \(validModelUrl.path). Check LLM library logs. ---"
                    )
                    self.handleModelLoadingError(.initializationFailed(reason: "Failed to load model \(modelToLoad.displayName)"))
                }
                self.refreshContextMetrics()  // Update context metrics based on the new/failed model
                
                if initialLoad { self.isInitializing = false }
                self.isRestarting = false
            }
        }
    }
    
    func refreshContextMetrics() {
        guard let llm = llm else {
            // If LLM is nil, reset metrics
            Task { @MainActor in
                self.tokenCount = 0
                self.contextUsage = 0
                // memoryUsage is device memory, so it's always relevant
                let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
                self.memoryUsage = Double(physicalMemoryBytes) / (1024.0 * 1024.0 * 1024.0)  // GB
            }
            return
        }
        
        Task.detached(priority: .utility) {
            let historyText = llm.history.map { $0.content }.joined(separator: " ")
            let tokens = await llm.encode(historyText)  // Assuming llm.encode is safe to call from background
            
            let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
            let deviceMemoryGB = Double(physicalMemoryBytes) / (1024.0 * 1024.0 * 1024.0)
            
            await MainActor.run {
                self.tokenCount = tokens.count
                // Ensure maxTokens is not zero to avoid division by zero
                let maxContextTokens = Double(self.modelParameters.maxTokens) > 0 ? Double(self.modelParameters.maxTokens) : 8192.0
                self.contextUsage = Double(tokens.count) / maxContextTokens
                self.memoryUsage = deviceMemoryGB
            }
        }
    }
    
    func updateModelParameters() {
        guard let llm = llm else {
            logDebug("--- Attempted to update parameters but LLM is nil. ---")
            handleLLMInteractionError(.modelNotReady)
            return
        }
        llm.temp = self.modelParameters.temperature
        llm.topK = self.modelParameters.topK
        llm.topP = self.modelParameters.topP
        // If LLM.maxTokens is a settable property for context window:
        // llm.maxTokens = self.modelParameters.maxTokens
        // This would also require re-evaluating context or potentially restarting.
        // For now, modelParameters.maxTokens is mainly for UI and context calculation.
        
        logDebug(
            "--- Model parameters applied: Temp=\(llm.temp), TopK=\(llm.topK), TopP=\(llm.topP), MaxTokens (UI)=\(self.modelParameters.maxTokens) ---"
        )
        
        Task { @MainActor in
            // Use centralized success message handling
            self.showSuccessAlert(
                title: "Parameters Updated",
                message: "LLM parameters have been applied."
            )
            self.refreshContextMetrics()  // Refresh metrics as maxTokens might have changed for UI
        }
    }
    
    func sendMessage(text input: String) async {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let llm = llm, !trimmedInput.isEmpty, !isGenerating,
              !isRestarting, !isInitializing
        else {
            if trimmedInput.isEmpty {
                logDebug("--- Attempted to send empty message ---")
                handleValidationError(.emptyInput(field: "message"))
            }
            if llm == nil {
                logDebug("--- Attempted to send message but LLM is nil. ---")
                handleLLMInteractionError(.modelNotReady)
            }
            if isGenerating {
                logDebug("--- Attempted to send message while already generating. ---")
                handleValidationError(.invalidFormat(field: "action", expected: "Send message when not generating"))
            }
            return
        }
        
        await MainActor.run {
            self.messages.append(Message(content: trimmedInput, isUser: true))
            self.messages.append(Message(content: "", isUser: false))  // Placeholder for AI response
            self.isGenerating = true
            self.generationStartTime = Date()
            self.generatedTokens = 0  // Reset for new generation
            logDebug(
                "--- Starting generation for: \"\(trimmedInput.prefix(100))\(trimmedInput.count > 100 ? "..." : "")\" ---"
            )
        }
        
        // This is an async call to the LLM library
        await llm.respond(to: trimmedInput)
        
        // This block might be reached if llm.respond finishes without triggering the 'nil' delta in the update handler
        // (e.g., if the model outputs nothing or an error occurs internally in the LLM library before streaming).
        await MainActor.run {
            if self.isGenerating {  // If still true, means the 'nil' delta didn't fire or generation was instant/empty
                self.isGenerating = false
                logDebug(
                    "--- Generation finished or stopped (sendMessage completion). Ensure LLM output was processed. ---"
                )
                // If the last AI message is still empty, it might indicate an issue.
                if self.messages.last?.isUser == false && self.messages.last?.content.isEmpty == true {
                    // Consider updating the empty AI message to an error or "No response"
                    // self.messages[self.messages.count - 1] = Message(content: "[No response from model]", isUser: false)
                    logDebug("--- Warning: AI response might be empty after generation. ---")
                }
            }
        }
        refreshContextMetrics()  // Refresh metrics after generation
    }
    
    func stop() {
        guard isGenerating else {
            logDebug("--- Stop called but not currently generating. ---")
            return
        }
        llm?.stop()  // Tell the LLM library to stop
        Task { @MainActor in
            // isGenerating should be set to false by the LLM's update handler when it receives nil (or stops)
            // However, as a fallback:
            if self.isGenerating {
                self.isGenerating = false
                logDebug("--- Generation stopped by user (stop() method). ---")
            }
        }
    }
    
    /// Restarts the currently selected LLM, clearing chat history.
    func restart() {
        guard !isRestarting, !isInitializing else {
            logDebug("--- Restart called while already restarting or initializing. Ignoring. ---")
            return
        }
        if isGenerating { stop() }  // Stop any ongoing generation
        
        Task { @MainActor in
            self.isRestarting = true  // Set restarting flag
            logDebug("--- LLM restart initiated for model: \(selectedModel?.displayName ?? "Unknown") ---")
            self.messages = []  // Clear chat history immediately for UI responsiveness
            logDebug("--- Chat history cleared for restart. ---")
        }
        
        // Reload the *current* selected model.
        // The loadActiveModel function handles the actual LLM re-initialization.
        let currentModelConfig = selectedModel
        loadActiveModel(modelConfig: currentModelConfig, initialLoad: false)
    }
    
    /// Switches to a new model, clears chat history, and loads the new model.
    func switchModel(to modelConfig: ModelConfig) {
        guard modelConfig.id != selectedModel?.id else {
            logDebug("--- Attempted to switch to the already selected model: \(modelConfig.displayName). Ignoring. ---")
            return
        }
        guard !isGenerating, !isRestarting, !isInitializing else {
            logDebug("--- Model switch attempted during generation, restart, or initialization. Ignoring. ---")
            handleValidationError(.invalidFormat(field: "action", expected: "Model switch when not busy"))
            return
        }
        if isGenerating { stop() }  // Stop any ongoing generation
        
        Task { @MainActor in
            self.isRestarting = true  // Use isRestarting to indicate model loading activity
            logDebug("--- Model switch initiated to: \(modelConfig.displayName) ---")
            self.messages = []  // Clear chat history
            UserDefaults.standard.selectedModelFilename = modelConfig.filename  // Save preference
            logDebug("--- Model preference '\(modelConfig.filename)' saved for \(modelConfig.displayName). Chat cleared. ---")
            // selectedModel will be updated by loadActiveModel
        }
        
        loadActiveModel(modelConfig: modelConfig, initialLoad: false)  // `initialLoad: false` indicates it's a switch/restart
    }
    
    /// Resets the application to its initial state, deleting all user data.
    func emergencyReset() {
        guard !isInitializing else {  // Prevent reset if already in initial loading
            logDebug("--- Emergency Reset called while already initializing. Ignoring. ---")
            return
        }
        if isGenerating { stop() }  // Stop any ongoing generation
        
        Task { @MainActor in
            self.isInitializing = true  // Use isInitializing to show full loading screen
            self.isRestarting = false  // Not a simple restart
            self.debugInfo = "--- EMERGENCY RESET INITIATED ---\n"
            
            // Clear LLM instance and its handlers
            self.llmEventCancellable?.cancel()
            self.llmEventCancellable = nil
            self.llm?.update = { _ in }  // Dereference closure
            self.llm?.postprocess = { _ in }  // Dereference closure
            self.llm = nil
            logDebug("--- LLM instance and handlers cleared for emergency reset. ---")
            
            // Brief pause to allow any async operations from LLM deinit to settle (if any)
            // This is a precaution; ideally, LLM deinitialization is synchronous or awaitable.
            logDebug("--- Brief pause during emergency reset for resource cleanup. ---")
            try? await Task.sleep(for: .milliseconds(200))
            
            // Reset all relevant state properties
            self.messages = []
            self.modelParameters = .default
            self.copiedMessageId = nil
            self.cleanupTemporaryFile()  // Resets ViewModel state related to file picking
            self.modelToDelete = nil
            self.showDeleteConfirmation = false
            self.generationSpeed = 0
            self.generatedTokens = 0
            self.tokenCount = 0
            self.contextUsage = 0
            self.modelInfo = ""  // Clear model info
            
            // Delete all user-added model files
            let userModelConfigs = UserDefaults.standard.userModelConfigurations
            let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            for storedConfig in userModelConfigs {
                let fileURL = documentsDirectory.appendingPathComponent(storedConfig.filename)
                do {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        try FileManager.default.removeItem(at: fileURL)
                        logDebug("--- Deleted user model file: \(fileURL.path) during reset. ---")
                    }
                } catch {
                    logDebug("--- Failed to delete user model file \(fileURL.path) during reset: \(error.localizedDescription) ---")
                }
            }
            
            // Clear UserDefaults related to models
            UserDefaults.standard.userModelConfigurations = []
            UserDefaults.standard.selectedModelFilename = nil
            logDebug("--- Cleared user model configurations and selected model from UserDefaults. ---")
            
            // Reset available models to only bundled ones
            self.availableModels = self.bundledModels
            self.selectedModel = self.bundledModels.first  // Select the first bundled model as default
            
            if let defaultModel = self.selectedModel {
                UserDefaults.standard.selectedModelFilename = defaultModel.filename
                logDebug("--- Default model set to: \(defaultModel.displayName) after reset. Proceeding to load. ---")
                // `isInitializing` is already true, so loadActiveModel will show the initial loading view.
                self.loadActiveModel(modelConfig: defaultModel, initialLoad: true)
            } else {
                logDebug("--- CRITICAL: No bundled models found after reset. This indicates a problem with `bundledModels` definition. ---")
                self.modelInfo = "Error: No default model available after reset."
                self.isInitializing = false  // Allow UI to show an error state if needed
            }
            // Use centralized success message handling
            self.showSuccessAlert(
                title: "Reset Complete",
                message: "Application has been reset to its initial state."
            )
        }
    }
    
    func clearChat() {
        guard !isGenerating, !isRestarting, !isInitializing else { return }
        messages = []
        llm?.history = []  // Clear LLM's internal history
        refreshContextMetrics()
        logDebug("--- Chat cleared by user ---")
    }
    
    func removeLastExchange() {
        guard !isGenerating, !isRestarting, !isInitializing else { return }
        guard (llm?.history.count ?? 0) >= 2 else {
            logDebug("--- Not enough history to remove last exchange. ---")
            return
        }
        
        llm?.history.removeLast(2)  // Remove user and bot message from LLM history
        if messages.count >= 2 {
            messages.removeLast(2)  // Remove from UI
        }
        refreshContextMetrics()
        logDebug("--- Last exchange (user + bot) removed ---")
    }
    
    func copyToClipboard(_ text: String, messageId: UUID? = nil) {
        UIPasteboard.general.string = text
        copyConfirmationTask?.cancel()  // Cancel any existing confirmation task
        
        if let id = messageId {
            Task { @MainActor in
                self.copiedMessageId = id
                logDebug("--- Copied to clipboard (Message ID: \(id)): \"\(text.prefix(50))\(text.count > 50 ? "..." : "")\" ---")
            }
            copyConfirmationTask = Task {
                do {
                    try await Task.sleep(for: .seconds(2))
                    await MainActor.run {
                        // Only clear if it's still the same message ID (user hasn't copied another one quickly)
                        if self.copiedMessageId == id {
                            self.copiedMessageId = nil
                        }
                    }
                } catch is CancellationError {
                    // This is expected if the task is cancelled (e.g., user copies another message)
                    logDebug("--- Copy confirmation task cancelled for message ID: \(id). ---")
                } catch {
                    logDebug("--- Copy confirmation task failed for message ID \(id): \(error.localizedDescription) ---")
                }
            }
        } else {
            // For general copies (e.g., debug log) without a message ID
            logDebug("--- Copied to clipboard (General): \"\(text.prefix(50))\(text.count > 50 ? "..." : "")\" ---")
            // Optionally show a generic "Copied!" alert if needed for these cases
            // self.userAlert = UserAlert(title: "Copied", message: "Content copied to clipboard.")
        }
    }
    
    func clearDebugInfo() {
        Task { @MainActor in
            self.debugInfo = "--- Debug log cleared by user. ---\n"
        }
    }
    
    private func setupLLMObservers() {
        guard let llm = llm else {
            logDebug("--- Attempted to setup LLM observers, but LLM instance is nil. ---")
            return
        }
        llmEventCancellable?.cancel()  // Cancel previous subscriptions
        
        // Sink to receive the full output string when it changes
        llmEventCancellable = llm.objectWillChange
            .receive(on: DispatchQueue.main)  // Ensure UI updates are on the main thread
            .sink { [weak self] _ in
                guard let self = self, let currentLlmOutput = self.llm?.output
                else { return }
                if let lastIndex = self.messages.indices.last,
                   !self.messages[lastIndex].isUser
                {
                    let existingId = self.messages[lastIndex].id
                    // To avoid performance issues with very frequent updates to large arrays,
                    // directly modify the last element if it's the AI's message.
                    // This assumes `messages` is not being rapidly replaced by other operations.
                    if self.messages[lastIndex].id == existingId {  // Check if it's still the same message
                        self.messages[lastIndex].content = currentLlmOutput
                    }
                }
            }
        
        // Closure for incremental updates (delta tokens)
        llm.update = { [weak self] deltaToken in
            Task { @MainActor in  // Ensure execution on main actor
                guard let self = self else { return }
                if deltaToken != nil {
                    self.generatedTokens += 1
                    // Calculate generation speed if startTime is set
                    if let startTime = self.generationStartTime {
                        let duration = Date().timeIntervalSince(startTime)
                        if duration > 0 {
                            self.generationSpeed = Double(self.generatedTokens) / duration
                        }
                    }
                } else {
                    // Nil deltaToken indicates end of stream
                    if self.isGenerating {  // Check if we were actually generating
                        self.isGenerating = false
                        self.logDebug("--- Generation stream ended (LLM update handler received nil delta). Final token count: \(self.generatedTokens) ---")
                        if let startTime = self.generationStartTime {
                            let duration = Date().timeIntervalSince(startTime)
                            if duration > 0 {  // Avoid division by zero
                                self.generationSpeed = Double(self.generatedTokens) / duration
                                self.logDebug(
                                    String(
                                        format: "--- Final generation speed: %.2f tokens/sec ---",
                                        self.generationSpeed
                                    )
                                )
                            }
                            self.generationStartTime = nil  // Reset start time
                        }
                        self.refreshContextMetrics()  // Refresh metrics after generation completes
                    }
                }
            }
        }
        
        // Optional: Hook into postprocessing if needed for logging or final adjustments
        let originalPostprocess = llm.postprocess
        llm.postprocess = { [weak self] finalOutput in
            originalPostprocess(finalOutput)  // Call original postprocessing
            Task { @MainActor in  // Ensure execution on main actor
                guard let self = self else { return }
                self.logDebug(
                    "Postprocess Output (\(finalOutput.count) chars): \"\(finalOutput.prefix(100).replacingOccurrences(of: "\n", with: "\\n"))\(finalOutput.count > 100 ? "..." : "")\""
                )
            }
        }
        logDebug("--- LLM observers set up successfully. ---")
    }
}
