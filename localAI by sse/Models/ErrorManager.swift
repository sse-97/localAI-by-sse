//
//  ErrorManager.swift
//  localAI by sse
//
//  Created by sse-97 on 01.06.25.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Error Handler Protocol

protocol ErrorHandler {
    func handle(_ error: AppError)
    func handleWithAlert(_ error: AppError) -> UserAlert
    func logError(_ error: AppError)
    func canRecover(from error: AppError) -> Bool
    func suggestRecoveryAction(for error: AppError) -> RecoveryAction?
}

// MARK: - Recovery Actions

enum RecoveryAction: Identifiable, Equatable {
    case retry
    case restart
    case clearData
    case switchModel
    case freeMemory
    case checkPermissions
    case contactSupport
    case updateOS
    case none
    
    var id: String {
        switch self {
        case .retry: return "retry"
        case .restart: return "restart"
        case .clearData: return "clearData"
        case .switchModel: return "switchModel"
        case .freeMemory: return "freeMemory"
        case .checkPermissions: return "checkPermissions"
        case .contactSupport: return "contactSupport"
        case .updateOS: return "updateOS"
        case .none: return "none"
        }
    }
    
    var title: String {
        switch self {
        case .retry: return "Retry"
        case .restart: return "Restart App"
        case .clearData: return "Clear Data"
        case .switchModel: return "Switch Model"
        case .freeMemory: return "Free Memory"
        case .checkPermissions: return "Check Permissions"
        case .contactSupport: return "Contact Support"
        case .updateOS: return "Update OS"
        case .none: return "OK"
        }
    }
    
    var systemImage: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .restart: return "power"
        case .clearData: return "trash"
        case .switchModel: return "switch.2"
        case .freeMemory: return "memorychip"
        case .checkPermissions: return "gear"
        case .contactSupport: return "questionmark.circle"
        case .updateOS: return "arrow.up.circle"
        case .none: return "checkmark"
        }
    }
}

// MARK: - Error Manager

final class ErrorManager: ObservableObject, @preconcurrency ErrorHandler {
    @Published var currentError: AppError?
    @Published var errorHistory: [ErrorLogEntry] = []
    @Published var isShowingErrorAlert: Bool = false
    
    private let logger = Logger(subsystem: "com.sse.localAI", category: "ErrorManager")
    private let maxHistoryEntries = 100
    
    // Singleton instance
    static let shared = ErrorManager()
    
    private init() {
        setupErrorLogging()
    }
    
    // MARK: - Public Interface
    
    @MainActor
    func handle(_ error: AppError) {
        logError(error)
        currentError = error
        
        // Automatically show alert for high and critical severity errors
        if error.severity.rawValue >= ErrorSeverity.high.rawValue {
            isShowingErrorAlert = true
        }
        
        // Log to system for debugging
        logger.error("Error handled: \(error.errorDescription ?? "Unknown error")")
    }
    
    @MainActor
    func handleWithAlert(_ error: AppError) -> UserAlert {
        handle(error)
        isShowingErrorAlert = true
        
        let recoveryAction = suggestRecoveryAction(for: error)
        let message = createUserFriendlyMessage(for: error, recoveryAction: recoveryAction)
        
        return UserAlert(
            title: createUserFriendlyTitle(for: error),
            message: message
        )
    }
    
    func logError(_ error: AppError) {
        let entry = ErrorLogEntry(
            id: UUID(),
            error: error,
            timestamp: Date(),
            context: getCurrentContext()
        )
        
        Task { @MainActor in
            errorHistory.append(entry)
            
            // Trim history if needed
            if errorHistory.count > maxHistoryEntries {
                errorHistory.removeFirst(errorHistory.count - maxHistoryEntries)
            }
        }
    }
    
    func canRecover(from error: AppError) -> Bool {
        switch error.severity {
        case .low, .medium:
            return true
        case .high:
            return suggestRecoveryAction(for: error) != RecoveryAction.none
        case .critical:
            return false
        }
    }
    
    // MARK: - Success Message Handling
    
    /// Creates a success message alert
    @MainActor
    func createSuccessAlert(title: String, message: String) -> UserAlert {
        // Log success for debugging and analytics
        logger.info("Success: \(title) - \(message)")
        
        return UserAlert(
            title: title,
            message: message
        )
    }
    
