//
//  StringConstants.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import Foundation

/// Defines standardized string constants used throughout the application.
enum StringConstants {
    static let defaultSystemPrompt = "You are a helpful assistant. Answer concisely and accurately."
    static let modelConfigSheetTitle = "Configure Model"
    static let defaultModelLoadErrorMessage = "The LLM model file (.gguf) could not be found or loaded. Please ensure it's correctly added to your project's bundle and is a valid GGUF file."
    static let emergencyResetTitle = "Emergency Reset"
    static let emergencyResetMessage = "Are you sure you want to reset the application to its initial state? All chat history, custom models, and settings will be permanently deleted. This action cannot be undone."
    static let deleteModelTitle = "Delete Model?"
    static func deleteModelMessage(for modelName: String) -> String {
        "Are you sure you want to delete \(modelName)? This will remove the model file from the app's documents. This action cannot be undone."
    }
    static let defaultDeleteModelMessage = "Are you sure you want to delete this model?"
    static let ggufDocumentTypeIdentifier = "com.ggerganov.gguf"  // A potential identifier, or use UTType by extension
}
