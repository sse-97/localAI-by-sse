//
//  LoadingView.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

/// A loading view displayed during app initialization
struct LoadingView: View {
    let modelInfo: String
    
    var body: some View {
        VStack(spacing: DesignConstants.largePadding) {
            ProgressView()
                .scaleEffect(DesignConstants.progressIndicatorScale)
                .tint(.accentColor)
            
            Text("Loading Model...")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if !modelInfo.isEmpty {
                Text(modelInfo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemBackground)
    }
}
