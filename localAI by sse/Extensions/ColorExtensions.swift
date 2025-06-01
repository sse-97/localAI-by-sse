//
//  ColorExtensions.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import SwiftUI
import UIKit

// MARK: - UI Color Extensions

/// Extends `Color` to provide platform-agnostic system colors.
extension Color {
    static var systemBackground: Color {
        Color(UIColor.systemBackground)
    }
    
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
