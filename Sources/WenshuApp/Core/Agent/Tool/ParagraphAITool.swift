//
//  ParagraphAITool.swift · Wenshu · P0 #2 (WIRE-AGENT-002) + P1 #10 (WIRE-PARAGRAPH-001)
//
//  Tool-protocol-facing entry point for the paragraph-level
//  editor transformations. Replaces the P0 #2 canned-stub body
//  with a real dispatch through `EditorTransformTools` (the
//  Swift port of hermes `agent/editing/editor_tools.py` shipped
//  in PORT-SPECIALIZED-005).
//
//  The actual rewriting is performed by the LLM (= ConversationLoop
//  routes the returned prompt prefix + user paragraph text into
//  the model call). The Swift tool's job is narrower: parse the
//  LLM's tool_use input, look up the matching transform, and
//  return the prompt prefix the model will consume.
//
//  Input contract (= unchanged from the stub; preserves the
//  ConversationLoop ↔ LLM contract per the P0 #2 acceptance):
//
//    {"text": "<paragraph>", "action": "<expand|shorten|rephrase|shiftTone|simplify|dramatize>", "tone": "<formal|casual|literary|punchy|neutral>?"}
//
//    - `text`   : the paragraph to transform. Optional (= empty
//                 yields a deterministic stub frame so the
//                 ConversationLoop still gets a tool_result back).
//    - `action` : one of the 6 `EditorTransform` raw values.
//                 Optional; defaults to "expand" (= mirrors the
//                 P0 #2 stub default).
//    - `tone`   : only meaningful when `action == "shiftTone"`.
//                 Defaults to `EditorTransformTools.defaultTone(for:)`
//                 for the requested action (= `.formal` for
//                 shiftTone, `.literary` for dramatize, `nil`
//                 everywhere else).
//
//  Output contract: the LLM-facing prompt prefix for the
//  requested transform. ChatView's tool surface composes this
//  with the user paragraph and feeds the combination into the
//  LLM call (= the model returns the rewritten paragraph; that
//  flows back through the ConversationLoop assistant-message
//  path). For empty input the tool still returns a non-empty
//  stub frame (= preserved from the P0 #2 stub; keeps the
//  ConversationLoop wiring deterministic for malformed input).
//
//  Tool name = "ParagraphAI" (= unchanged from the P0 #2 stub;
//  matches the convention other wenshu tools use: ReadFileTool
//  → "ReadFile", WriteFileTool → "WriteFile").
//

import Foundation

public struct ParagraphAITool: Tool, Sendable {

    /// Shared singleton (= ChatViewModel registers this with the
    /// conductor at construction time). The tool holds a
    /// reference to a single `EditorTransformTools` actor so
    /// every call site hits the same in-process prompt registry.
    public static let shared = ParagraphAITool(
        editorTools: EditorTransformTools()
    )

    private let editorTools: EditorTransformTools

    public init(editorTools: EditorTransformTools) {
        self.editorTools = editorTools
    }

    public func execute(input: String) async throws -> String {
        // Parse input JSON. Stub contract: {"text": "...", "mode": "..."}
        // The real port accepts {"text": "...", "action": "...",
        // "tone": "..."} (= matches the LLM tool_use shape the
        // ConversationLoop emits). Both `action` and `tone` are
        // optional; default = "expand" + default tone for the
        // resolved action (= matches the P0 #2 stub default).
        let dict: [String: Any]
        do {
            dict = try ToolInputParser.parseDictionary(input: input)
        } catch {
            // Empty / malformed input still returns a valid stub frame
            // (= canned expansion of an empty paragraph is empty +
            // "(no input)" annotation; tests assert non-empty output).
            return stubFrame(text: "", action: EditorTransform.expand.rawValue)
        }
        let text = (dict["text"] as? String) ?? ""

        // Resolve the action (= "action" is the canonical name;
        // "mode" is the legacy alias from the P0 #2 stub; both
        // resolve to the same EditorTransform so old LLM tool_use
        // blocks keep working).
        let actionRaw = (dict["action"] as? String)
            ?? (dict["mode"] as? String)
            ?? EditorTransform.expand.rawValue
        guard let transform = EditorTransform(rawValue: actionRaw) else {
            // Unknown action = fall back to expand (= matches the
            // HermesTodoTool / TodoStoreTool "empty input == read"
            // convention: pick the safe default, do not throw).
            return await dispatchFrame(
                text: text,
                transform: .expand,
                explicitTone: nil
            )
        }

        // Resolve the tone (= only meaningful for shiftTone; for
        // other transforms `tone` is ignored, but parsing it
        // first keeps the contract uniform across the 6 cases).
        let explicitTone: TargetTone?
        if let toneRaw = dict["tone"] as? String {
            explicitTone = TargetTone(rawValue: toneRaw)
        } else {
            explicitTone = nil
        }

        return await dispatchFrame(
            text: text,
            transform: transform,
            explicitTone: explicitTone
        )
    }

