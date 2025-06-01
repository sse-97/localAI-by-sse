//
//  ChatViewModel+ErrorHandling.swift
//  localAI by sse
//
//  Created by sse-97 on 01.06.25.
//

import Foundation
import SwiftUI

// MARK: - ChatViewModel Error Handling Extension

extension ChatViewModel {
    
    // MARK: - Centralized Error Handling
    
    /// Handles an error using the centralized error management system
    func handleError(_ error: AppError) {
        Task { @MainActor in
            ErrorManager.shared.handle(error)
        }
        
        // Update UI state based on error type and severity
        updateUIForError(error)
        
        // Set error for UI display based on severity
        Task { @MainActor in
            switch error.severity {
            case .critical:
                self.currentError = error
            case .high:
                self.currentError = error
            case .medium:
                self.bannerError = error
            case .low:
                self.bannerError = error
            }
        }
    }
    
    /// Handles an error and shows an alert to the user
    func handleErrorWithAlert(_ error: AppError) {
        Task { @MainActor in
            let alert = ErrorManager.shared.handleWithAlert(error)
            self.userAlert = alert
            
            // Also set for enhanced error UI if needed
            if error.severity == .critical || error.severity == .high {
                self.currentError = error
            }
        }
    }
    
    /// Shows a success message to the user through the centralized system
    func showSuccessAlert(title: String, message: String) {
        Task { @MainActor in
            self.userAlert = ErrorManager.shared.createSuccessAlert(title: title, message: message)
        }
    }
    
    /// Creates and handles a model loading error
    func handleModelLoadingError(_ error: ModelLoadingError) {
        let appError = AppError.modelLoading(error)
        handleErrorWithAlert(appError)
    }
    
    /// Creates and handles a file system error
    func handleFileSystemError(_ error: FileSystemError) {
        let appError = AppError.fileSystem(error)
        handleErrorWithAlert(appError)
    }
    
    /// Creates and handles an LLM interaction error
    func handleLLMInteractionError(_ error: LLMInteractionError) {
        let appError = AppError.llmInteraction(error)
        handleErrorWithAlert(appError)
    }
    
    /// Creates and handles a validation error
    func handleValidationError(_ error: ValidationError) {
        let appError = AppError.validation(error)
        handleErrorWithAlert(appError)
    }
    
    /// Creates and handles a system error
    func handleSystemError(_ error: SystemError) {
        let appError = AppError.system(error)
        handleErrorWithAlert(appError)
    }
    
    // MARK: - UI State Updates
    
    private func updateUIForError(_ error: AppError) {
        switch error {
        case .modelLoading:
            // Reset model-related state
            if isInitializing {
                isInitializing = false
            }
            if isRestarting {
                isRestarting = false
            }
            llm = nil
            modelInfo = error.errorDescription ?? "Model loading failed"
            
        case .fileSystem:
            // Clean up file-related state
            cleanupTemporaryFile()
            if isShowingModelConfigSheet {
                isShowingModelConfigSheet = false
            }
            
        case .llmInteraction:
            // Handle generation state
            if isGenerating {
                isGenerating = false
            }
            
        case .userInterface:
            // Handle UI state issues
            break
            
        case .system:
            // Handle system-level issues
            break
            
        case .validation:
            // Handle validation issues
            break
            
        case .network:
            // Handle network issues
            break
        }
    }
    
    // MARK: - Error Recovery Actions
    
    /// Attempts to recover from an error based on the suggested recovery action
    func attemptErrorRecovery(for error: AppError) {
        guard let recoveryAction = ErrorManager.shared.suggestRecoveryAction(for: error) else {
            logDebug("--- No recovery action available for error: \(error.id) ---")
            return
        }
        
        logDebug("--- Attempting recovery action: \(recoveryAction.title) for error: \(error.id) ---")
        
        switch recoveryAction {
        case .retry:
            handleRetryAction(for: error)
        case .restart:
            handleRestartAction()
        case .clearData:
            handleClearDataAction(for: error)
        case .switchModel:
            handleSwitchModelAction()
        case .freeMemory:
            handleFreeMemoryAction()
        case .checkPermissions:
            handleCheckPermissionsAction()
        case .contactSupport:
            handleContactSupportAction()
        case .updateOS:
            handleUpdateOSAction()
        case .none:
            break
        }
    }
    
    // MARK: - Recovery Action Handlers
    
