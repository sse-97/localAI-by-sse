//
//  ContentView.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import Combine
import LLM
import SwiftUI
import UniformTypeIdentifiers  // Required for UTType

// MARK: - Application-Wide Constants

/// Defines standardized UI constants used throughout the application.
private enum DesignConstants {
    // MARK: Sizing and Padding
    static let messageBubbleCornerRadius: CGFloat = 16
    static let standardPadding: CGFloat = 12
    static let smallPadding: CGFloat = 4
    static let mediumPadding: CGFloat = 8
    static let largePadding: CGFloat = 16
    static let iconSize: CGFloat = 24
    static let progressIndicatorScale: CGFloat = 0.7
    static let debugLogHeight: CGFloat = 300
}

/// Defines standardized string constants used throughout the application.
private enum StringConstants {
    static let defaultSystemPrompt =
    "You are a helpful assistant. Answer concisely and accurately."
    static let modelConfigSheetTitle = "Configure Model"
    static let defaultModelLoadErrorMessage =
    "The LLM model file (.gguf) could not be found or loaded. Please ensure it's correctly added to your project's bundle and is a valid GGUF file."
    static let emergencyResetTitle = "Emergency Reset"
    static let emergencyResetMessage =
    "Are you sure you want to reset the application to its initial state? All chat history, custom models, and settings will be permanently deleted. This action cannot be undone."
    static let deleteModelTitle = "Delete Model?"
    static func deleteModelMessage(for modelName: String) -> String {
        "Are you sure you want to delete \(modelName)? This will remove the model file from the app's documents. This action cannot be undone."
    }
    static let defaultDeleteModelMessage =
    "Are you sure you want to delete this model?"
    static let ggufDocumentTypeIdentifier = "com.ggerganov.gguf"  // A potential identifier, or use UTType by extension
}

// MARK: - User Alert Structure
/// Represents an alert to be shown to the user.
struct UserAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

// MARK: - Model Template Extension

/// Extends the external `Template` struct from the LLM library.
/// This allows defining predefined chat templates tailored to specific models.
extension Template {
    /// Creates a `Template` configured for Llama 3 model instruction format.
    /// - Parameter systemPrompt: An optional system prompt to guide the model's behavior.
    /// - Returns: A `Template` instance for Llama 3.
    static func llama3(_ systemPrompt: String? = nil) -> Template {
        return Template(
            prefix: "<|begin_of_text|>",
            system: (
                "<|start_header_id|>system<|end_header_id|>\n\n",
                "<|eot_id|>"
            ),
            user: (
                "<|start_header_id|>user<|end_header_id|>\n\n",
                "<|eot_id|>"
            ),
            bot: (
                "<|start_header_id|>assistant<|end_header_id|>\n\n",
                ""
            ),
            stopSequence: "<|eot_id|>",
            systemPrompt: systemPrompt
        )
    }
    
    /// Creates a `Template` configured for Qwen3 model instruction format.
    /// - Parameter systemPrompt: An optional system prompt to guide the model's behavior.
    /// - Returns: A `Template` instance for Qwen3.
    static func qwen3(_ systemPrompt: String? = nil) -> Template {
        return Template(
            system: ("<|im_start|>system\n", "<|im_end|>\n"),
            user: ("<|im_start|>user\n", "<|im_end|>\n"),
            bot: ("<|im_start|>assistant\n", "<|im_end|>\n"),
            stopSequence: "<|im_end|>",
            systemPrompt: systemPrompt
        )
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
            return
            "Optimal for Llama 3 models. Uses begin_of_text, header_id, and eot_id tokens."
        case .qwen3:
            return
            "Designed for Qwen 3 models. Uses im_start and im_end tokens."
        case .chatML:
            return "A generic ChatML format with im_start and im_end tokens."
        case .alpaca:
            return
            "Instruction format using ### markers, ideal for Alpaca-style models."
        case .mistral:
            return "Uses INST and /INST tokens for Mistral models."
        case .gemma:
            return "Uses start_of_turn and end_of_turn for Google Gemma models."
        }
    }
    
    func createTemplate(_ systemPrompt: String?) -> Template {
        let effectiveSystemPrompt =
        (systemPrompt?.isEmpty ?? true) ? nil : systemPrompt
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
    let id = UUID()  // For easier identification if needed, though filename is primary key for file ops
    let filename: String
    var displayName: String
    let templateTypeRawValue: String
    var systemPrompt: String?  // Allow nil for empty or default system prompt
    
    // Computed property to get TemplateType
    var templateType: TemplateType? {
        TemplateType(rawValue: templateTypeRawValue)
    }
}

// MARK: - UI Color Extensions

/// Extends `Color` to provide platform-agnostic system colors.
extension Color {
    static var secondarySystemBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    static var systemGray5: Color {
        Color(UIColor.systemGray5)
    }
    
    static var systemGray6: Color {
        Color(UIColor.systemGray6)
    }
}

// MARK: - UserDefaults Extension