    /// Resolve the tone + build the prompt prefix + wrap it in the
    /// `[ParagraphAI ...]` frame the ConversationLoop + ChatView
    /// expect (= preserves the P0 #2 stub frame shape so existing
    /// callers + tests do not break).
    private func dispatchFrame(
        text: String,
        transform: EditorTransform,
        explicitTone: TargetTone?
    ) async -> String {
        let resolvedTone: TargetTone?
        if let explicitTone {
            resolvedTone = explicitTone
        } else {
            resolvedTone = await editorTools.defaultTone(for: transform)
        }
        let prefix = await editorTools.promptPrefix(for: transform, targetTone: resolvedTone)
        return composeFrame(text: text, transform: transform, tone: resolvedTone, promptPrefix: prefix)
    }

    /// Build the canned expansion frame (= preserved from the P0 #2
    /// stub; the body now contains the real prompt prefix instead
    /// of the literal "expanded" suffix).
    private func composeFrame(
        text: String,
        transform: EditorTransform,
        tone: TargetTone?,
        promptPrefix: String
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.isEmpty ? "(no input)" : trimmed
        let toneSuffix = tone.map { ",tone=\($0.rawValue)" } ?? ""
        return "[ParagraphAI action=\(transform.rawValue)\(toneSuffix)] prompt=\(promptPrefix) input=\(body)"
    }

    /// Stub frame used for malformed / empty input that fails
    /// JSON parsing. Kept (= preserved from the P0 #2 stub; the
    /// wire test in `WenshuConductorToolWiringTests` still
    /// matches the "ParagraphAI stub" substring path for the
    /// parity guard).
    private func stubFrame(text: String, action: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.isEmpty ? "(no input)" : trimmed
        return "[ParagraphAI stub — action=\(action)] \(body) [expanded]"
    }
}

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension ParagraphAITool {
    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1). Fires once at first
    /// type access; the underlying `Task` schedules the async
    /// `register(...)` call off the init thread (= matches the
    /// wenshu pattern of not awaiting inside `static let`).
    ///
    /// Registration is idempotent (= the registry silently replaces
    /// a same-toolset re-registration; the override-protection logic
    /// in ToolRegistry blocks accidental cross-toolset shadowing).
    public static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.register(
                name: "ParagraphAI",
                toolset: "editor",
                schema: ToolRegistrySchema(
                    name: "ParagraphAI",
                    description: "Paragraph-level AI editor transforms (= expand / shorten / rephrase / shiftTone / simplify / dramatize).",
                    inputSchema: [
                        "text": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The paragraph text to transform."
                        ),
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The transform to apply (= expand / shorten / rephrase / shiftTone / simplify / dramatize). Defaults to expand.",
                            enumValues: ["expand", "shorten", "rephrase", "shiftTone", "simplify", "dramatize"]
                        ),
                        "tone": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Target tone for shiftTone (= formal / casual / literary / punchy / neutral). Optional; ignored for non-tone actions.",
                            enumValues: ["formal", "casual", "literary", "punchy", "neutral"]
                        )
                    ],
                    required: ["text"]
                ),
                handler: ParagraphAITool.shared,
                description: "Paragraph-level AI editor transforms (= expand / shorten / rephrase / shiftTone / simplify / dramatize).",
                emoji: "✍"
            )
        }
    }()
}

// NOTE: Swift 6 forbids top-level expressions, so the static let
// `_registryBootstrap` initializer runs lazily on first type access
// (= Swift equivalent of Python module-load statement = hermes
// `registry.register(...)` at import time). Production code paths
// that touch this type (= e.g. ChatView constructing
// `ParagraphAITool.shared`, WenshuConductor constructing `ReadFileTool()`)
// automatically trigger the bootstrap.
