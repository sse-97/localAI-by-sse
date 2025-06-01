//
//  DataModels.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import Foundation
import LLM

// MARK: - User Alert Structure
/// Represents an alert to be shown to the user.
struct UserAlert: Identifiable {
    let id: UUID
    var title: String
    var message: String
    
    init(title: String, message: String) {
        self.id = UUID()
        self.title = title
        self.message = message
    }
}

// MARK: - Template Selection Types

/// Represents available template types for LLM models
enum TemplateType: String, CaseIterable, Identifiable, Codable {  // Made Codable for persistence
    case llama3 = "Llama 3"
    case qwen3 = "Qwen 3"
    case chatML = "ChatML"
    case alpaca = "Alpaca"
    case mistral = "Mistral"
    case gemma = "Gemma"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .llama3:
            return "Optimal for Llama 3 models. Uses begin_of_text, header_id, and eot_id tokens."
        case .qwen3:
            return "Designed for Qwen 3 models. Uses im_start and im_end tokens."
        case .chatML:
            return "A generic ChatML format with im_start and im_end tokens."
        case .alpaca:
            return "Instruction format using ### markers, ideal for Alpaca-style models."
        case .mistral:
            return "Uses INST and /INST tokens for Mistral models."
        case .gemma:
            return "Uses start_of_turn and end_of_turn for Google Gemma models."
        }
    }
    
    func createTemplate(_ systemPrompt: String?) -> Template {
        let effectiveSystemPrompt = (systemPrompt?.isEmpty ?? true) ? nil : systemPrompt
        switch self {
        case .llama3:
            return .llama3(effectiveSystemPrompt)
        case .qwen3:
            return .qwen3(effectiveSystemPrompt)
        case .chatML:
            return .chatML(effectiveSystemPrompt)
        case .alpaca:
            return .alpaca(effectiveSystemPrompt)
        case .mistral:
            return .mistral  // Mistral template in LLM library might not take system prompt directly in constructor
        case .gemma:
            return .gemma  // Gemma template in LLM library might not take system prompt directly in constructor
        }
    }
}

// MARK: - Data Models

/// Represents a selectable LLM model configuration.
/// Conforms to `Identifiable` for use in SwiftUI lists and `Equatable` for comparisons.
struct ModelConfig: Identifiable, Equatable {
    let id = UUID()
    let name: String  // Internal/technical name, often from filename for bundled
    let filename: String  // The actual .gguf filename
    var template: Template  // Made var to allow update if system prompt changes (though not currently implemented)
    var displayName: String  // User-facing display name
    let isUserAdded: Bool
    let fileURL: URL?  // For user-added models, this is their path in Documents directory
    
    // Added for persistence: original template type and system prompt for user models
    var templateType: TemplateType?  // Only relevant for user-added models to reconstruct template
    var systemPromptForTemplate: String?  // Only relevant for user-added models
    
    /// Conformance to `Equatable` based on `id`.
    static func == (lhs: ModelConfig, rhs: ModelConfig) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a single message in the chat history.
/// Conforms to `Identifiable` for SwiftUI lists, `Equatable` for comparisons, and `Codable` for potential serialization.
struct Message: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var content: String
    let isUser: Bool
    
    /// Conformance to `Equatable` based on `id`.
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents the parameters for LLM generation.
/// Conforms to `Codable` for potential serialization.
struct ModelParameters: Codable {
    var temperature: Float
    var topK: Int32
    var topP: Float
    var maxTokens: Int32  // Note: This is context window size, not max generation tokens
    
    /// Default parameters for the model.
    static let `default` = ModelParameters(
        temperature: 0.8,
        topK: 40,
        topP: 0.95,
        maxTokens: 8192  // Default context window, adjust if models have different defaults
    )
}

/// Structure for storing custom model configurations in UserDefaults.
struct StoredUserModel: Codable, Identifiable {
    let id: UUID
    let filename: String
    var displayName: String
    let templateTypeRawValue: String
    var systemPrompt: String?  // Allow nil for empty or default system prompt
    
    init(filename: String, displayName: String, templateTypeRawValue: String, systemPrompt: String? = nil) {
        self.id = UUID()
        self.filename = filename
        self.displayName = displayName
        self.templateTypeRawValue = templateTypeRawValue
        self.systemPrompt = systemPrompt
    }
    
    // Computed property to get TemplateType
    var templateType: TemplateType? {
        TemplateType(rawValue: templateTypeRawValue)
    }
}