/// Extends `UserDefaults` for type-safe access to stored application preferences.
extension UserDefaults {
    private enum Keys {
        static let selectedModelFilename = "selectedModelFilename"
        static let userModelConfigurationsData =
        "userModelConfigurationsData_v2"  // New key for StoredUserModel
    }
    
    var selectedModelFilename: String? {
        get { string(forKey: Keys.selectedModelFilename) }
        set { set(newValue, forKey: Keys.selectedModelFilename) }
    }
    
    var userModelConfigurations: [StoredUserModel] {
        get {
            guard let data = data(forKey: Keys.userModelConfigurationsData)
            else { return [] }
            do {
                return try JSONDecoder().decode(
                    [StoredUserModel].self,
                    from: data
                )
            } catch {
                // Consider logging this error to the app's debug log if available
                print(
                    "UserDefaults Error: Failed to decode userModelConfigurations: \(error.localizedDescription)"
                )
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                set(data, forKey: Keys.userModelConfigurationsData)
            } catch {
                // Consider logging this error
                print(
                    "UserDefaults Error: Failed to encode userModelConfigurations: \(error.localizedDescription)"
                )
            }
        }
    }
}

// MARK: - View Modifiers

/// A `ViewModifier` to apply a standard message bubble appearance.
struct MessageBubbleStyle: ViewModifier {
    let isUserMessage: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(DesignConstants.standardPadding)
            .foregroundColor(isUserMessage ? .black : .primary)
            .background(
                isUserMessage
                ? Color.accentColor
                : Color.secondarySystemBackground
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignConstants.messageBubbleCornerRadius
                )
            )
            .textSelection(.enabled)
    }
}

extension View {
    func messageBubble(isUserMessage: Bool) -> some View {
        modifier(MessageBubbleStyle(isUserMessage: isUserMessage))
    }
}

// MARK: - Custom Model Configuration Sheet

/// Sheet for configuring a custom model after file selection
struct ModelConfigurationSheet: View {
    let temporaryFileURL: URL
    let originalFilename: String
    let onComplete: (ModelConfig, TemplateType, String) -> Void  // Pass back templateType and systemPrompt
    let onCancel: () -> Void
    
    @State private var displayName: String
    @State private var selectedTemplate: TemplateType = .llama3  // Default template
    @State private var systemPrompt: String = StringConstants
        .defaultSystemPrompt
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
            initialValue: defaultDisplayName.isEmpty
            ? "My Custom Model" : defaultDisplayName
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
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
                        let finalSystemPrompt = systemPrompt.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        let template = selectedTemplate.createTemplate(
                            finalSystemPrompt.isEmpty ? nil : finalSystemPrompt
                        )
                        let modelConfigIntent = ModelConfig(
                            name: displayName.isEmpty
                            ? originalFilename : displayName,  // Name could be same as display for user models
                            filename: originalFilename,
                            template: template,
                            displayName: displayName.isEmpty
                            ? originalFilename : displayName,
                            isUserAdded: true,
                            fileURL: temporaryFileURL,  // This is temporary, will be replaced by final URL in ViewModel
                            templateType: selectedTemplate,  // Store for persistence
                            systemPromptForTemplate: finalSystemPrompt  // Store for persistence
                        )
                        onComplete(
                            modelConfigIntent,
                            selectedTemplate,
                            finalSystemPrompt
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        displayName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
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

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL, String) -> Void
    
    // Define GGUF type for better filtering if possible
    // Note: This custom UTType might not be universally recognized unless the app registers it.
    // Using .data or a known extension-based type is safer if this doesn't work as expected.
    private static let ggufType =
    UTType(filenameExtension: "gguf", conformingTo: .data) ?? .data
    
    func makeUIViewController(context: Context)
    -> UIDocumentPickerViewController
    {
        // Try to use the specific GGUF type, fall back to generic data if it's nil (shouldn't be for .gguf)
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [Self.ggufType, UTType.data],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let pickedURL = urls.first else { return }
            
            // Ensure we have security-scoped access to the URL if it's outside the app's sandbox
            // This is important for files picked from locations like "On My iPhone/iPad" or iCloud Drive.
            let shouldStopAccessing =
            pickedURL.startAccessingSecurityScopedResource()
            
            // The `asCopy: true` in UIDocumentPickerViewController constructor usually handles copying
            // to a temporary location, so direct access here should be to that temporary copy.
            // However, it's good practice to be mindful of security-scoped URLs.
            
            let originalFilename = pickedURL.lastPathComponent
            
            parent.onDocumentPicked(pickedURL, originalFilename)
            
            if shouldStopAccessing {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            // User cancelled the picker, nothing to do here as no file was picked.
        }
    }
}

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
    @Published private(set) var availableModels: [ModelConfig] = []
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
    
    // MARK: Private Properties
    private var generationStartTime: Date?
    private var llmEventCancellable: AnyCancellable?
    private var copyConfirmationTask: Task<Void, Never>? = nil
    
    private let bundledModels: [ModelConfig] = [
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
                UserDefaults.standard.selectedModelFilename =
                firstModel.filename
                logDebug(
                    "--- Selected default model: \(firstModel.displayName) ---"
                )
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
}

