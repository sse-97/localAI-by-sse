//
//  ErrorTypes.swift
//  localAI by sse
//
//  Created by sse-97 on 01.06.25.
//

import Foundation

// MARK: - App Error Types

/// Comprehensive error types for the localAI application
enum AppError: LocalizedError, Identifiable, Equatable {
    case modelLoading(ModelLoadingError)
    case fileSystem(FileSystemError)
    case llmInteraction(LLMInteractionError)
    case userInterface(UIError)
    case system(SystemError)
    case validation(ValidationError)
    case network(NetworkError)
    
    var id: String {
        switch self {
        case .modelLoading(let error): return "modelLoading_\(error.id)"
        case .fileSystem(let error): return "fileSystem_\(error.id)"
        case .llmInteraction(let error): return "llmInteraction_\(error.id)"
        case .userInterface(let error): return "userInterface_\(error.id)"
        case .system(let error): return "system_\(error.id)"
        case .validation(let error): return "validation_\(error.id)"
        case .network(let error): return "network_\(error.id)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .modelLoading(let error): return error.errorDescription
        case .fileSystem(let error): return error.errorDescription
        case .llmInteraction(let error): return error.errorDescription
        case .userInterface(let error): return error.errorDescription
        case .system(let error): return error.errorDescription
        case .validation(let error): return error.errorDescription
        case .network(let error): return error.errorDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelLoading(let error): return error.recoverySuggestion
        case .fileSystem(let error): return error.recoverySuggestion
        case .llmInteraction(let error): return error.recoverySuggestion
        case .userInterface(let error): return error.recoverySuggestion
        case .system(let error): return error.recoverySuggestion
        case .validation(let error): return error.recoverySuggestion
        case .network(let error): return error.recoverySuggestion
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .modelLoading(let error): return error.severity
        case .fileSystem(let error): return error.severity
        case .llmInteraction(let error): return error.severity
        case .userInterface(let error): return error.severity
        case .system(let error): return error.severity
        case .validation(let error): return error.severity
        case .network(let error): return error.severity
        }
    }
    