    private func handleRetryAction(for error: AppError) {
        switch error {
        case .modelLoading:
            // Retry loading the current model
            if let model = selectedModel {
                loadActiveModel(modelConfig: model, initialLoad: false)
            }
            
        case .fileSystem(let fileError):
            switch fileError {
            case .copyFailed, .deleteFailed, .temporaryFileCreationFailed, .documentPickerFailed:
                // These would typically be handled by user re-triggering the action
                break
            default:
                break
            }
            
        case .llmInteraction(let llmError):
            switch llmError {
            case .generationFailed, .stopFailed, .parametersUpdateFailed:
                // These would be handled when user tries the action again
                break
            default:
                break
            }
            
        default:
            break
        }
    }
    
    private func handleRestartAction() {
        restart()
    }
    
    private func handleClearDataAction(for error: AppError) {
        switch error {
        case .llmInteraction(let llmError):
            switch llmError {
            case .contextOverflow, .historyCorrupted:
                clearChat()
            default:
                break
            }
        case .fileSystem(let fileError):
            switch fileError {
            case .diskSpaceInsufficient:
                // Could suggest clearing chat history or temporary files
                clearChat()
                cleanupTemporaryFile()
            default:
                break
            }
        default:
            break
        }
    }
    
    private func handleSwitchModelAction() {
        // Switch to the first available bundled model
        if let bundledModel = models.first(where: { !$0.isUserAdded }) {
            switchModel(to: bundledModel)
        }
    }
    
    private func handleFreeMemoryAction() {
        // Clear non-essential data to free memory
        clearChat()
        
        // Reset debug info if it's large
        if debugInfo.count > 10000 {
            clearDebugInfo()
        }
        
        // Force garbage collection
        // Note: This is a suggestion to the system, not guaranteed
        autoreleasepool {
            // Any temporary objects created here will be released
        }
    }
    
    private func handleCheckPermissionsAction() {
        // Open app settings
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func handleContactSupportAction() {
        // This could open GitHub issues page or email
        if let githubUrl = URL(string: "https://github.com/sse-97/localAI-by-sse/issues") {
            UIApplication.shared.open(githubUrl)
        }
    }
    
    private func handleUpdateOSAction() {
        // Open iOS update settings
        if let settingsUrl = URL(string: "App-prefs:General&path=SOFTWARE_UPDATE_LINK") {
            UIApplication.shared.open(settingsUrl)
        } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Error Context Helpers
    
    /// Provides additional context for error logging
    func getErrorContext() -> [String: String] {
        var context: [String: String] = [:]
        
        context["selectedModel"] = selectedModel?.displayName ?? "None"
        context["isGenerating"] = String(isGenerating)
        context["isRestarting"] = String(isRestarting)
        context["isInitializing"] = String(isInitializing)
        context["messageCount"] = String(messages.count)
        context["tokenCount"] = String(tokenCount)
        context["contextUsage"] = String(contextUsage)
        context["availableModels"] = String(models.count)
        context["debugModeEnabled"] = String(debugModeEnabled)
        
        return context
    }
    
    // MARK: - Recovery Action Execution
    
    /// Executes a recovery action and updates error state
    func executeRecoveryAction(_ action: RecoveryAction) {
        logDebug("--- Executing recovery action: \(action.title) ---")
        
        // Clear current error states
        clearCurrentError()
        clearBannerError()
        
        // Execute the specific recovery action
        switch action {
        case .retry:
            if let model = selectedModel {
                loadActiveModel(modelConfig: model, initialLoad: false)
            }
        case .restart:
            handleRestartAction()
        case .clearData:
            handleClearDataAction(for: currentError ?? AppError.system(.backgroundTaskFailed(task: "clearData")))
        case .switchModel:
            handleSwitchModelAction()
        case .freeMemory:
            handleFreeMemoryAction()
        case .checkPermissions:
            handleCheckPermissionsAction()
        case .contactSupport:
            handleContactSupportAction()
        case .updateOS:
            handleUpdateOSAction()
        case .none:
            break
        }
    }
}

// MARK: - Error Handling View Extension

extension View {
    /// Modifier to handle errors consistently across the app
    func errorHandling() -> some View {
        self.onReceive(ErrorManager.shared.$currentError) { error in
            if let error = error {
                print("Error received in view: \(error.errorDescription ?? "Unknown")")
            }
        }
    }
    
    /// Modifier to show error alerts with recovery actions
    func errorAlert(isPresented: Binding<Bool>, error: AppError?, onRecovery: @escaping (RecoveryAction) -> Void) -> some View {
        self.alert(
            error?.errorDescription ?? "Unknown Error",
            isPresented: isPresented
        ) {
            if let error = error,
               let recoveryAction = ErrorManager.shared.suggestRecoveryAction(for: error),
               recoveryAction != .none {
                Button(recoveryAction.title) {
                    onRecovery(recoveryAction)
                }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("OK") { }
            }
        } message: {
            if let error = error {
                Text(error.recoverySuggestion ?? "Please try again.")
            }
        }
    }
}
