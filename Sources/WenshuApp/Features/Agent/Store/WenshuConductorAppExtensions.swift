//
//  WenshuConductorAppExtensions.swift · Wenshu · agent runtime boundary
//
//  The app half of the conductor.
//
//  The conductor actor lives in the `WenshuAgent` package. The members
//  below stay in the app because they read app-owned state: the tool
//  catalogue (= which tools the app ships and how they are
//  categorized) and the settings store (= which of them the user
//  turned on). The runtime cannot name either, so the app keeps them
//  and the package keeps the actor.
//

import Foundation
import WenshuAgent

extension WenshuConductor {

    // MARK: - Tool exposure (= the catalogue + the user's selection)

    /// Tool names the conductor asks the registry for.
    ///
    /// Delegates to ToolCatalogue so the list carries a category per tool and
    /// the settings presets can be derived from it. An empty selection means
    /// every tool, so an existing installation changes nothing until someone
    /// opens settings and chooses.
    @MainActor
    static var defaultToolNames: [String] {
        ToolCatalogue.exposedNames(settings: agentSettings.prompt)
    }

    /// Behaviour knobs for the turn runtime, as the user configured them.
    ///
    /// MainActor because the store is: settings are written from the settings
    /// screen and read from here, and a turn already hops there for the
    /// libraries.
    @MainActor
    static var agentSettings: AgentSettings { AgentSettingsStore.shared.load() }

    // MARK: - ToolRegistry wiring (WIRE-TOOLREGISTRY-003)

    // / Maximum time `buildToolsSync(from:)` will wait for the detached async
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / covers the scheduling jitter.
    static let toolRegistryWaitTimeoutMs: UInt64 = 250

    // / Build the conductor's tool registry from `ToolRegistry.shared` (= hermes
    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / deterministic.
    static func buildTools(from registry: ToolRegistry) async -> [String: any Tool] {
        // Step 1: brief warmup window. Registrations are fire-and-forget
        // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // always time out and waste 250 ms.
        try? await Task.sleep(nanoseconds: toolRegistryWarmupMs * 1_000_000)

        // Step 2: assemble the dict via `getHandler`. Unknown names are
        // silently dropped (= spec: `testBuildTools_excludesUnknownNames`).
        var tools: [String: any Tool] = [:]
        // The configured selection is read on the main actor because the
        // settings store is; everything else below is actor-local.
        let wanted = await defaultToolNames
        for name in wanted {
            if let handler = await registry.getHandler(name: name) {
                tools[name] = handler
            }
        }
        return tools
    }

    // / Brief settle window for `buildTools(from:)` (= 50 ms). Registrations are
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / which would time out in tests where not all 12 tool files are linked).
    static let toolRegistryWarmupMs: UInt64 = 50

    /// Resolve the user's selected tools from the registry, for a turn.
    ///
    /// The set is resolved when a turn runs, not when the conductor is
    /// built: the app installs the conductor at launch and the
    /// registrations land on a background task after that, so a
    /// launch-time snapshot is empty for the first turns.
    static func productionToolProvider() -> @Sendable () async -> [String: any Tool] {
        { [registry = ToolRegistry.shared] in
            var resolved: [String: any Tool] = [:]
            let wanted = await WenshuConductor.defaultToolNames
            for name in wanted {
                if let handler = await registry.getHandler(name: name) {
                    resolved[name] = handler
                }
            }
            return resolved
        }
    }

    // MARK: - Legacy typed tool dispatch (= the app's concrete tools)

    // / h10: dispatch an agent tool call. Returns "" on unknown tool / failure.
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / input = text → speaks aloud (fire-and-forget)
    func invokeTool(name: String, input: String, caller: AgentCaller = .main) async -> String {
        // hermes DELEGATE_BLOCKED_TOOLS parity ((see OOB.md #2026-08-23)).
        // … (= 1 rationale line collapsed; = A112 docblock collapse per §1.8)
        // Sub-agents can call memory but only for read ops (no add/delete).
        if caller.isSubAgent {
            let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let op = parts.first.map(String.init) ?? ""
            if let reason = SubAgentPermissions.checkPermission(tool: name, op: op) {
                return reason
            }
        }
        // .003: tool-level allowlist ((see OOB.md #2026-08-23) — user cannot change system via chat).
        // … (= 1 rationale line collapsed; = A112 docblock collapse per §1.8)
        // Unknown op = blocked (per-tool allowlist below).
        let parts = input.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let op = parts.first.map(String.init) ?? ""
        let arg = parts.count > 1 ? String(parts[1]) : ""

        // The concrete tools are app types (= they bind the app's storage),
        // so they are created here rather than stored on the runtime actor.
        let fileTools = FileTools()
        let webTools = WebTools()
        let visionTools = VisionTools()
        let avMediaTools = AVMediaTools()

        switch name {
        case "file":
            // Allowlist: read / list / search only (NOT write / patch).
            guard ["read", "list", "search"].contains(op) else {
                return "(tool blocked: file.\(op) is in deny-list — (see OOB.md #2026-08-23): user cannot change code / config via chat)"
            }
            switch op {
            case "read": return (try? fileTools.read(path: arg)) ?? ""
            case "list": return (try? fileTools.list(path: arg).map { $0.path }.joined(separator: "\n")) ?? ""
            case "search": return (try? fileTools.search(rootDir: arg, pattern: "").joined(separator: "\n")) ?? ""
            default: return ""
            }
        case "process":
            // Deny all (chat-triggered shell = arbitrary code execution).
            return "(tool blocked: process is deny-all — (see OOB.md #2026-08-23): user cannot change system via chat. Use wenshu-devtool CLI.)"
        case "web":
            // Per 12 standard P1-02 try?  (= wenshu tries to surface
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // failure via Console.app.
            do {
                return try await webTools.extract(url: input)
            } catch {
                WenshuConductor.toolLogger.error("[wenshu.conductor.tool] web.extract url=\(input, privacy: .public) silently dropped error: \(String(describing: error), privacy: .public)")
                return ""
            }
        case "vision":
            // Same pattern (= silent fallback on the bottom-rung of
            // the multi-tool pipeline).
            var recognizedResults: [VisionTextResult] = []
            do {
                recognizedResults = try await visionTools.recognizeText(imagePath: input)
            } catch {
                WenshuConductor.toolLogger.error("[wenshu.conductor.tool] vision.recognizeText imagePath=\(input, privacy: .public) silently dropped error: \(String(describing: error), privacy: .public)")
                return ""
            }
            return recognizedResults.map(\.text).joined(separator: "\n")
        case "av":
            avMediaTools.speak(text: input)
            return "[spoken]"
        default:
            return "(tool blocked: unknown tool '\(name)')"
        }
    }
}