    var category: ErrorCategory {
        switch self {
        case .modelLoading: return .model
        case .fileSystem: return .file
        case .llmInteraction: return .llm
        case .userInterface: return .ui
        case .system: return .system
        case .validation: return .validation
        case .network: return .network
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity: Int, CaseIterable {
    case low = 1        // Minor issues, app continues normally
    case medium = 2     // Noticeable issues, some functionality affected
    case high = 3       // Significant issues, major functionality affected
    case critical = 4   // App-breaking issues, requires immediate action
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Error Categories

enum ErrorCategory: String, CaseIterable {
    case model = "Model"
    case file = "File System"
    case llm = "LLM Interaction"
    case ui = "User Interface"
    case system = "System"
    case validation = "Validation"
    case network = "Network"
}

// MARK: - Model Loading Errors

enum ModelLoadingError: LocalizedError, Identifiable, Equatable {
    case fileNotFound(filename: String)
    case invalidFormat(filename: String)
    case corruptedFile(filename: String)
    case insufficientMemory(requiredMemory: String)
    case initializationFailed(reason: String)
    case unsupportedModelType(type: String)
    case bundleResourceMissing(resourceName: String)
    case urlConstructionFailed(filename: String)
    
    var id: String {
        switch self {
        case .fileNotFound(let filename): return "fileNotFound_\(filename)"
        case .invalidFormat(let filename): return "invalidFormat_\(filename)"
        case .corruptedFile(let filename): return "corruptedFile_\(filename)"
        case .insufficientMemory(let memory): return "insufficientMemory_\(memory)"
        case .initializationFailed(let reason): return "initializationFailed_\(reason)"
        case .unsupportedModelType(let type): return "unsupportedModelType_\(type)"
        case .bundleResourceMissing(let resource): return "bundleResourceMissing_\(resource)"
        case .urlConstructionFailed(let filename): return "urlConstructionFailed_\(filename)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "Model file '\(filename)' could not be found."
        case .invalidFormat(let filename):
            return "Model file '\(filename)' has an invalid format."
        case .corruptedFile(let filename):
            return "Model file '\(filename)' appears to be corrupted."
        case .insufficientMemory(let requiredMemory):
            return "Insufficient memory to load model. Required: \(requiredMemory)"
        case .initializationFailed(let reason):
            return "Failed to initialize model: \(reason)"
        case .unsupportedModelType(let type):
            return "Unsupported model type: \(type)"
        case .bundleResourceMissing(let resourceName):
            return "Required bundle resource '\(resourceName)' is missing."
        case .urlConstructionFailed(let filename):
            return "Failed to construct URL for model file '\(filename)'."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please ensure the model file exists and try again."
        case .invalidFormat:
            return "Please use a valid GGUF model file."
        case .corruptedFile:
            return "Please re-download the model file or choose a different model."
        case .insufficientMemory:
            return "Try closing other apps or using a smaller model."
        case .initializationFailed:
            return "Try restarting the app or choosing a different model."
        case .unsupportedModelType:
            return "Please use a supported GGUF model file."
        case .bundleResourceMissing:
            return "Please reinstall the application."
        case .urlConstructionFailed:
            return "Please check the model filename and try again."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .fileNotFound, .invalidFormat, .corruptedFile:
            return .high
        case .insufficientMemory, .initializationFailed:
            return .critical
        case .unsupportedModelType:
            return .medium
        case .bundleResourceMissing, .urlConstructionFailed:
            return .critical
        }
    }
}

// MARK: - File System Errors

enum FileSystemError: LocalizedError, Identifiable, Equatable {
    case copyFailed(source: String, destination: String, reason: String)
    case deleteFailed(path: String, reason: String)
    case accessDenied(path: String)
    case diskSpaceInsufficient(requiredSpace: String)
    case pathDoesNotExist(path: String)
    case invalidPath(path: String)
    case temporaryFileCreationFailed
    case documentPickerFailed(reason: String)
    
    var id: String {
        switch self {
        case .copyFailed(let source, let destination, _): 
            return "copyFailed_\(source)_\(destination)"
        case .deleteFailed(let path, _): 
            return "deleteFailed_\(path)"
        case .accessDenied(let path): 
            return "accessDenied_\(path)"
        case .diskSpaceInsufficient(let space): 
            return "diskSpaceInsufficient_\(space)"
        case .pathDoesNotExist(let path): 
            return "pathDoesNotExist_\(path)"
        case .invalidPath(let path): 
            return "invalidPath_\(path)"
        case .temporaryFileCreationFailed: 
            return "temporaryFileCreationFailed"
        case .documentPickerFailed(let reason): 
            return "documentPickerFailed_\(reason)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .copyFailed(let source, let destination, let reason):
            return "Failed to copy file from '\(source)' to '\(destination)': \(reason)"
        case .deleteFailed(let path, let reason):
            return "Failed to delete file at '\(path)': \(reason)"
        case .accessDenied(let path):
            return "Access denied to file at '\(path)'"
        case .diskSpaceInsufficient(let requiredSpace):
            return "Insufficient disk space. Required: \(requiredSpace)"
        case .pathDoesNotExist(let path):
            return "Path does not exist: '\(path)'"
        case .invalidPath(let path):
            return "Invalid file path: '\(path)'"
        case .temporaryFileCreationFailed:
            return "Failed to create temporary file"
        case .documentPickerFailed(let reason):
            return "Document picker failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .copyFailed:
            return "Please ensure sufficient disk space and try again."
        case .deleteFailed:
            return "Please check file permissions and try again."
        case .accessDenied:
            return "Please grant necessary file permissions."
        case .diskSpaceInsufficient:
            return "Free up disk space and try again."
        case .pathDoesNotExist:
            return "Please verify the file path and try again."
        case .invalidPath:
            return "Please provide a valid file path."
        case .temporaryFileCreationFailed:
            return "Please restart the app and try again."
        case .documentPickerFailed:
            return "Please try selecting the file again."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .copyFailed, .deleteFailed:
            return .high
        case .accessDenied, .diskSpaceInsufficient:
            return .critical
        case .pathDoesNotExist, .invalidPath:
            return .medium
        case .temporaryFileCreationFailed, .documentPickerFailed:
            return .medium
        }
    }
}

// MARK: - LLM Interaction Errors

enum LLMInteractionError: LocalizedError, Identifiable, Equatable {
    case generationFailed(reason: String)
    case stopFailed
    case contextOverflow(currentTokens: Int, maxTokens: Int)
    case invalidInput(reason: String)
    case modelNotReady
    case parametersUpdateFailed(reason: String)
    case historyCorrupted
    case unexpectedResponse(response: String)
    
    var id: String {
        switch self {
        case .generationFailed(let reason): return "generationFailed_\(reason)"
        case .stopFailed: return "stopFailed"
        case .contextOverflow(let current, let max): return "contextOverflow_\(current)_\(max)"
        case .invalidInput(let reason): return "invalidInput_\(reason)"
        case .modelNotReady: return "modelNotReady"
        case .parametersUpdateFailed(let reason): return "parametersUpdateFailed_\(reason)"
        case .historyCorrupted: return "historyCorrupted"
        case .unexpectedResponse(let response): return "unexpectedResponse_\(response.prefix(50))"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .stopFailed:
            return "Failed to stop text generation"
        case .contextOverflow(let currentTokens, let maxTokens):
            return "Context overflow: \(currentTokens) tokens exceeds maximum of \(maxTokens)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .modelNotReady:
            return "Model is not ready for interaction"
        case .parametersUpdateFailed(let reason):
            return "Failed to update model parameters: \(reason)"
        case .historyCorrupted:
            return "Conversation history is corrupted"
        case .unexpectedResponse(let response):
            return "Received unexpected response: \(response.prefix(100))"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .generationFailed:
            return "Please try again or restart the model."
        case .stopFailed:
            return "Please wait for generation to complete or restart the app."
        case .contextOverflow:
            return "Clear conversation history or reduce input length."
        case .invalidInput:
            return "Please check your input and try again."
        case .modelNotReady:
            return "Please wait for the model to finish loading."
        case .parametersUpdateFailed:
            return "Please check parameter values and try again."
        case .historyCorrupted:
            return "Clear conversation history to continue."
        case .unexpectedResponse:
            return "Please try again with a different input."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .generationFailed, .stopFailed:
            return .medium
        case .contextOverflow:
            return .low
        case .invalidInput:
            return .low
        case .modelNotReady:
            return .low
        case .parametersUpdateFailed:
            return .medium
        case .historyCorrupted:
            return .high
        case .unexpectedResponse:
            return .low
        }
    }
}

// MARK: - User Interface Errors

enum UIError: LocalizedError, Identifiable, Equatable {
    case invalidState(component: String, state: String)
    case navigationFailed(destination: String)
    case alertPresentationFailed
    case sheetPresentationFailed
    case clipboardAccessFailed
    case focusManagementFailed
    case animationFailed(animation: String)
    
    var id: String {
        switch self {
        case .invalidState(let component, let state): return "invalidState_\(component)_\(state)"
        case .navigationFailed(let destination): return "navigationFailed_\(destination)"
        case .alertPresentationFailed: return "alertPresentationFailed"
        case .sheetPresentationFailed: return "sheetPresentationFailed"
        case .clipboardAccessFailed: return "clipboardAccessFailed"
        case .focusManagementFailed: return "focusManagementFailed"
        case .animationFailed(let animation): return "animationFailed_\(animation)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidState(let component, let state):
            return "Invalid state for \(component): \(state)"
        case .navigationFailed(let destination):
            return "Failed to navigate to \(destination)"
        case .alertPresentationFailed:
            return "Failed to present alert"
        case .sheetPresentationFailed:
            return "Failed to present sheet"
        case .clipboardAccessFailed:
            return "Failed to access clipboard"
        case .focusManagementFailed:
            return "Failed to manage focus"
        case .animationFailed(let animation):
            return "Animation failed: \(animation)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidState:
            return "Please restart the app."
        case .navigationFailed:
            return "Please try again."
        case .alertPresentationFailed:
            return "Please try again."
        case .sheetPresentationFailed:
            return "Please try again."
        case .clipboardAccessFailed:
            return "Please check app permissions."
        case .focusManagementFailed:
            return "Please tap to focus manually."
        case .animationFailed:
            return "Animation will be skipped."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .invalidState:
            return .high
        case .navigationFailed, .alertPresentationFailed, .sheetPresentationFailed:
            return .medium
        case .clipboardAccessFailed, .focusManagementFailed, .animationFailed:
            return .low
        }
    }
}

// MARK: - System Errors

enum SystemError: LocalizedError, Identifiable, Equatable {
    case osVersionIncompatible(required: String, current: String)
    case memoryPressureHigh
    case storageSpaceLow(available: String)
    case permissionDenied(permission: String)
    case deviceUnsupported(reason: String)
    case backgroundTaskFailed(task: String)
    case dataCorruption(dataType: String, details: String)
    
    var id: String {
        switch self {
        case .osVersionIncompatible(let required, let current): 
            return "osVersionIncompatible_\(required)_\(current)"
        case .memoryPressureHigh: 
            return "memoryPressureHigh"
        case .storageSpaceLow(let available): 
            return "storageSpaceLow_\(available)"
        case .permissionDenied(let permission): 
            return "permissionDenied_\(permission)"
        case .deviceUnsupported(let reason): 
            return "deviceUnsupported_\(reason)"
        case .backgroundTaskFailed(let task): 
            return "backgroundTaskFailed_\(task)"
        case .dataCorruption(let dataType, let details): 
            return "dataCorruption_\(dataType)_\(details.hashValue)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .osVersionIncompatible(let required, let current):
            return "OS version incompatible. Required: \(required), Current: \(current)"
        case .memoryPressureHigh:
            return "Device is experiencing high memory pressure"
        case .storageSpaceLow(let available):
            return "Storage space is low. Available: \(available)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .deviceUnsupported(let reason):
            return "Device is not supported: \(reason)"
        case .backgroundTaskFailed(let task):
            return "Background task failed: \(task)"
        case .dataCorruption(let dataType, let details):
            return "Data corruption detected in \(dataType): \(details)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .osVersionIncompatible:
            return "Please update your device to the required OS version."
        case .memoryPressureHigh:
            return "Please close other apps to free up memory."
        case .storageSpaceLow:
            return "Please free up storage space on your device."
        case .permissionDenied:
            return "Please grant the required permission in Settings."
        case .deviceUnsupported:
            return "This app is not compatible with your device."
        case .backgroundTaskFailed:
            return "Please ensure the app has background processing permissions."
        case .dataCorruption:
            return "The app will attempt to reset this data. If issues persist, try restarting the app."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .osVersionIncompatible, .deviceUnsupported:
            return .critical
        case .memoryPressureHigh, .storageSpaceLow:
            return .high
        case .permissionDenied, .backgroundTaskFailed:
            return .medium
        case .dataCorruption:
            return .medium
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError, Identifiable, Equatable {
    case emptyInput(field: String)
    case invalidFormat(field: String, expected: String)
    case outOfRange(field: String, min: String, max: String, actual: String)
    case duplicateValue(field: String, value: String)
    case invalidCharacters(field: String, invalidChars: String)
    case fileSizeTooLarge(filename: String, size: String, maxSize: String)
    case fileSizeTooSmall(filename: String, size: String, minSize: String)
    
    var id: String {
        switch self {
        case .emptyInput(let field): return "emptyInput_\(field)"
        case .invalidFormat(let field, let expected): return "invalidFormat_\(field)_\(expected)"
        case .outOfRange(let field, let min, let max, let actual): 
            return "outOfRange_\(field)_\(min)_\(max)_\(actual)"
        case .duplicateValue(let field, let value): return "duplicateValue_\(field)_\(value)"
        case .invalidCharacters(let field, let chars): return "invalidCharacters_\(field)_\(chars)"
        case .fileSizeTooLarge(let filename, let size, let maxSize): 
            return "fileSizeTooLarge_\(filename)_\(size)_\(maxSize)"
        case .fileSizeTooSmall(let filename, let size, let minSize): 
            return "fileSizeTooSmall_\(filename)_\(size)_\(minSize)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .emptyInput(let field):
            return "\(field) cannot be empty"
        case .invalidFormat(let field, let expected):
            return "\(field) has an invalid format. Expected: \(expected)"
        case .outOfRange(let field, let min, let max, let actual):
            return "\(field) value \(actual) is out of range (\(min)-\(max))"
        case .duplicateValue(let field, let value):
            return "\(field) value '\(value)' already exists"
        case .invalidCharacters(let field, let invalidChars):
            return "\(field) contains invalid characters: \(invalidChars)"
        case .fileSizeTooLarge(let filename, let size, let maxSize):
            return "File '\(filename)' (\(size)) exceeds maximum size (\(maxSize))"
        case .fileSizeTooSmall(let filename, let size, let minSize):
            return "File '\(filename)' (\(size)) is below minimum size (\(minSize))"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyInput:
            return "Please provide a value for this field."
        case .invalidFormat:
            return "Please enter the value in the correct format."
        case .outOfRange:
            return "Please enter a value within the allowed range."
        case .duplicateValue:
            return "Please choose a unique value."
        case .invalidCharacters:
            return "Please remove the invalid characters."
        case .fileSizeTooLarge:
            return "Please choose a smaller file."
        case .fileSizeTooSmall:
            return "Please choose a larger file."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .emptyInput, .invalidFormat, .outOfRange, .duplicateValue, .invalidCharacters:
            return .low
        case .fileSizeTooLarge, .fileSizeTooSmall:
            return .medium
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError, Identifiable, Equatable {
    case noConnection
    case timeout(duration: String)
    case invalidResponse(statusCode: Int)
    case dataCorrupted
    case urlInvalid(url: String)
    case downloadFailed(url: String, reason: String)
    case uploadFailed(reason: String)
    
    var id: String {
        switch self {
        case .noConnection: return "noConnection"
        case .timeout(let duration): return "timeout_\(duration)"
        case .invalidResponse(let statusCode): return "invalidResponse_\(statusCode)"
        case .dataCorrupted: return "dataCorrupted"
        case .urlInvalid(let url): return "urlInvalid_\(url)"
        case .downloadFailed(let url, let reason): return "downloadFailed_\(url)_\(reason)"
        case .uploadFailed(let reason): return "uploadFailed_\(reason)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .timeout(let duration):
            return "Request timed out after \(duration)"
        case .invalidResponse(let statusCode):
            return "Invalid response (Status: \(statusCode))"
        case .dataCorrupted:
            return "Received data is corrupted"
        case .urlInvalid(let url):
            return "Invalid URL: \(url)"
        case .downloadFailed(let url, let reason):
            return "Failed to download from \(url): \(reason)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Please check your internet connection and try again."
        case .timeout:
            return "Please check your connection and try again."
        case .invalidResponse:
            return "Please try again later."
        case .dataCorrupted:
            return "Please try downloading again."
        case .urlInvalid:
            return "Please check the URL and try again."
        case .downloadFailed:
            return "Please check your connection and try again."
        case .uploadFailed:
            return "Please check your connection and try again."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .noConnection:
            return .high
        case .timeout, .invalidResponse:
            return .medium
        case .dataCorrupted, .urlInvalid, .downloadFailed, .uploadFailed:
            return .medium
        }
    }
}

// MARK: - Codable Extensions

extension AppError: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case modelLoading
        case fileSystem
        case llmInteraction
        case userInterface
        case system
        case validation
        case network
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "modelLoading":
            let modelError = try container.decode(ModelLoadingError.self, forKey: .modelLoading)
            self = .modelLoading(modelError)
        case "fileSystem":
            let fileError = try container.decode(FileSystemError.self, forKey: .fileSystem)
            self = .fileSystem(fileError)
        case "llmInteraction":
            let llmError = try container.decode(LLMInteractionError.self, forKey: .llmInteraction)
            self = .llmInteraction(llmError)
        case "userInterface":
            let uiError = try container.decode(UIError.self, forKey: .userInterface)
            self = .userInterface(uiError)
        case "system":
            let systemError = try container.decode(SystemError.self, forKey: .system)
            self = .system(systemError)
        case "validation":
            let validationError = try container.decode(ValidationError.self, forKey: .validation)
            self = .validation(validationError)
        case "network":
            let networkError = try container.decode(NetworkError.self, forKey: .network)
            self = .network(networkError)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown error type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .modelLoading(let error):
            try container.encode("modelLoading", forKey: .type)
            try container.encode(error, forKey: .modelLoading)
        case .fileSystem(let error):
            try container.encode("fileSystem", forKey: .type)
            try container.encode(error, forKey: .fileSystem)
        case .llmInteraction(let error):
            try container.encode("llmInteraction", forKey: .type)
            try container.encode(error, forKey: .llmInteraction)
        case .userInterface(let error):
            try container.encode("userInterface", forKey: .type)
            try container.encode(error, forKey: .userInterface)
        case .system(let error):
            try container.encode("system", forKey: .type)
            try container.encode(error, forKey: .system)
        case .validation(let error):
            try container.encode("validation", forKey: .type)
            try container.encode(error, forKey: .validation)
        case .network(let error):
            try container.encode("network", forKey: .type)
            try container.encode(error, forKey: .network)
        }
    }
}

// Codable conformance for all error types
extension ModelLoadingError: Codable {}
extension FileSystemError: Codable {}
extension LLMInteractionError: Codable {}
extension UIError: Codable {}
extension SystemError: Codable {}
extension ValidationError: Codable {}
extension NetworkError: Codable {}
