//
//  DocumentPicker.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL, String) -> Void
    
    // Define GGUF type for better filtering if possible
    // Note: This custom UTType might not be universally recognized unless the app registers it.
    // Using .data or a known extension-based type is safer if this doesn't work as expected.
    private static let ggufType = UTType(filenameExtension: "gguf", conformingTo: .data) ?? .data
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
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
            let shouldStopAccessing = pickedURL.startAccessingSecurityScopedResource()
            
            // The `asCopy: true` in UIDocumentPickerViewController constructor usually handles copying
            // to a temporary location, so direct access here should be to that temporary copy.
            // However, it's good practice to be mindful of security-scoped URLs.
            
            let originalFilename = pickedURL.lastPathComponent
            
            parent.onDocumentPicked(pickedURL, originalFilename)
            
            if shouldStopAccessing {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled the picker, nothing to do here as no file was picked.
        }
    }
}