// MARK: - ChatViewModel: Custom Model Management
extension ChatViewModel {
    /// Loads user-added model configurations from persisted `StoredUserModel` data.
    private func loadUserModelsFromUserDefaults() {
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
                    logDebug(
                        "--- Error: Could not determine template type for stored model \(storedModel.displayName). Skipping. ---"
                    )
                    continue
                }
                let template = templateType.createTemplate(
                    storedModel.systemPrompt
                )
                
                let userModelConfig = ModelConfig(
                    name: storedModel.displayName,  // For user models, name can be same as displayName
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
                    logDebug(
                        "--- Loaded user model from UserDefaults: \(userModelConfig.displayName) from \(fileURL.path) with template '\(templateType.rawValue)' ---"
                    )
                }
                validUserModels.append(storedModel)
            } else {
                logDebug(
                    "--- User model file \(storedModel.filename) not found at \(fileURL.path). Removing from UserDefaults. ---"
                )
                // This model will be excluded when `validUserModels` is saved back.
            }
        }
        
        // If any models were found to be missing, update UserDefaults to only contain valid ones.
        if validUserModels.count != storedUserModels.count {
            UserDefaults.standard.userModelConfigurations = validUserModels
            logDebug(
                "--- Cleaned up UserDefaults, removed \(storedUserModels.count - validUserModels.count) missing user models. ---"
            )
        }
    }
    
    func handlePickedModelFile(temporaryFileURL: URL, originalFilename: String)
    {
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
                "--- Error: pickedTemporaryModelFileURL was nil during processing. ---"
            )
            userAlert = UserAlert(
                title: "Error",
                message:
                    "Could not find the selected model file. Please try again."
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
                            message:
                                "The temporary model file disappeared. Please try picking it again."
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
                        $0.isUserAdded
                        && $0.filename == finalModelConfig.filename
                    }
                    self.availableModels.append(finalModelConfig)
                    
                    // Update UserDefaults
                    var currentStoredConfigs = UserDefaults.standard
                        .userModelConfigurations
                    currentStoredConfigs.removeAll {
                        $0.filename == storedUserModel.filename
                    }  // Remove old if exists
                    currentStoredConfigs.append(storedUserModel)
                    UserDefaults.standard.userModelConfigurations =
                    currentStoredConfigs
                    
                    logDebug(
                        "--- Added/Updated custom model: \(finalModelConfig.displayName) with template '\(templateType.rawValue)' ---"
                    )
                    self.userAlert = UserAlert(
                        title: "Model Added",
                        message:
                            "\(finalModelConfig.displayName) has been successfully added."
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
                        message:
                            "Failed to copy model file: \(error.localizedDescription)"
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
                    var currentStoredConfigs = UserDefaults.standard
                        .userModelConfigurations
                    currentStoredConfigs.removeAll {
                        $0.filename == model.filename
                    }
                    UserDefaults.standard.userModelConfigurations =
                    currentStoredConfigs
                    
                    // Remove from availableModels
                    self.availableModels.removeAll { $0.id == model.id }
                    
                    // If the deleted model was selected, switch to a default
                    if self.selectedModel?.id == model.id {
                        let newSelection =
                        self.bundledModels.first
                        ?? self.availableModels.first
                        self.selectedModel = newSelection
                        if let newSel = newSelection {
                            UserDefaults.standard.selectedModelFilename =
                            newSel.filename
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
                        message:
                            "Failed to delete model file: \(error.localizedDescription)"
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
            let modelToLoad = modelConfig ?? selectedModel
                ?? availableModels.first
        else {
            Task { @MainActor in
                self.modelInfo = "Error: No model available to load."
                self.llm = nil
                if initialLoad { self.isInitializing = false }
                self.isRestarting = false
                logDebug(
                    "--- Critical Error: No model configuration available to load. ---"
                )
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
            let fileExtension = URL(fileURLWithPath: modelToLoad.filename)
                .pathExtension
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
                self.modelInfo =
                "Failed to construct URL for \(modelToLoad.displayName)."
                self.llm = nil
                if initialLoad { self.isInitializing = false }
                self.isRestarting = false
                logDebug(
                    "--- Model URL could not be constructed for \(modelToLoad.displayName). ---"
                )
                self.userAlert = UserAlert(
                    title: "Model Load Error",
                    message:
                        "Could not find the path for model file: \(modelToLoad.filename)."
                )
            }
            return
        }
        
        guard FileManager.default.fileExists(atPath: validModelUrl.path) else {
            Task { @MainActor in
                self.modelInfo =
                "Model file not found for \(modelToLoad.displayName) at \(validModelUrl.path)."
                self.llm = nil
                if initialLoad { self.isInitializing = false }
                self.isRestarting = false
                logDebug(
                    "--- Model file does not exist at path: \(validModelUrl.path) for \(modelToLoad.displayName). ---"
                )
                self.userAlert = UserAlert(
                    title: "Model Load Error",
                    message:
                        "Model file '\(modelToLoad.filename)' is missing or inaccessible."
                )
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
                    self.modelInfo =
                    "Failed to initialize \(modelToLoad.displayName)."
                    self.logDebug(
                        "--- LLM initialization failed for: \(modelToLoad.displayName) from \(validModelUrl.path). Check LLM library logs. ---"
                    )
                    self.userAlert = UserAlert(
                        title: "Model Load Failed",
                        message:
                            "Could not initialize \(modelToLoad.displayName). The model file might be corrupted, incompatible, or require more memory."
                    )
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
                self.memoryUsage =
                Double(physicalMemoryBytes) / (1024.0 * 1024.0 * 1024.0)  // GB
            }
            return
        }
        
        Task.detached(priority: .utility) {
            let historyText = llm.history.map { $0.content }.joined(
                separator: " "
            )
            let tokens = await llm.encode(historyText)  // Assuming llm.encode is safe to call from background
            
            let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
            let deviceMemoryGB =
            Double(physicalMemoryBytes) / (1024.0 * 1024.0 * 1024.0)
            
            await MainActor.run {
                self.tokenCount = tokens.count
                // Ensure maxTokens is not zero to avoid division by zero
                let maxContextTokens =
                Double(self.modelParameters.maxTokens) > 0
                ? Double(self.modelParameters.maxTokens) : 8192.0
                self.contextUsage = Double(tokens.count) / maxContextTokens
                self.memoryUsage = deviceMemoryGB
            }
        }
    }
    
    func updateModelParameters() {
        guard let llm = llm else {
            logDebug("--- Attempted to update parameters but LLM is nil. ---")
            userAlert = UserAlert(
                title: "Error",
                message: "Cannot update parameters: Model not loaded."
            )
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
            self.userAlert = UserAlert(
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
            }
            if llm == nil {
                logDebug("--- Attempted to send message but LLM is nil. ---")
            }
            if isGenerating {
                logDebug(
                    "--- Attempted to send message while already generating. ---"
                )
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
                if self.messages.last?.isUser == false
                    && self.messages.last?.content.isEmpty == true
                {
                    // Consider updating the empty AI message to an error or "No response"
                    // self.messages[self.messages.count - 1] = Message(content: "[No response from model]", isUser: false)
                    logDebug(
                        "--- Warning: AI response might be empty after generation. ---"
                    )
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
            logDebug(
                "--- Restart called while already restarting or initializing. Ignoring. ---"
            )
            return
        }
        if isGenerating { stop() }  // Stop any ongoing generation
        
        Task { @MainActor in
            self.isRestarting = true  // Set restarting flag
            logDebug(
                "--- LLM restart initiated for model: \(selectedModel?.displayName ?? "Unknown") ---"
            )
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
            logDebug(
                "--- Attempted to switch to the already selected model: \(modelConfig.displayName). Ignoring. ---"
            )
            return
        }
        guard !isGenerating, !isRestarting, !isInitializing else {
            logDebug(
                "--- Model switch attempted during generation, restart, or initialization. Ignoring. ---"
            )
            userAlert = UserAlert(
                title: "Busy",
                message:
                    "Please wait for the current operation to complete before switching models."
            )
            return
        }
        if isGenerating { stop() }  // Stop any ongoing generation
        
        Task { @MainActor in
            self.isRestarting = true  // Use isRestarting to indicate model loading activity
            logDebug(
                "--- Model switch initiated to: \(modelConfig.displayName) ---"
            )
            self.messages = []  // Clear chat history
            UserDefaults.standard.selectedModelFilename = modelConfig.filename  // Save preference
            logDebug(
                "--- Model preference '\(modelConfig.filename)' saved for \(modelConfig.displayName). Chat cleared. ---"
            )
            // selectedModel will be updated by loadActiveModel
        }
        
        loadActiveModel(modelConfig: modelConfig, initialLoad: false)  // `initialLoad: false` indicates it's a switch/restart
    }
    
    /// Resets the application to its initial state, deleting all user data.
    func emergencyReset() {
        guard !isInitializing else {  // Prevent reset if already in initial loading
            logDebug(
                "--- Emergency Reset called while already initializing. Ignoring. ---"
            )
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
            logDebug(
                "--- LLM instance and handlers cleared for emergency reset. ---"
            )
            
            // Brief pause to allow any async operations from LLM deinit to settle (if any)
            // This is a precaution; ideally, LLM deinitialization is synchronous or awaitable.
            logDebug(
                "--- Brief pause during emergency reset for resource cleanup. ---"
            )
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
                let fileURL = documentsDirectory.appendingPathComponent(
                    storedConfig.filename
                )
                do {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        try FileManager.default.removeItem(at: fileURL)
                        logDebug(
                            "--- Deleted user model file: \(fileURL.path) during reset. ---"
                        )
                    }
                } catch {
                    logDebug(
                        "--- Failed to delete user model file \(fileURL.path) during reset: \(error.localizedDescription) ---"
                    )
                }
            }
            
            // Clear UserDefaults related to models
            UserDefaults.standard.userModelConfigurations = []
            UserDefaults.standard.selectedModelFilename = nil
            logDebug(
                "--- Cleared user model configurations and selected model from UserDefaults. ---"
            )
            
            // Reset available models to only bundled ones
            self.availableModels = self.bundledModels
            self.selectedModel = self.bundledModels.first  // Select the first bundled model as default
            
            if let defaultModel = self.selectedModel {
                UserDefaults.standard.selectedModelFilename =
                defaultModel.filename
                logDebug(
                    "--- Default model set to: \(defaultModel.displayName) after reset. Proceeding to load. ---"
                )
                // `isInitializing` is already true, so loadActiveModel will show the initial loading view.
                self.loadActiveModel(
                    modelConfig: defaultModel,
                    initialLoad: true
                )
            } else {
                logDebug(
                    "--- CRITICAL: No bundled models found after reset. This indicates a problem with `bundledModels` definition. ---"
                )
                self.modelInfo =
                "Error: No default model available after reset."
                self.isInitializing = false  // Allow UI to show an error state if needed
            }
            self.userAlert = UserAlert(
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
                logDebug(
                    "--- Copied to clipboard (Message ID: \(id)): \"\(text.prefix(50))\(text.count > 50 ? "..." : "")\" ---"
                )
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
                    logDebug(
                        "--- Copy confirmation task cancelled for message ID: \(id). ---"
                    )
                } catch {
                    logDebug(
                        "--- Copy confirmation task failed for message ID \(id): \(error.localizedDescription) ---"
                    )
                }
            }
        } else {
            // For general copies (e.g., debug log) without a message ID
            logDebug(
                "--- Copied to clipboard (General): \"\(text.prefix(50))\(text.count > 50 ? "..." : "")\" ---"
            )
            // Optionally show a generic "Copied!" alert if needed for these cases
            // self.userAlert = UserAlert(title: "Copied", message: "Content copied to clipboard.")
        }
    }
    
    func clearDebugInfo() {
        Task { @MainActor in
            self.debugInfo = "--- Debug log cleared by user. ---\n"
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
    
    private func setupLLMObservers() {
        guard let llm = llm else {
            logDebug(
                "--- Attempted to setup LLM observers, but LLM instance is nil. ---"
            )
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
                            self.generationSpeed =
                            Double(self.generatedTokens) / duration
                        }
                    }
                } else {
                    // Nil deltaToken indicates end of stream
                    if self.isGenerating {  // Check if we were actually generating
                        self.isGenerating = false
                        self.logDebug(
                            "--- Generation stream ended (LLM update handler received nil delta). Final token count: \(self.generatedTokens) ---"
                        )
                        if let startTime = self.generationStartTime {
                            let duration = Date().timeIntervalSince(startTime)
                            if duration > 0 {  // Avoid division by zero
                                self.generationSpeed =
                                Double(self.generatedTokens) / duration
                                self.logDebug(
                                    String(
                                        format:
                                            "--- Final generation speed: %.2f tokens/sec ---",
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

// MARK: - Chat UI Components

/// A view that displays a single message (either from the user or the AI).
struct MessageView: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: Message
    let isGenerating: Bool
    let isLastMessage: Bool  // Is this the absolute last message in the chat?
    let onCopy: (String) -> Void
    let copiedMessageId: UUID?
    
    // Determines if this specific message bubble should show a typing indicator
    private var isTypingIndicator: Bool {
        !message.isUser && message.content.isEmpty && isGenerating
        && isLastMessage
    }
    
    private var displayText: String {
        isTypingIndicator ? "Typing..." : message.content
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()  // Push user messages to the right
                Text(message.content)
                    .messageBubble(isUserMessage: true)
            } else {
                botMessageContent
                Spacer()  // Keep bot messages to the left
            }
        }
        .padding(.horizontal, DesignConstants.standardPadding)
        .padding(.vertical, DesignConstants.smallPadding)
        .contextMenu {
            // Only allow copying non-empty AI messages
            if !message.isUser && !message.content.isEmpty && !isTypingIndicator
            {
                Button {
                    onCopy(message.content)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            message.isUser
            ? "User message: \(message.content)"
            : "AI message: \(displayText)"
        )
    }
    
    @ViewBuilder
    private var botMessageContent: some View {
        HStack(alignment: .bottom, spacing: DesignConstants.mediumPadding) {
            Text(displayText)
                .messageBubble(isUserMessage: false)
                .overlay(alignment: .bottomTrailing) {  // For "Copied!" confirmation
                    if !message.isUser && message.id == copiedMessageId {
                        Text("Copied!")
                            .font(.caption2).fontWeight(.bold)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(Color.white)
                            .clipShape(Capsule())
                            .transition(.opacity.animation(.default))
                            .padding(5)  // Padding around the "Copied!" capsule
                            .id("copyConfirmation-\(message.id)")  // Ensure unique ID for transition
                    }
                }
            
            if isTypingIndicator {
                ProgressView()  // Show spinner next to "Typing..."
                    .scaleEffect(DesignConstants.progressIndicatorScale)
                    .padding(.bottom, DesignConstants.mediumPadding)  // Align with text baseline
            }
        }
    }
}

/// A view for adjusting LLM model parameters and performing model/chat actions.
struct ParameterSettingView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isShowingResetConfirmation = false  // For emergency reset
    
    var body: some View {
        List {
            modelLicenseSection
            modelSelectionSection
            
            Section(header: Text("LLM Parameters (Apply to take effect)")) {
                temperatureSection
                topKSection
                topPSection
                maxTokensSection  // For context window size
            }
            
            Section {
                Button("Apply LLM Parameters") {
                    viewModel.updateModelParameters()
                }
                .disabled(
                    viewModel.isRestarting || viewModel.isGenerating
                    || viewModel.isInitializing || viewModel.llm == nil
                )
            }
            
            conversationActionsSection
            otherActionsSection
            debugModeSection
        }
        .sheet(
            isPresented: $viewModel.isShowingDocumentPicker,
            onDismiss: {
                // If the sheet is dismissed without completing, ensure temporary files are handled.
                // This might be redundant if onCancel in ModelConfigurationSheet handles it.
                if viewModel.isShowingModelConfigSheet == false {  // Check if it was dismissed from ModelConfigurationSheet
                    viewModel.cleanupTemporaryFile()
                }
            }
        ) {
            DocumentPicker { temporaryURL, originalFilename in
                viewModel.handlePickedModelFile(
                    temporaryFileURL: temporaryURL,
                    originalFilename: originalFilename
                )
            }
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
        .navigationTitle("Settings & Actions")
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
    
    private var temperatureSection: some View {
        VStack(alignment: .leading) {
            Text(
                "Temperature (Randomness): \(viewModel.modelParameters.temperature, specifier: "%.2f")"
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
                "Top P (Nucleus Sampling): \(viewModel.modelParameters.topP, specifier: "%.2f")"
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

/// A view displaying system performance metrics, context usage, and debug information.
struct SystemMonitorView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        List {
            currentModelSection
            performanceMetricsSection
            contextUsageSection
            debugLogSection
        }
        .navigationTitle("System Monitor")
        .onAppear {
            viewModel.refreshContextMetrics()  // Refresh metrics when view appears
        }
    }
    
    private var currentModelSection: some View {
        Section(header: Text("Current Model")) {
            if viewModel.isInitializing
                || (viewModel.isRestarting && viewModel.llm == nil)
            {
                HStack {
                    Text(
                        viewModel.modelInfo.isEmpty
                        ? "Model loading..." : viewModel.modelInfo
                    )
                    .font(.headline).foregroundColor(.secondary)
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                }
            } else if let model = viewModel.selectedModel, viewModel.llm != nil
            {
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.displayName).font(.headline)
                        Text(model.filename)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(model.isUserAdded ? "Custom" : "Built-in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            (model.isUserAdded
                             ? Color.blue.opacity(0.1)
                             : Color.green.opacity(0.1)).cornerRadius(4)
                        )
                }
            } else {
                Text(
                    viewModel.modelInfo.isEmpty
                    ? "No model loaded" : viewModel.modelInfo
                )
                .font(.headline)
                .foregroundColor(
                    viewModel.llm == nil && !viewModel.modelInfo.isEmpty
                    && !viewModel.modelInfo.contains(
                        "Error: No model available"
                    ) ? .red : .secondary
                )
            }
        }
    }
    
    private var performanceMetricsSection: some View {
        Section(header: Text("Performance Metrics")) {
            metricRow(
                title: "Generation speed",
                value: String(
                    format: "%.1f tokens/sec",
                    viewModel.generationSpeed
                )
            )
            .accessibilityLabel(
                "Generation speed \(String(format: "%.1f", viewModel.generationSpeed)) tokens per second"
            )
            
            metricRow(
                title: "Device Memory",
                value: String(format: "%.2f GB", viewModel.memoryUsage)
            )
            .accessibilityHint(
                "Total physical memory of this device. Not app-specific usage."
            )
            .accessibilityLabel(
                "Total device memory \(String(format: "%.2f", viewModel.memoryUsage)) gigabytes"
            )
            
            metricRow(
                title: "Generated tokens (last)",
                value: "\(viewModel.generatedTokens)"
            )
            .accessibilityLabel(
                "Generated tokens in the last response: \(viewModel.generatedTokens)"
            )
        }
    }
    
    private var contextUsageSection: some View {
        Section(
            header: Text(
                "Context Usage (Max: \(viewModel.modelParameters.maxTokens) tokens)"
            )
        ) {
            metricRow(
                title: "Token count (history)",
                value: "\(viewModel.tokenCount)"
            )
            .accessibilityLabel(
                "Current token count in history: \(viewModel.tokenCount)"
            )
            VStack(alignment: .leading) {
                HStack {
                    Text("Context usage")
                    Spacer()
                    Text("\(Int(viewModel.contextUsage * 100))%")
                        .foregroundColor(.secondary)
                }
                ProgressView(value: viewModel.contextUsage)
                    .progressViewStyle(.linear)
                    .tint(
                        viewModel.contextUsage > 0.9
                        ? .red
                        : viewModel.contextUsage > 0.7
                        ? .orange : .accentColor
                    )
                    .accessibilityLabel(
                        "Context usage \(Int(viewModel.contextUsage * 100)) percent"
                    )
            }
            metricRow(
                title: "History entries (pairs)",
                value: "\((viewModel.llm?.history.count ?? 0) / 2)"
            )
            .accessibilityLabel(
                "Number of user and bot message exchanges in history: \((viewModel.llm?.history.count ?? 0) / 2)"
            )
        }
    }
    
    private var debugLogSection: some View {
        Section(header: Text("Debug Log")) {
            Toggle(
                "Enable Debug Logging",
                isOn: $viewModel.debugModeEnabled.animation()
            )
            .onChange(of: viewModel.debugModeEnabled) { _, newValue in
                viewModel.logDebug(
                    "--- Debug mode \(newValue ? "enabled" : "disabled") by user (Monitor View) ---"
                )
            }
            if viewModel.debugModeEnabled {
                debugControls
                debugLogView
            }
        }
    }
    
    private var debugControls: some View {
        HStack {
            Toggle("Auto-scroll Log", isOn: $viewModel.shouldAutoScrollDebug)
            Spacer()
            Button(action: { viewModel.clearDebugInfo() }) {
                Label("Clear Log", systemImage: "trash")
            }
            .disabled(viewModel.debugInfo.isEmpty)
            Button {
                viewModel.copyToClipboard(viewModel.debugInfo)
            } label: {
                Label("Copy Log", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.debugInfo.isEmpty)
        }
        .padding(.vertical, DesignConstants.smallPadding)
    }
    
    private var debugLogView: some View {
        Group {
            if !viewModel.debugInfo.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(viewModel.debugInfo)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(DesignConstants.mediumPadding)
                            .background(Color.systemGray6.opacity(0.5))
                            .cornerRadius(DesignConstants.smallPadding)
                            .id("debugTextEnd")  // Anchor for scrolling
                    }
                    .frame(height: DesignConstants.debugLogHeight)
                    .onChange(of: viewModel.debugInfo) { _, _ in  // Use new syntax if targeting iOS 17+
                        if viewModel.shouldAutoScrollDebug {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("debugTextEnd", anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {  // Scroll on appear as well
                        if viewModel.shouldAutoScrollDebug {
                            proxy.scrollTo("debugTextEnd", anchor: .bottom)
                        }
                    }
                }
            } else {
                Text(
                    "No debug information available. Enable debug logging to see details."
                )
                .foregroundColor(.secondary).italic()
                .padding(.vertical, DesignConstants.mediumPadding)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    @ViewBuilder
    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary).lineLimit(1).truncationMode(
                .middle
            )
        }
    }
}

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
                        title: viewModel.llm == nil
                        && viewModel.selectedModel != nil
                        ? "Switching Model..." : "Restarting Model..."
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
            .padding(DesignConstants.largePadding * 1.5)  // More padding for the content box
            .background(.ultraThinMaterial)  // Use ultraThinMaterial for the box background
            .cornerRadius(DesignConstants.messageBubbleCornerRadius)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)  // Softer shadow
        }
        .transition(.opacity.animation(.easeInOut))  // Animate the overlay appearance/disappearance
    }
    
    private func handleSendMessage() {
        let trimmedMessage = messageInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedMessage.isEmpty, !viewModel.isGenerating,
              !viewModel.isRestarting, !viewModel.isInitializing,
              viewModel.llm != nil
        else {
            viewModel.logDebug(
                "--- Send message blocked: Empty or LLM busy/unavailable. ---"
            )
            return
        }
        
        let messageToSend = trimmedMessage
        messageInput = ""  // Clear input field immediately
        Task { await viewModel.sendMessage(text: messageToSend) }
    }
    
    private func hideKeyboard() {
        // Standard way to resign first responder in SwiftUI
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        inputFocused = false  // Also update focus state
    }
}

/// A view displayed if the LLM model file cannot be found or loaded, or other critical errors.
struct ModelErrorView: View {
    let errorMessage: String?
    // Optional: Add a retry action
    // let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DesignConstants.largePadding) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60)).foregroundColor(.red).padding()
            Text("Model Loading Error").font(.title).fontWeight(.bold)
            Text(errorMessage ?? StringConstants.defaultModelLoadErrorMessage)
                .multilineTextAlignment(.center).foregroundColor(.secondary)
                .padding(.horizontal)
            // if let onRetry = onRetry {
            //     Button("Retry Load") { onRetry() }
            //         .padding(.top)
            //         .buttonStyle(.borderedProminent)
            // }
            Spacer()
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// View shown during initial model loading at app startup.
struct InitialLoadingView: View {
    var body: some View {
        ZStack {
            // Use a system background color that adapts to light/dark mode
            Color.secondarySystemBackground.ignoresSafeArea()
            VStack(spacing: DesignConstants.largePadding) {
                ProgressView().scaleEffect(1.5)
                Text("Initializing Model...").font(.headline).foregroundColor(
                    .secondary
                )
            }
            .padding(DesignConstants.largePadding * 1.5)
            .background(.regularMaterial)  // Use regular material for a standard blurred background
            .cornerRadius(DesignConstants.messageBubbleCornerRadius)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)  // Subtle shadow
        }
    }
}

/// View shown when device iOS version is incompatible
struct VersionIncompatibleView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("iOS Version Not Supported")
                .font(.title)
                .fontWeight(.bold)
            
            Text(
                "This app requires iOS 17.6 or newer to run properly. Please update your device software."
            )
            .multilineTextAlignment(.center)
            .padding()
            
            Button("Check for Updates") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

/// Privacy Policy View - Added for App Store compliance
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Last Updated: May 17, 2024")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Introduction")
                        .font(.headline)
                    
                    Text(
                        "localAI is committed to protecting your privacy. This Privacy Policy explains how our application collects, uses, and safeguards information when you use our mobile application."
                    )
                }
                
                Group {
                    Text("Summary")
                        .font(.headline)
                    
                    Text(
                        "**localAI processes all data locally on your device.** The app does not collect, transmit, store, or share any personal information or conversation data with external servers or third parties."
                    )
                }
                
                Group {
                    Text("Information Collection and Use")
                        .font(.headline)
                    
                    Text("Local Processing")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(
                        "• All AI inference occurs entirely on your device\n• Conversations with the AI remain on your device and are never transmitted externally\n• No user data is uploaded to remote servers\n• No analytics or telemetry data is collected"
                    )
                }
                
                Group {
                    Text("User-Added Models")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(
                        "When you import custom models:\n• Model files are stored locally in your device's storage within the app's sandbox\n• These files are never uploaded to external servers\n• The app does not analyze the content of your model files beyond what's necessary for functionality"
                    )
                }
                
                Group {
                    Text("Permissions")
                        .font(.headline)
                    
                    Text("File Access")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(
                        "localAI requests access to documents only when you explicitly choose to import custom models. We only access files you specifically select, and we do not scan or index any other files on your device."
                    )
                }
                
                Group {
                    Text("Data Security")
                        .font(.headline)
                    
                    Text(
                        "Since all data is processed locally on your device, data security is maintained through your device's built-in security features. We recommend using a device password/PIN and keeping your iOS up to date."
                    )
                }
                
                Group {
                    Text("Your Choices")
                        .font(.headline)
                    
                    Text(
                        "You can delete conversations and imported models at any time through the app's interface. If you wish to remove all app data, you can uninstall the application."
                    )
                }
                
                Group {
                    Text("Contact Information")
                        .font(.headline)
                    
                    Text(
                        "If you have questions or concerns about our privacy practices, please open an issue on our GitHub repository at https://github.com/sse-97/localAI-by-sse."
                    )
                    .padding(.bottom, 20)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

// MARK: - App Entry Point & Main Content View

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingGlobalResetConfirmation = false  // For the toolbar reset option
    
    var body: some View {
        Group {
            if viewModel.isOSVersionIncompatible {
                VersionIncompatibleView()
            } else if viewModel.isInitializing {
                InitialLoadingView()
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
        .environmentObject(viewModel)  // Pass viewModel to the environment if needed by deeper views (though direct passing is used here)
        .sheet(
            isPresented: $viewModel.isShowingModelConfigSheet,
            onDismiss: {
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
        ) {
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
        .alert(item: $viewModel.userAlert) { alertContent in  // For general user alerts
            Alert(
                title: Text(alertContent.title),
                message: Text(alertContent.message),
                dismissButton: .default(Text("OK"))
            )
        }
        // Global reset confirmation from toolbar
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
            isPresented: Binding<Bool>(
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

// LaunchScreen recreation as a SwiftUI view
struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Match the AccentColor from the Assets
            Color("AccentColor")
                .ignoresSafeArea()
            
            // Center the logo
            Image("localAI-without-background")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 240, height: 128)
        }
    }
}

// MARK: - Application Main Struct
@main
struct localAI_by_sseApp: App {
    @State private var isLaunchScreenActive = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if !isLaunchScreenActive {
                    ContentView()
                } else {
                    // Recreate the LaunchScreen as a SwiftUI view
                    LaunchScreenView()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: isLaunchScreenActive)
            .task {
                // Delay for 2 seconds before showing the main content
                try? await Task.sleep(for: .seconds(2))
                isLaunchScreenActive = false
            }
        }
    }
}
