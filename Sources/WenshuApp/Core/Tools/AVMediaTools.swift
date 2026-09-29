// AVMediaTools.swift · WenshuApp · v0.18
//
// Local AV media tools (= hermes `tts` parity). Uses
// `AVSpeechSynthesizer` for text-to-speech (Apple Foundation
// default = Apple HIG canonical).

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// TTS (hermes tts)

/// AVMediaTools: local AV media (AVSpeechSynthesizer)
struct AVMediaTools: Tool, Sendable {
    init() {}

    /// Tool-protocol adapter (= MIGRATE-TOOLREGISTRY-002): parse the
    /// JSON input envelope and dispatch to `speak(text:)`. Mirrors
    /// `WenshuConductor.invokeTool(name: "av", ...)` which uses the
    /// input string verbatim as the text to speak.
    func execute(input: String) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        // Try to parse JSON envelope (= {"text": "..."}); fall back to
        // using the raw input as the speak text.
        var text = trimmed
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let t = parsed["text"] as? String {
            text = t
        }
        speak(text: text)
        return "[spoken]"
    }

    /// speak: (fire-and-forget, wait)
    func speak(text: String, voice: String = "zh-CN", rate: Float = 0.5) {
        #if canImport(AVFoundation)
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voice)
        utterance.rate = rate
        synthesizer.speak(utterance)
        #endif
    }

    /// estimateDuration: (,)
    ///: / (in progress ~3-5 /, default 4 /)
    func estimateDuration(text: String, rate: Float = 0.5) -> TimeInterval {
        let charactersPerSecond = 4.0 * Double(rate / 0.5)
        return TimeInterval(Double(text.count) / charactersPerSecond)
    }

    /// availableVoices:
    func availableVoices(languagePrefix: String? = nil) -> [String] {
        #if canImport(AVFoundation)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let filtered = languagePrefix.map { prefix in
            voices.filter { $0.language.hasPrefix(prefix) }
        } ?? voices
        return filtered.map { "\($0.name) (\($0.language))" }
        #else
        return []
        #endif
    }
}

#if canImport(AVFoundation)
// default (Apple)
private let AVSpeechUtteranceDefaultSpeechRate: Float = AVSpeechUtteranceDefaultSpeechRate
#endif

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension AVMediaTools {
    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1). Fires once at first
    /// type access; the underlying `Task` schedules the async
    /// `register(...)` call off the init thread.
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "av",
                toolset: "meta",
                schema: ToolRegistrySchema(
                    name: "av",
                    description: "Local AV media operations: speak text aloud (= AVSpeechSynthesizer, fire-and-forget).",
                    inputSchema: [
                        "text": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Text to speak aloud."
                        ),
                        "voice": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Voice language code (= default zh-CN)."
                        ),
                        "rate": ToolRegistrySchemaProperty(
                            type: "number",
                            description: "Speech rate (= 0.0 to 1.0; default 0.5)."
                        )
                    ],
                    required: ["text"]
                ),
                handler: AVMediaTools(),
                description: "Local AV media operations: speak text aloud.",
                emoji: "🔊"
            )
        }
    }()
}
