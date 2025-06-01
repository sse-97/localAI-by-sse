//
//  LaunchScreenView.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

/// LaunchScreen recreation as a SwiftUI view
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
