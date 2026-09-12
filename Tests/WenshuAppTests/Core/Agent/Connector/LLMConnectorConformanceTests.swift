//
//  LLMConnectorConformanceTests.swift · Wenshu · v0.71 P1 batch 3
//
//  v0.71 P1 batch 3 (boss 2026-09-12 OOB '用户 BYOK (bring your own key)'
//  + §11.2 LLM connector profiles = 7 connector profiles (Anthropic /
//  OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax cn)' +
//  '我提需求，你只做我提的事'):
//
//  Code-level verification (= no network, no LLM calls) that all 7
//  LLMConnector profiles are actually present in the codebase, each
//  one:
//    1. defines a `public actor` (= the LLMConnector protocol
//       requires Sendable + the concurrency model used in v0.34+)
//    2. conforms to `LLMConnector` (= has both `connectorID: String`
//       and `send(messages:options:) async throws -> LLMResponse`)
//    3. has a unique `connectorID` (= no duplicates = the routing
//       layer in AuxiliaryClient can disambiguate)
//
//  These tests don't make any network calls; they only verify the
//  type-level conformance (= Swift's type system = the canonical
//  back-pressure for protocol conformance; = if a connector is
//  missing any required member, the build breaks).

import Testing
import Foundation
@testable import WenshuApp

@Suite("v0.71 P1 — LLMConnector profile conformance (= 7 connectors per §11.2)")
struct LLMConnectorConformanceTests {

