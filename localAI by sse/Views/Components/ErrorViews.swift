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
