//
//  ChatViewModel+ModelManagement.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import Foundation
import UIKit

// MARK: - ChatViewModel: Custom Model Management
extension ChatViewModel {
    /// Loads user-added model configurations from persisted `StoredUserModel` data.
    func loadUserModelsFromUserDefaults() {
        let storedUserModels = UserDefaults.standard.userModelConfigurations
        var validUserModels: [StoredUserModel] = []  // To store models that still exist
        
        for storedModel in storedUserModels {
            let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            let fileURL = documentsDirectory.appendingPathComponent(
                storedModel.filename
            )
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                guard let templateType = storedModel.templateType else {
                    logDebug("--- Warning: Invalid template type for stored model \(storedModel.filename), skipping. ---")
                    continue
                }
                let template = templateType.createTemplate(
                    storedModel.systemPrompt
                )
                
                let userModelConfig = ModelConfig(
                    name: storedModel.displayName,
                    filename: storedModel.filename,
                    template: template,
                    displayName: storedModel.displayName,
                    isUserAdded: true,
                    fileURL: fileURL,
                    templateType: templateType,
                    systemPromptForTemplate: storedModel.systemPrompt
                )
                
                // Avoid duplicates if already loaded (e.g., during app lifecycle without full restart)
                if !availableModels.contains(where: {
                    $0.fileURL?.path == fileURL.path
                }) {
                    availableModels.append(userModelConfig)
                }
                validUserModels.append(storedModel)
            } else {
                logDebug(
                    "--- User model file missing: \(storedModel.filename) at expected path \(fileURL.path). Removing from configurations. ---"
                )
                // This model will be excluded when `validUserModels` is saved back.
            }
        }
        