    func suggestRecoveryAction(for error: AppError) -> RecoveryAction? {
        switch error {
        // Model Loading Errors
        case .modelLoading(let modelError):
            switch modelError {
            case .fileNotFound, .invalidFormat, .corruptedFile:
                return .switchModel
            case .insufficientMemory:
                return .freeMemory
            case .initializationFailed, .unsupportedModelType:
                return .switchModel
            case .bundleResourceMissing:
                return .restart
            case .urlConstructionFailed:
                return .retry
            }
            
        // File System Errors
        case .fileSystem(let fileError):
            switch fileError {
            case .copyFailed, .deleteFailed:
                return .retry
            case .accessDenied:
                return .checkPermissions
            case .diskSpaceInsufficient:
                return .clearData
            case .pathDoesNotExist, .invalidPath:
                return .retry
            case .temporaryFileCreationFailed, .documentPickerFailed:
                return .retry
            }
            
        // LLM Interaction Errors
        case .llmInteraction(let llmError):
            switch llmError {
            case .generationFailed, .stopFailed:
                return .retry
            case .contextOverflow, .historyCorrupted:
                return .clearData
            case .invalidInput, .unexpectedResponse:
                return .retry
            case .modelNotReady:
                return RecoveryAction.none
            case .parametersUpdateFailed:
                return .retry
            }
            
        // UI Errors
        case .userInterface:
            return .retry
            
        // System Errors
        case .system(let systemError):
            switch systemError {
            case .osVersionIncompatible, .deviceUnsupported:
                return .updateOS
            case .memoryPressureHigh:
                return .freeMemory
            case .storageSpaceLow:
                return .clearData
            case .permissionDenied:
                return .checkPermissions
            case .backgroundTaskFailed:
                return .restart
            case .dataCorruption:
                return .clearData
            }
            
        // Validation Errors
        case .validation:
            return .retry
            
        // Network Errors
        case .network:
            return .retry
        }
    }
    
    // MARK: - User-Friendly Messages
    
    private func createUserFriendlyTitle(for error: AppError) -> String {
        switch error.category {
        case .model:
            return "Model Issue"
        case .file:
            return "File Error"
        case .llm:
            return "Generation Error"
        case .ui:
            return "Interface Error"
        case .system:
            return "System Error"
        case .validation:
            return "Input Error"
        case .network:
            return "Connection Error"
        }
    }
    
    private func createUserFriendlyMessage(for error: AppError, recoveryAction: RecoveryAction?) -> String {
        var message = error.errorDescription ?? "An unknown error occurred."
        
        if let recoverySuggestion = error.recoverySuggestion {
            message += "\n\n\(recoverySuggestion)"
        }
        
        if let action = recoveryAction, action != .none {
            message += "\n\nSuggested action: \(action.title)"
        }
        
        return message
    }
    
    // MARK: - Context and Logging
    
    private func getCurrentContext() -> ErrorContext {
        // This would collect current app state for debugging
        return ErrorContext(
            timestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            availableMemory: getAvailableMemory(),
            diskSpace: getAvailableDiskSpace()
        )
    }
    
    private func getAvailableMemory() -> String {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(memoryInfo.resident_size) / 1024.0 / 1024.0 / 1024.0
            return String(format: "%.2f GB used", usedMemory)
        }
        
        return "Unknown"
    }
    
    private func getAvailableDiskSpace() -> String {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSize = attributes[.systemFreeSize] as? NSNumber {
                let freeSpaceGB = Double(freeSize.int64Value) / 1024.0 / 1024.0 / 1024.0
                return String(format: "%.2f GB free", freeSpaceGB)
            }
        } catch {
            return "Unknown"
        }
        return "Unknown"
    }
    
    private func setupErrorLogging() {
        // Setup any additional error logging (crash reporting, analytics, etc.)
        logger.info("Error Manager initialized")
    }
    
    // MARK: - Debug Functions
    
    func getErrorSummary() -> String {
        let errorCounts = Dictionary(grouping: errorHistory) { $0.error.category }
            .mapValues { $0.count }
        
        var summary = "Error Summary:\n"
        for (category, count) in errorCounts.sorted(by: { $0.value > $1.value }) {
            summary += "\(category.rawValue): \(count)\n"
        }
        
        return summary
    }
    
    @MainActor
    func clearErrorHistory() {
        errorHistory.removeAll()
        logger.info("Error history cleared")
    }
    
    func exportErrorLog() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(errorHistory)
            return String(data: data, encoding: .utf8) ?? "Failed to encode error log"
        } catch {
            return "Failed to export error log: \(error.localizedDescription)"
        }
    }
}

// MARK: - Error Context

struct ErrorContext: Codable {
    let timestamp: Date
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let availableMemory: String
    let diskSpace: String
}

// MARK: - Error Log Entry

struct ErrorLogEntry: Identifiable, Codable {
    let id: UUID
    let error: AppError
    let timestamp: Date
    let context: ErrorContext
}
