//
//  ErrorLoggingService.swift
//  localAI by sse
//
//  Created by sse-97 on 01.06.25.
//

import Foundation
import os.log

// MARK: - Error Logging Service

final class ErrorLoggingService {
    
    // MARK: - Singleton
    static let shared = ErrorLoggingService()
    
    // MARK: - Loggers
    private let errorLogger = Logger(subsystem: "com.sse.localAI", category: "Error")
    private let modelLogger = Logger(subsystem: "com.sse.localAI", category: "Model")
    private let fileLogger = Logger(subsystem: "com.sse.localAI", category: "FileSystem")
    private let llmLogger = Logger(subsystem: "com.sse.localAI", category: "LLM")
    private let uiLogger = Logger(subsystem: "com.sse.localAI", category: "UI")
    private let systemLogger = Logger(subsystem: "com.sse.localAI", category: "System")
    private let validationLogger = Logger(subsystem: "com.sse.localAI", category: "Validation")
    private let networkLogger = Logger(subsystem: "com.sse.localAI", category: "Network")
    
    // MARK: - File Logging
    private let fileManager = FileManager.default
    private var logFileURL: URL? {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent("error_log.txt")
    }
    
    private init() {
        setupFileLogging()
    }
    
    // MARK: - Public Logging Methods
    
    /// Logs an AppError with appropriate categorization
    func log(_ error: AppError, context: [String: String] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let contextString = context.isEmpty ? "" : " | Context: \(formatContext(context))"
        let message = "[\(timestamp)] \(error.errorDescription ?? "Unknown error")\(contextString)"
        
        // Log to appropriate category logger
        let logger = getLogger(for: error.category)
        
        switch error.severity {
        case .low:
            logger.info("\(message, privacy: .public)")
        case .medium:
            logger.notice("\(message, privacy: .public)")
        case .high:
            logger.error("\(message, privacy: .public)")
        case .critical:
            logger.critical("\(message, privacy: .public)")
        }
        
        // Also log to file
        logToFile(message, severity: error.severity)
    }
    
    /// Logs a debug message
    func logDebug(_ message: String, category: ErrorCategory = .system, context: [String: String] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let contextString = context.isEmpty ? "" : " | Context: \(formatContext(context))"
        let logMessage = "[\(timestamp)] DEBUG: \(message)\(contextString)"
        
        let logger = getLogger(for: category)
        logger.debug("\(logMessage, privacy: .public)")
        
        // Don't log debug messages to file in release builds
        #if DEBUG
        logToFile(logMessage, severity: .low)
        #endif
    }
    
    /// Logs an info message
    func logInfo(_ message: String, category: ErrorCategory = .system, context: [String: String] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let contextString = context.isEmpty ? "" : " | Context: \(formatContext(context))"
        let logMessage = "[\(timestamp)] INFO: \(message)\(contextString)"
        
        let logger = getLogger(for: category)
        logger.info("\(logMessage, privacy: .public)")
        
        logToFile(logMessage, severity: .low)
    }
    
    /// Logs a warning message
    func logWarning(_ message: String, category: ErrorCategory = .system, context: [String: String] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let contextString = context.isEmpty ? "" : " | Context: \(formatContext(context))"
        let logMessage = "[\(timestamp)] WARNING: \(message)\(contextString)"
        
        let logger = getLogger(for: category)
        logger.notice("\(logMessage, privacy: .public)")
        
        logToFile(logMessage, severity: .medium)
    }
    
    /// Logs a critical error message
    func logCritical(_ message: String, category: ErrorCategory = .system, context: [String: String] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let contextString = context.isEmpty ? "" : " | Context: \(formatContext(context))"
        let logMessage = "[\(timestamp)] CRITICAL: \(message)\(contextString)"
        
        let logger = getLogger(for: category)
        logger.critical("\(logMessage, privacy: .public)")
        
        logToFile(logMessage, severity: .critical)
    }
    
    // MARK: - File Management
    
    /// Gets the contents of the error log file
    func getLogFileContents() -> String {
        guard let logFileURL = logFileURL,
              fileManager.fileExists(atPath: logFileURL.path) else {
            return "No log file found"
        }
        
        do {
            return try String(contentsOf: logFileURL)
        } catch {
            return "Failed to read log file: \(error.localizedDescription)"
        }
    }
    
