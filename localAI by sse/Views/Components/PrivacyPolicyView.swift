//
//  PrivacyPolicyView.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

/// Privacy Policy View - Added for App Store compliance
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Last Updated: May 17, 2024")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Introduction")
                        .font(.headline)
                    
                    Text(
                        "localAI is committed to protecting your privacy. This Privacy Policy explains how our application collects, uses, and safeguards information when you use our mobile application."
                    )
                }
                
                Group {
                    Text("Summary")
                        .font(.headline)
                    
                    Text(
                        "**localAI processes all data locally on your device.** The app does not collect, transmit, store, or share any personal information or conversation data with external servers or third parties."
                    )
                }
                
                Group {
                    Text("Information Collection and Use")
                        .font(.headline)
                    
                    Text("Local Processing")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(
                        "• All AI inference occurs entirely on your device\n• Conversations with the AI remain on your device and are never transmitted externally\n• No user data is uploaded to remote servers\n• No analytics or telemetry data is collected"
                    )
                }
                
                Group {
                    Text("User-Added Models")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(
                        "When you import custom models:\n• Model files are stored locally in your device's storage within the app's sandbox\n• These files are never uploaded to external servers\n• The app does not analyze the content of your model files beyond what's necessary for functionality"
                    )
                }
                
                Group {
                    Text("Permissions")
                        .font(.headline)
                    
                    Text("File Access")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(
                        "localAI requests access to documents only when you explicitly choose to import custom models. We only access files you specifically select, and we do not scan or index any other files on your device."
                    )
                }
                
                Group {
                    Text("Data Security")
                        .font(.headline)
                    
                    Text(
                        "Since all data is processed locally on your device, data security is maintained through your device's built-in security features. We recommend using a device password/PIN and keeping your iOS up to date."
                    )
                }
                
                Group {
                    Text("Your Choices")
                        .font(.headline)
                    
                    Text(
                        "You can delete conversations and imported models at any time through the app's interface. If you wish to remove all app data, you can uninstall the application."
                    )
                }
                
                Group {
                    Text("Contact Information")
                        .font(.headline)
                    
                    Text(
                        "If you have questions or concerns about our privacy practices, please open an issue on our GitHub repository at https://github.com/sse-97/localAI-by-sse."
                    )
                    .padding(.bottom, 20)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}
