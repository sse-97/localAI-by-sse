<p align="center">
  <img src="localAI by sse/Assets.xcassets/AppIcon.appiconset/localAI 1.png" alt="localAI Logo" width="120" height="120">
</p>

<p align="center">
  Run LLMs completely locally on your iOS device.
</p>

## Overview

localAI is a native iOS application that enables on-device inference with large language models without requiring an internet connection. Built with Swift and SwiftUI, it leverages [LLM.swift](https://github.com/eastriverlee/LLM.swift) for efficient model inference on Apple Silicon.

## Features

- **Completely Local Processing**: All inference on-device with no data sent to external servers
- **Bundled Model**: Pre-packaged with Llama 3.2 3B Instruct
- **Custom Models**: Import your own GGUF format models
- **Adjustable Parameters**: Temperature, Top-K/P sampling
- **Monitoring**: Real-time token generation speed, memory usage, context utilization
- **UI**: Clean interface with light/dark mode support
- **Debugging**: Detailed logging options

## Requirements

- iOS 17.6+
- Device with Apple Silicon recommended for optimal performance

## Installation

### Build from Source
Clone the repository, integrate the LLM.swift package, then build and run.

### iOS App Store
Coming soon! We're working on App Store approval.

## Usage

Launch the app and start chatting using the pre-packaged Llama 3.2 3B Instruct model. Add custom GGUF models via Settings. Adjust parameters like temperature, Top-K, and Top-P to customize responses.

## Supported Models

- **Bundled**: Llama 3.2 3B
- **Compatible**: Llama family, Mistral, Alpaca, Phi-2, TinyLlama, Qwen, Gemma, and any GGUF format model

## Troubleshooting

- **Model fails to load**: Verify GGUF file, try smaller model, check memory
- **Slow generation**: Use smaller models, disable low-power mode
- **Crashes**: Try Emergency Reset option with a smaller model

## Privacy

All processing happens on-device with no data sent to remote servers, no analytics, and no network permissions required.

## License

MIT License - see the [LICENSE](LICENSE.txt) file for details.

## Acknowledgments

- [llama.cpp](https://github.com/ggml-org/llama.cpp) for the core inference engine
- [LLM.swift](https://github.com/eastriverlee/LLM.swift) developers
- Open-source language model creators and quantizers

---

<p align="center">
  Made with ❤️ and Claude 3.7 Sonnet by <a href="https://github.com/sse-97">sse-97</a>
</p>
