//
//  ErrorViews.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

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

/// Enhanced error view that works with the centralized error system
struct EnhancedErrorView: View {
    let error: AppError
    let onRecovery: ((RecoveryAction) -> Void)?
    let onDismiss: (() -> Void)?
    
    @StateObject private var errorManager = ErrorManager.shared
    
    var body: some View {
        VStack(spacing: DesignConstants.largePadding) {
            Spacer()
            
            // Error icon based on severity
            errorIcon
                .font(.system(size: 60))
                .foregroundColor(errorColor)
                .padding()
            
            // Error title
            Text(errorTitle)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Error description
            Text(error.errorDescription ?? "An unknown error occurred.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Recovery suggestion
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, DesignConstants.smallPadding)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: DesignConstants.mediumPadding) {
                if let recoveryAction = errorManager.suggestRecoveryAction(for: error),
                   recoveryAction != .none,
                   let onRecovery = onRecovery {
                    Button(action: { onRecovery(recoveryAction) }) {
                        HStack {
                            Image(systemName: recoveryAction.systemImage)
                            Text(recoveryAction.title)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if let onDismiss = onDismiss {
                    Button("Dismiss", action: onDismiss)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorIcon: Image {
        switch error.severity {
        case .low:
            return Image(systemName: "info.circle.fill")
        case .medium:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .high:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .critical:
            return Image(systemName: "xmark.octagon.fill")
        }
    }
    
    private var errorColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .red
        }
    }
    
    private var errorTitle: String {
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
}

/// Compact error banner for non-critical errors
struct ErrorBannerView: View {
    let error: AppError
    let onDismiss: (() -> Void)?
    let onRetry: ((RecoveryAction) -> Void)?
    
    @StateObject private var errorManager = ErrorManager.shared
    
    var body: some View {
        HStack(spacing: DesignConstants.mediumPadding) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(errorColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(errorTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(error.errorDescription ?? "An error occurred")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Show retry button if there's a recovery action available
            if let recoveryAction = errorManager.suggestRecoveryAction(for: error),
               recoveryAction != .none,
               let onRetry = onRetry {
                Button(action: { onRetry(recoveryAction) }) {
                    HStack(spacing: 4) {
                        Image(systemName: recoveryAction.systemImage)
                            .font(.caption)
                        Text(recoveryAction.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                }
            }
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(DesignConstants.mediumPadding)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignConstants.smallPadding)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var errorColor: Color {
        switch error.severity {
        case .low: return .blue
        case .medium: return .orange
        case .high, .critical: return .red
        }
    }
    
    private var errorTitle: String {
        switch error.category {
        case .model: return "Model Issue"
        case .file: return "File Error"
        case .llm: return "Generation Error"
        case .ui: return "Interface Error"
        case .system: return "System Error"
        case .validation: return "Input Error"
        case .network: return "Connection Error"
        }
    }
}

/// Error overlay for in-app errors
struct ErrorOverlayView: View {
    let error: AppError
    let onRecovery: ((RecoveryAction) -> Void)?
    let onDismiss: () -> Void
    
    @StateObject private var errorManager = ErrorManager.shared
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: DesignConstants.largePadding) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(errorTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(error.errorDescription ?? "An error occurred")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: DesignConstants.mediumPadding) {
                    if let recoveryAction = errorManager.suggestRecoveryAction(for: error),
                       recoveryAction != .none,
                       let onRecovery = onRecovery {
                        Button(action: { onRecovery(recoveryAction) }) {
                            HStack {
                                Image(systemName: recoveryAction.systemImage)
                                Text(recoveryAction.title)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("Cancel", action: onDismiss)
                        .buttonStyle(.bordered)
                }
            }
            .padding(DesignConstants.largePadding)
            .background(Color.systemBackground)
            .cornerRadius(DesignConstants.messageBubbleCornerRadius)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, DesignConstants.largePadding)
        }
    }
    
    private var errorTitle: String {
        switch error.category {
        case .model: return "Model Issue"
        case .file: return "File Error"
        case .llm: return "Generation Error"
        case .ui: return "Interface Error"
        case .system: return "System Error"
        case .validation: return "Input Error"
        case .network: return "Connection Error"
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
