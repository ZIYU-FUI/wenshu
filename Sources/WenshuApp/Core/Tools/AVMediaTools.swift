//
//  AVMediaTools.swift · Wenshu · v0.18 ticket 11 (hermes replica)
//
//  本地 AV media 工具 (复刻 hermes tts 真值).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现" + "不符合文枢定位的可以复刻".
//
//  wenshu 定位 = SwiftUI 桌面写作 app. AVMediaTools 写作用 (听写 / 朗读).
//  Apple HIG 真值: AVFoundation AVSpeechSynthesizer.
//

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// TTS 合成结果真值 (hermes tts 真值)
public struct TTSResult: Equatable, Sendable {
    public let text: String
    public let voice: String
    public let rate: Float
    public let duration: TimeInterval

    public init(text: String, voice: String, rate: Float, duration: TimeInterval) {
        self.text = text
        self.voice = voice
        self.rate = rate
        self.duration = duration
    }
}

/// AVMediaTools: 本地 AV media 工具 (AVSpeechSynthesizer 真值)
public struct AVMediaTools: Tool, Sendable {
    public init() {}

    /// Tool-protocol adapter (= MIGRATE-TOOLREGISTRY-002): parse the
    /// JSON input envelope and dispatch to `speak(text:)`. Mirrors
    /// `WenshuConductor.invokeTool(name: "av", ...)` which uses the
    /// input string verbatim as the text to speak.
    public func execute(input: String) async throws -> String {
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

    /// speak: 朗读文字真值 (fire-and-forget, 不等播放完)
    public func speak(text: String, voice: String = "zh-CN", rate: Float = 0.5) {
        #if canImport(AVFoundation)
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voice)
        utterance.rate = rate
        synthesizer.speak(utterance)
        #endif
    }

    /// estimateDuration: 估算朗读时长真值 (不真播放, 算法估算)
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    /// 简化公式: 字符数 / 语速 (中英文 ~3-5 字/秒, 默认 4 字/秒)
    public func estimateDuration(text: String, rate: Float = 0.5) -> TimeInterval {
        let charactersPerSecond = 4.0 * Double(rate / 0.5)
        return TimeInterval(Double(text.count) / charactersPerSecond)
    }

    /// availableVoices: 列可用语音真值
    public func availableVoices(languagePrefix: String? = nil) -> [String] {
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
// 默认语速常量 (Apple 真值)
private let AVSpeechUtteranceDefaultSpeechRate: Float = AVSpeechUtteranceDefaultSpeechRate
#endif

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension AVMediaTools {
    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1). Fires once at first
    /// type access; the underlying `Task` schedules the async
    /// `register(...)` call off the init thread.
    public static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.register(
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
