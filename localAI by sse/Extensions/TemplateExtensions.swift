//
//  TemplateExtensions.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import Foundation
import LLM

// MARK: - Model Template Extension

/// Extends the external `Template` struct from the LLM library.
/// This allows defining predefined chat templates tailored to specific models.
extension Template {
    /// Creates a `Template` configured for Llama 3 model instruction format.
    /// - Parameter systemPrompt: An optional system prompt to guide the model's behavior.
    /// - Returns: A `Template` instance for Llama 3.
    static func llama3(_ systemPrompt: String? = nil) -> Template {
        return Template(
            prefix: "<|begin_of_text|>",
            system: (
                "<|start_header_id|>system<|end_header_id|>\n\n",
                "<|eot_id|>"
            ),
            user: (
                "<|start_header_id|>user<|end_header_id|>\n\n",
                "<|eot_id|>"
            ),
            bot: (
                "<|start_header_id|>assistant<|end_header_id|>\n\n",
                ""
            ),
            stopSequence: "<|eot_id|>",
            systemPrompt: systemPrompt
        )
    }
    
    /// Creates a `Template` configured for Qwen3 model instruction format.
    /// - Parameter systemPrompt: An optional system prompt to guide the model's behavior.
    /// - Returns: A `Template` instance for Qwen3.
    static func qwen3(_ systemPrompt: String? = nil) -> Template {
        return Template(
            system: ("<|im_start|>system\n", "<|im_end|>\n"),
            user: ("<|im_start|>user\n", "<|im_end|>\n"),
            bot: ("<|im_start|>assistant\n", "<|im_end|>\n"),
            stopSequence: "<|im_end|>",
            systemPrompt: systemPrompt
        )
    }
}
