//
//  SystemMonitorView.swift
//  localAI by sse
//
//  Created by GitHub Copilot on 25.05.25.
//

import SwiftUI

/// A view displaying system performance metrics, context usage, and debug information.
struct SystemMonitorView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            List {
                currentModelSection
                performanceMetricsSection
                contextUsageSection
                debugLogSection
            }
            .navigationTitle("System Monitor")
        }
    }
    
    private var currentModelSection: some View {
        Section(header: Text("Current Model")) {
            if let selectedModel = viewModel.selectedModel {
                metricRow(
                    title: "Model Name",
                    value: selectedModel.displayName
                )
                metricRow(
                    title: "Model File",
                    value: selectedModel.filename
                )
                metricRow(
                    title: "Model Type",
                    value: selectedModel.isUserAdded ? "Custom" : "Bundled"
                )
                if let templateType = selectedModel.templateType {
                    metricRow(
                        title: "Template",
                        value: templateType.rawValue
                    )
                }
            } else {
                Text("No model selected")
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text("Model Status").font(.subheadline)
                if viewModel.isInitializing {
                    Label("Initializing...", systemImage: "gear")
                        .foregroundColor(.orange)
                } else if viewModel.isRestarting {
                    Label("Restarting...", systemImage: "arrow.clockwise")
                        .foregroundColor(.orange)
                } else if viewModel.llm != nil {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Not Available", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, DesignConstants.smallPadding)
        }
    }
    
    private var performanceMetricsSection: some View {
        Section(header: Text("Performance Metrics")) {
            metricRow(
                title: "Generation Speed",
                value: "\(String(format: "%.1f", viewModel.generationSpeed)) tokens/sec"
            )
            .accessibilityLabel(
                "Generation speed: \(String(format: "%.1f", viewModel.generationSpeed)) tokens per second"
            )
            metricRow(
                title: "Generated Tokens",
                value: "\(viewModel.generatedTokens)"
            )
            .accessibilityLabel(
                "Total generated tokens: \(viewModel.generatedTokens)"
            )
        }
    }
    
    private var contextUsageSection: some View {
        Section(header: Text("Context Usage")) {
            metricRow(
                title: "Token count (history)",
                value: "\(viewModel.tokenCount)"
            )
            .accessibilityLabel(
                "Current token count in history: \(viewModel.tokenCount)"
            )
            VStack(alignment: .leading) {
                HStack {
                    Text("Context usage")
                    Spacer()
                    Text("\(Int(viewModel.contextUsage * 100))%")
                        .foregroundColor(.secondary)
                }
                ProgressView(value: viewModel.contextUsage)
                    .progressViewStyle(.linear)
                    .tint(
                        viewModel.contextUsage > 0.9
                        ? .red
                        : viewModel.contextUsage > 0.7
                        ? .orange : .accentColor
                    )
                    .accessibilityLabel(
                        "Context usage \(Int(viewModel.contextUsage * 100)) percent"
                    )
            }
            metricRow(
                title: "History entries (pairs)",
                value: "\((viewModel.llm?.history.count ?? 0) / 2)"
            )
            .accessibilityLabel(
                "Number of user and bot message exchanges in history: \((viewModel.llm?.history.count ?? 0) / 2)"
            )
        }
    }
    
    private var debugLogSection: some View {
        Section(header: Text("Debug Log")) {
            Toggle(
                "Enable Debug Logging",
                isOn: $viewModel.debugModeEnabled.animation()
            )
            .onChange(of: viewModel.debugModeEnabled) { _, newValue in
                viewModel.logDebug(
                    "--- Debug mode \(newValue ? "enabled" : "disabled") by user (Monitor View) ---"
                )
            }
            if viewModel.debugModeEnabled {
                debugControls
                debugLogView
            }
        }
    }
    
    private var debugControls: some View {
        HStack {
            Toggle("Auto-scroll Log", isOn: $viewModel.shouldAutoScrollDebug)
            Spacer()
            Button(action: { viewModel.clearDebugInfo() }) {
                Label("Clear Log", systemImage: "trash")
            }
            .disabled(viewModel.debugInfo.isEmpty)
            Button {
                viewModel.copyToClipboard(viewModel.debugInfo)
            } label: {
                Label("Copy Log", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.debugInfo.isEmpty)
        }
        .padding(.vertical, DesignConstants.smallPadding)
    }
    
    private var debugLogView: some View {
        Group {
            if !viewModel.debugInfo.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(viewModel.debugInfo)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(DesignConstants.mediumPadding)
                            .background(Color.systemGray6.opacity(0.5))
                            .cornerRadius(DesignConstants.smallPadding)
                            .id("debugTextEnd")  // Anchor for scrolling
                    }
                    .frame(height: DesignConstants.debugLogHeight)
                    .onChange(of: viewModel.debugInfo) { _, _ in  // Use new syntax if targeting iOS 17+
                        if viewModel.shouldAutoScrollDebug {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("debugTextEnd", anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {  // Scroll on appear as well
                        if viewModel.shouldAutoScrollDebug {
                            proxy.scrollTo("debugTextEnd", anchor: .bottom)
                        }
                    }
                }
            } else {
                Text(
                    "No debug information available. Enable debug logging to see details."
                )
                .foregroundColor(.secondary).italic()
                .padding(.vertical, DesignConstants.mediumPadding)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    @ViewBuilder
    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary).lineLimit(1).truncationMode(
                .middle
            )
        }
    }
}