    /// Clears the error log file
    func clearLogFile() {
        guard let logFileURL = logFileURL else { return }
        
        do {
            if fileManager.fileExists(atPath: logFileURL.path) {
                try fileManager.removeItem(at: logFileURL)
            }
            setupFileLogging() // Recreate the file
            logInfo("Log file cleared", category: .system)
        } catch {
            errorLogger.error("Failed to clear log file: \(error.localizedDescription)")
        }
    }
    
    /// Gets the size of the log file
    func getLogFileSize() -> String {
        guard let logFileURL = logFileURL,
              let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return "Unknown"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize.int64Value)
    }
    
    /// Exports the log file for sharing
    func exportLogFile() -> URL? {
        guard let logFileURL = logFileURL,
              fileManager.fileExists(atPath: logFileURL.path) else {
            return nil
        }
        
        // Create a timestamped copy for export
        let timestamp = DateFormatter().string(from: Date())
        let exportURL = logFileURL.appendingPathExtension("export_\(timestamp)")
        
        do {
            try fileManager.copyItem(at: logFileURL, to: exportURL)
            return exportURL
        } catch {
            errorLogger.error("Failed to export log file: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func getLogger(for category: ErrorCategory) -> Logger {
        switch category {
        case .model: return modelLogger
        case .file: return fileLogger
        case .llm: return llmLogger
        case .ui: return uiLogger
        case .system: return systemLogger
        case .validation: return validationLogger
        case .network: return networkLogger
        }
    }
    
    private func setupFileLogging() {
        guard let logFileURL = logFileURL else { return }
        
        // Create log file if it doesn't exist
        if !fileManager.fileExists(atPath: logFileURL.path) {
            let initialContent = "=== localAI Error Log ===\nCreated: \(Date())\n\n"
            do {
                try initialContent.write(to: logFileURL, atomically: true, encoding: .utf8)
            } catch {
                errorLogger.error("Failed to create log file: \(error.localizedDescription)")
            }
        }
        
        // Rotate log file if it gets too large (> 10MB)
        if let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
           let fileSize = attributes[.size] as? NSNumber,
           fileSize.int64Value > 10 * 1024 * 1024 {
            rotateLogFile()
        }
    }
    
    private func rotateLogFile() {
        guard let logFileURL = logFileURL else { return }
        
        let timestamp = DateFormatter().string(from: Date())
        let archiveURL = logFileURL.appendingPathExtension("archive_\(timestamp)")
        
        do {
            // Move current log to archive
            try fileManager.moveItem(at: logFileURL, to: archiveURL)
            
            // Create new log file
            setupFileLogging()
            
            logInfo("Log file rotated", category: .system)
        } catch {
            errorLogger.error("Failed to rotate log file: \(error.localizedDescription)")
        }
    }
    
    private func logToFile(_ message: String, severity: ErrorSeverity) {
        guard let logFileURL = logFileURL else { return }
        
        let logEntry = "\(message)\n"
        
        do {
            if fileManager.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logEntry.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            errorLogger.error("Failed to write to log file: \(error.localizedDescription)")
        }
    }
    
    private func formatContext(_ context: [String: String]) -> String {
        return context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }
}

// MARK: - Legacy Migration Support

extension ErrorLoggingService {
    /// Migrates from the old logDebug function to the new logging service
    func logDebugLegacy(_ message: String) {
        logDebug(message, category: .system)
    }
    
    /// Creates a context dictionary from ViewModel state
    func createContextFromViewModel(_ viewModel: ChatViewModel) -> [String: String] {
        return [
            "selectedModel": viewModel.selectedModel?.displayName ?? "None",
            "isGenerating": String(viewModel.isGenerating),
            "isRestarting": String(viewModel.isRestarting),
            "isInitializing": String(viewModel.isInitializing),
            "messageCount": String(viewModel.messages.count),
            "tokenCount": String(viewModel.tokenCount),
            "debugMode": String(viewModel.debugModeEnabled)
        ]
    }
}