        // If any models were found to be missing, update UserDefaults to only contain valid ones.
        if validUserModels.count != storedUserModels.count {
            UserDefaults.standard.userModelConfigurations = validUserModels
            logDebug(
                "--- Updated UserDefaults to exclude \(storedUserModels.count - validUserModels.count) missing model(s). ---"
            )
        }
    }
    
    func handlePickedModelFile(temporaryFileURL: URL, originalFilename: String) {
        // This temporaryFileURL is from the document picker, often in a temporary directory.
        // It needs to be copied to the app's documents directory.
        self.pickedTemporaryModelFileURL = temporaryFileURL
        self.originalPickedModelFilename = originalFilename
        self.isShowingModelConfigSheet = true
        logDebug(
            "--- Picked model file: \(originalFilename) at temporary location: \(temporaryFileURL.path) ---"
        )
    }
    
    /// Processes the model after configuration in `ModelConfigurationSheet`.
    func processConfiguredModel(
        _ configuredModelIntent: ModelConfig,
        templateType: TemplateType,
        systemPrompt: String
    ) {
        isShowingModelConfigSheet = false
        
        guard let sourceTemporaryURL = pickedTemporaryModelFileURL else {
            logDebug(
                "--- Error: No temporary file URL available for model processing. ---"
            )
            userAlert = UserAlert(
                title: "Error",
                message: "Could not find the selected model file. Please try again."
            )
            cleanupTemporaryFile()
            return
        }
        
        let originalFilename = configuredModelIntent.filename  // This is the crucial filename
        
        Task {
            let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            let destinationURL = documentsDirectory.appendingPathComponent(
                originalFilename
            )
            
            do {
                // Ensure the source file actually exists before attempting to move
                guard
                    FileManager.default.fileExists(
                        atPath: sourceTemporaryURL.path
                    )
                else {
                    logDebug(
                        "--- Error: Source temporary file does not exist at \(sourceTemporaryURL.path). ---"
                    )
                    await MainActor.run {
                        self.userAlert = UserAlert(
                            title: "Error Adding Model",
                            message: "The temporary model file disappeared. Please try picking it again."
                        )
                    }
                    cleanupTemporaryFile()  // Clean up ViewModel state
                    return
                }
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    logDebug(
                        "--- Model file \(originalFilename) already exists at \(destinationURL.path). Replacing it. ---"
                    )
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.copyItem(
                    at: sourceTemporaryURL,
                    to: destinationURL
                )  // Use copyItem
                logDebug(
                    "--- Copied model from temporary \(sourceTemporaryURL.path) to \(destinationURL.path) ---"
                )
                
                // Now that it's copied, we can try to clean up the original temporary file from the picker if it's still around
                // Note: UIDocumentPicker with asCopy: true might place it in a location that's auto-cleaned.
                try? FileManager.default.removeItem(at: sourceTemporaryURL)
                
                // Create the StoredUserModel for UserDefaults persistence
                let storedUserModel = StoredUserModel(
                    filename: originalFilename,
                    displayName: configuredModelIntent.displayName,
                    templateTypeRawValue: templateType.rawValue,
                    systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
                )
                
                // Create the final ModelConfig with the correct fileURL and persisted details
                let finalModelConfig = ModelConfig(
                    name: configuredModelIntent.displayName,
                    filename: originalFilename,
                    template: configuredModelIntent.template,  // Template already created with correct system prompt
                    displayName: configuredModelIntent.displayName,
                    isUserAdded: true,
                    fileURL: destinationURL,  // Use the final destination URL
                    templateType: templateType,
                    systemPromptForTemplate: systemPrompt
                )
                
                await MainActor.run {
                    // Update availableModels: Remove old if exists, then add new
                    self.availableModels.removeAll {
                        $0.isUserAdded && $0.filename == finalModelConfig.filename
                    }
                    self.availableModels.append(finalModelConfig)
                    
                    // Update UserDefaults
                    var currentStoredConfigs = UserDefaults.standard.userModelConfigurations
                    currentStoredConfigs.removeAll {
                        $0.filename == storedUserModel.filename
                    }  // Remove old if exists
                    currentStoredConfigs.append(storedUserModel)
                    UserDefaults.standard.userModelConfigurations = currentStoredConfigs
                    
                    logDebug(
                        "--- Added/Updated custom model: \(finalModelConfig.displayName) with template '\(templateType.rawValue)' ---"
                    )
                    self.userAlert = UserAlert(
                        title: "Model Added",
                        message: "\(finalModelConfig.displayName) has been successfully added."
                    )
                    self.switchModel(to: finalModelConfig)  // Switch to the newly added model
                }
            } catch {
                logDebug(
                    "--- Failed to copy/process model from \(sourceTemporaryURL.path) to \(destinationURL.path): \(error.localizedDescription) ---"
                )
                await MainActor.run {
                    self.userAlert = UserAlert(
                        title: "Error Adding Model",
                        message: "Failed to copy model file: \(error.localizedDescription)"
                    )
                }
                // Don't delete sourceTemporaryURL here if copy failed, it might be needed for retry or inspection.
                // UIDocumentPicker's temporary file lifecycle should handle it.
            }
            
            await MainActor.run {
                // Cleanup ViewModel state regardless of success/failure of file ops
                self.pickedTemporaryModelFileURL = nil
                self.originalPickedModelFilename = nil
            }
        }
    }
    
    func cleanupTemporaryFile() {
        // This function now primarily resets ViewModel state.
        // The actual temporary file from UIDocumentPicker (when asCopy: true)
        // is usually managed by the system or copied then deleted.
        if let tempURL = pickedTemporaryModelFileURL,
           FileManager.default.fileExists(atPath: tempURL.path)
        {
            // If we explicitly created a copy that we manage, we can remove it.
            // However, the sourceTemporaryURL from handlePickedModelFile is usually from the picker's sandbox.
            // For safety, only attempt removal if we are certain it's a file we should manage.
            // Given the current flow, it's better to let the system handle the picker's temp file.
            logDebug(
                "--- cleanupTemporaryFile called. ViewModel state reset. Temporary file at \(tempURL.path) might be system-managed. ---"
            )
        }
        pickedTemporaryModelFileURL = nil
        originalPickedModelFilename = nil
        isShowingModelConfigSheet = false  // Ensure sheet is dismissed
    }
    
    func deleteCustomModel(_ model: ModelConfig) {
        guard model.isUserAdded, let fileURL = model.fileURL else {
            logDebug(
                "--- Attempted to delete a non-custom model or model with no URL: \(model.displayName) ---"
            )
            return
        }
        
        Task {
            do {
                try FileManager.default.removeItem(at: fileURL)
                logDebug("--- Deleted model file: \(fileURL.path) ---")
                
                await MainActor.run {
                    // Remove from UserDefaults
                    var currentStoredConfigs = UserDefaults.standard.userModelConfigurations
                    currentStoredConfigs.removeAll {
                        $0.filename == model.filename
                    }
                    UserDefaults.standard.userModelConfigurations = currentStoredConfigs
                    
                    // Remove from availableModels
                    self.availableModels.removeAll { $0.id == model.id }
                    
                    // If the deleted model was selected, switch to a default
                    if self.selectedModel?.id == model.id {
                        let newSelection = self.bundledModels.first ?? self.availableModels.first
                        self.selectedModel = newSelection
                        if let newSel = newSelection {
                            UserDefaults.standard.selectedModelFilename = newSel.filename
                            self.loadActiveModel(modelConfig: newSel)  // Reload the new model
                        } else {
                            // No models left at all
                            self.llm = nil
                            self.modelInfo = "No models available."
                            self.isInitializing = false  // Ensure UI updates
                            self.isRestarting = false
                            logDebug(
                                "--- No models available after deleting \(model.displayName). ---"
                            )
                        }
                    }
                    self.userAlert = UserAlert(
                        title: "Model Deleted",
                        message: "\(model.displayName) has been deleted."
                    )
                    logDebug(
                        "--- Deleted custom model config: \(model.displayName) ---"
                    )
                }
            } catch {
                logDebug(
                    "--- Failed to delete model file \(fileURL.path): \(error.localizedDescription) ---"
                )
                await MainActor.run {
                    self.userAlert = UserAlert(
                        title: "Error Deleting Model",
                        message: "Failed to delete model file: \(error.localizedDescription)"
                    )
                }
            }
            // Reset confirmation state
            await MainActor.run {
                self.modelToDelete = nil
                self.showDeleteConfirmation = false
            }
        }
    }
}
