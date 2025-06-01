//
//  localAI_by_sseApp.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

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