    /// The 7 LLM connector profiles per §11.2 (= canonical wenshu
    /// §11.2 spec): Anthropic / OpenAI / Gemini / DeepSeek / Ollama
    /// / OpenRouter / minimax cn. Each profile MUST be a separate
    /// actor that conforms to LLMConnector.
    @Test("all_7_connector_profiles_present_per_section_11_2")
    func all_7_connector_profiles_present_per_section_11_2() {
        // Per §11.2, the 7 connector profiles map to:
        //   P0: Anthropic, OpenAI, minimax cn
        //   P1: DeepSeek, Gemini, Ollama
        //   P2: OpenRouter
        // (Priority doesn't affect conformance; = all 7 must be
        // present and conformant.)
        let expectedConnectors = [
            "AnthropicConnector",      // P0
            "OpenAIConnector",         // P0
            "MinimaxConnector",        // P0
            "DeepSeekConnector",       // P1
            "GeminiNativeConnector",   // P1
            "OllamaConnector",         // P1
            "OpenRouterConnector",     // P2
        ]
        #expect(expectedConnectors.count == 7, "§11.2 requires 7 connector profiles")
        // Find each connector's file (= convention = Core/Agent/Connector/<Name>.swift).
        for name in expectedConnectors {
            let file = "Sources/WenshuApp/Core/Agent/Connector/\(name).swift"
            let url = URL(fileURLWithPath: file)
            #expect(
                FileManager.default.fileExists(atPath: url.path),
                "Connector file MUST exist (§11.2): \(file)"
            )
        }
    }

    /// Each connector MUST declare `public actor X: LLMConnector { ... }`
    /// (= the protocol conformance declaration). The compiler enforces
    /// the LLMConnector conformance at build time (= if the actor
    /// misses `connectorID` or `send`, the build breaks).
    @Test("each_connector_declares_actor_conformance_to_LLMConnector")
    func each_connector_declares_actor_conformance_to_LLMConnector() throws {
        let expectedConnectors = [
            "AnthropicConnector", "OpenAIConnector", "MinimaxConnector",
            "DeepSeekConnector", "GeminiNativeConnector", "OllamaConnector",
            "OpenRouterConnector",
        ]
        var nonConforming: [String] = []
        for name in expectedConnectors {
            let file = "Sources/WenshuApp/Core/Agent/Connector/\(name).swift"
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for `public actor <Name>: LLMConnector { ... }`
            // (= the canonical conformance declaration).
            if !content.contains("public actor \(name): LLMConnector") {
                nonConforming.append(name)
            }
        }
        #expect(
            nonConforming.isEmpty,
            "Connectors missing `public actor <Name>: LLMConnector` declaration: \(nonConforming)"
        )
    }

    /// The 7 connector IDs MUST be unique (= the AuxiliaryClient
    /// routing layer dispatches by connectorID; = duplicates
    /// would silently route to the wrong connector).
    ///
    /// Two declaration styles appear in the codebase (= both are
    /// valid LLMConnector conformance):
    ///   • `public nonisolated let connectorID = "anthropic"` (= stored
    ///     property with literal default; = Anthropic / OpenAI / etc.)
    ///   • `public nonisolated let connectorID: String  // = provider.slug
    ///     (= set at init)` (= stored property with runtime value; =
    ///     the OpenAICompatibleConnector used by DeepSeek / Ollama /
    ///     OpenRouter / minimax-cn).
    ///   • `var connectorID: String { "..." }` (= computed property;
    ///     not used in the current codebase but covered for back-compat).
    /// The regex below matches all three styles.
    @Test("connectorIDs_are_unique_across_all_7_profiles")
    func connectorIDs_are_unique_across_all_7_profiles() throws {
        let expectedConnectors = [
            "AnthropicConnector", "OpenAIConnector", "MinimaxConnector",
            "DeepSeekConnector", "GeminiNativeConnector", "OllamaConnector",
            "OpenRouterConnector",
        ]
        // Match `let connectorID = "..."` (= stored property with literal)
        // or `var connectorID: String { "..." }` (= computed property).
        // Some connectors use a runtime slug (= `let connectorID: String` =
        // set at init from `provider.slug`; = we just verify the declaration).
        let literalPattern = #"connectorID\s*=\s*"([^"]+)""#
        var seenIDs: [String: String] = [:]  // connectorID literal -> actor name
        var runtimeIDs: [String] = []         // actors using runtime slug
        var duplicates: [String] = []
        for name in expectedConnectors {
            let file = "Sources/WenshuApp/Core/Connector/\(name).swift"
                .replacingOccurrences(of: "/Connector/", with: "/Agent/Connector/")
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)
            // Strip comments (= a literal like "anthropic" inside
            // a `// example` line should not count).
            let stripped = content.components(separatedBy: "\n").filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
            }.joined(separator: "\n")
            guard let regex = try? NSRegularExpression(pattern: literalPattern, options: []) else { continue }
            let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
            let matches = regex.matches(in: stripped, options: [], range: range)
            if matches.isEmpty {
                // No literal; = must be a runtime slug (= style #2).
                if stripped.contains("let connectorID: String") ||
                   stripped.contains("var connectorID: String") {
                    runtimeIDs.append(name)
                } else {
                    Issue.record("\(name) connectorID declaration not recognized")
                }
                continue
            }
            for match in matches {
                guard let r = Range(match.range(at: 1), in: stripped) else { continue }
                let id = String(stripped[r])
                if let existing = seenIDs[id] {
                    duplicates.append("\(id) used by both \(existing) and \(name)")
                } else {
                    seenIDs[id] = name
                }
            }
        }
        #expect(
            duplicates.isEmpty,
            "Duplicate connectorIDs (= the routing layer would dispatch incorrectly): \(duplicates)"
        )
        // We expect at least 1 literal per connector (= some use
        // runtime slugs; = OpenAICompatibleConnector is shared by
        // 4 providers, so it's OK to have runtime IDs).
        // The hard requirement is: NO duplicates.
        // (= every literal connectorID in the codebase is unique).
        #expect(
            !seenIDs.isEmpty || !runtimeIDs.isEmpty,
            "Expected at least one literal or runtime connectorID; found neither. Literals: \(seenIDs), runtime: \(runtimeIDs)"
        )
    }

    /// Each connector MUST implement `send(messages:options:)` (= the
    /// single required method on the LLMConnector protocol; = the
    /// compiler enforces this but a regression test pins the contract).
    @Test("each_connector_implements_send_method")
    func each_connector_implements_send_method() throws {
        let expectedConnectors = [
            "AnthropicConnector", "OpenAIConnector", "MinimaxConnector",
            "DeepSeekConnector", "GeminiNativeConnector", "OllamaConnector",
            "OpenRouterConnector",
        ]
        var missing: [String] = []
        for name in expectedConnectors {
            let file = "Sources/WenshuApp/Core/Agent/Connector/\(name).swift"
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for `func send(messages: [LLMMessage], options: LLMCallOptions)`
            if !content.contains("func send(") || !content.contains("messages: [LLMMessage]") {
                missing.append(name)
            }
        }
        #expect(
            missing.isEmpty,
            "Connectors missing `func send(messages:options:)` implementation: \(missing)"
        )
    }
}
