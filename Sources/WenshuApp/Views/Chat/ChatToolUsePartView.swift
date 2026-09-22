//
//  ChatToolUsePartView.swift · Wenshu · refactor chat-mvvm-3layer C-9c
//
//  Apple MVVM canonical part view: renders one tool invocation
//  card (= the "the assistant is calling tool X with args Y" cell).
//  Lifted out of ChatPartView.swift so:
//
//  - The chat part surface follows 1-view-1-file.
//  - Tool-use UI can evolve independently (= hermes has tool-
//    specific cards for delegate_task / image_generate; = wenshu
//    ships a generalized fallback per v0.71 P1 batch 2).
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  UI-only (= no business logic; = the tool name + args come from
//  ChatMessagePart.ToolUsePart).
//
//  hermes 1:1 (= ToolFallback component in assistant-ui):
//  - Thin left border + lighter background + small status dot +
//    tool name + collapsed args. Click to expand the JSON args.
//

import SwiftUI

public struct ChatToolUsePartView: View {
    public let toolUse: ChatMessagePart.ToolUsePart
    public let isOutgoing: Bool

    @State private var isArgsExpanded: Bool = false

    public init(toolUse: ChatMessagePart.ToolUsePart, isOutgoing: Bool) {
        self.toolUse = toolUse
        self.isOutgoing = isOutgoing
    }

    public var body: some View {
        // Apple HIG inline card (= rounded rect + thin left border +
        // monospaced font for the tool name = the canonical "tool call"
        // visual = same pattern as Xcode / Mail "Show Details" blocks).
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMicro) {
            HStack(spacing: DesignTokens.chromePaddingSmall) {
                // Status indicator (= T2 dot + T44 icon overlay).
                // T2 introduced the colored Circle status dot
                // (= running = secondary / complete = green /
                // error = red). T44 replaces it with a small
                // SF Symbol that matches the status (= hourglass
                // for running / checkmark for complete / xmark for
                // error). The icon uses .font(.system(size: 9))
                // (= smaller than the tool-icon size 11 = the
                // status icon is a "secondary" visual cue, not the
                // primary one).
                // T45-STATUS-PULSE (2026-09-18): when status = .running,
                // the hourglass icon gets a subtle opacity pulse
                // (= 1.0 → 0.5 → 1.0 over 1.2s = faster than the
                // T17 reasoning pulse = more "active tool" feel).
                // The pulse stops when status leaves .running (= the
                // icon returns to its static foregroundStyle tint).
                Image(systemName: Self.statusIconName(for: toolUse.status))
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(statusColor)
                    .opacity(isRunningStatus ? runningStatusOpacity : 1.0)
                    .animation(
                        isRunningStatus
                            ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                            : .default,
                        value: runningStatusOpacity
                    )
                    .frame(width: 14)
                // T43-TOOL-ICON-SF (2026-09-18): a small SF Symbol
                // icon that visualises the tool kind (= replaces the
                // bare tool-name text with a leading glyph). The
                // icon map covers the wenshu tool categories:
                //   - ReadFileTool / ListDir / Search → "magnifyingglass"
                //   - WriteFile / Edit / Append      → "square.and.pencil"
                //   - Shell / Process                → "terminal"
                //   - Calculator / Math              → "function"
                //   - Web fetch                      → "globe"
                //   - Default (unknown tool)         → "wrench.and.screwdriver"
                // Falls back to "wrench.and.screwdriver" for tools
                // not in the map (= forward-compat for new tools).
                Image(systemName: Self.iconName(for: toolUse.name))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                // Tool name in monospaced font (= the wenshu convention
                // for tool identifiers = matches the chat input's
                // `/command` autocomplete rendering).
                Text(toolUse.name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                // T47-TOOL-DURATION (2026-09-18): show the tool
                // execution duration when present (= e.g. "1.2s" /
                // "234ms"). Appended inline after the tool name with
                // a · separator (= Apple HIG metadata pattern).
                // Hidden when:
                //   - status != .complete / .error (= the tool is
                //     still running; = no duration yet)
                //   - durationSeconds is nil (= legacy tool calls
                //     without the duration field)
                if let duration = toolUse.durationSeconds,
                   toolUse.status != .running {
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    Text(Self.formatDuration(duration))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                // Expand toggle (= click anywhere on the card; = the
                // Hermes ToolFallback uses a `ScaffoldRow` click target).
            }
            if isArgsExpanded {
                // Args JSON (= pretty-printed if possible; = wrapped
                // in a monospaced font for readability).
                Text(Self.prettyJSON(toolUse.args))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignTokens.statusForeground)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DesignTokens.chromePaddingMicro)
            }
        }
        .padding(.horizontal, DesignTokens.chromePaddingSmall)
        .padding(.vertical, DesignTokens.chromePaddingMicro)
        .background(toolCardFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            // Thin left border (= Apple Mail "block quote" indicator).
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .frame(maxWidth: 360)
        .onTapGesture {
            // Toggle args expansion (= single tap target = the card
            // itself = mirrors Hermes' ScaffoldRow click semantics).
            withAnimation(.easeInOut(duration: 0.2)) {
                isArgsExpanded.toggle()
            }
        }
    }

    /// Status color (= Apple HIG semantic color = adapts to dark mode
    /// + the user's accent preference).
    private var statusColor: Color {
        switch toolUse.status {
        case .running: return .secondary
        case .complete: return .green
        case .error: return .red
        }
    }

    /// Card background (= thin tint that respects the surrounding
    /// bubble color AND the tool's status).
    /// T46-CARD-STATUS-TINT (2026-09-18): when status = .complete,
    /// the card fill gets a subtle green tint (= success). When
    /// status = .error, a subtle red tint. Running + outgoing are
    /// unchanged.
    ///   - running:  no tint (= original neutral quaternary)
    ///   - complete: green.opacity(0.06)
    ///   - error:    red.opacity(0.06)
    ///   - outgoing user bubble: windowBackground tint preserved
    private var toolCardFill: AnyShapeStyle {
        if isOutgoing {
            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.12))
        }
        switch toolUse.status {
        case .running:
            return AnyShapeStyle(.quaternary.opacity(0.5))
        case .complete:
            return AnyShapeStyle(Color.green.opacity(0.06))
        case .error:
            return AnyShapeStyle(Color.red.opacity(0.06))
        }
    }

    /// Border color (= matches the status dot color at low opacity).
    private var borderColor: Color {
        statusColor.opacity(0.5)
    }

    /// Pretty-print the args JSON (= if the args aren't valid JSON,
    /// show them as-is). `nonisolated` so it can be called from test
    /// contexts without `@MainActor` isolation (= pure utility).
    nonisolated static func prettyJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let pretty = try? JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
              ),
              let s = String(data: pretty, encoding: .utf8) else {
            return raw
        }
        return s
    }

    /// T43-TOOL-ICON-SF (2026-09-18): map a tool name to a SF
    /// Symbol that visually identifies the tool kind. The map
    /// covers the standard wenshu tool categories; = unknown
    /// tools fall through to the generic wrench glyph.
    ///
    ///
    /// Mapping strategy:
    ///   - Prefix-based for `*Tool` naming convention (= the
    ///     standard wenshu / hermes-port convention).
    ///   - Keyword-based for tools that don't follow the convention
    ///     (= e.g. "shell" matches both "RunShellTool" and "Shell").
    nonisolated static func iconName(for toolName: String) -> String {
        let lower = toolName.lowercased()
        // Image / media (= photo) = checked FIRST so that
        // 'photo_edit' matches photo (= the edit suffix would
        // otherwise catch it as write/edit).
        if lower.contains("image") || lower.contains("media") || lower.contains("photo") {
            return "photo"
        }
        // Read tools (= magnifying glass = data lookup)
        if lower.contains("read") || lower.contains("list") || lower.contains("search")
            || lower.contains("find") || lower.contains("query") || lower.contains("grep") {
            return "magnifyingglass"
        }
        // Write / edit tools (= pencil = mutation)
        if lower.contains("write") || lower.contains("edit") || lower.contains("append")
            || lower.contains("create") || lower.contains("delete") || lower.contains("move") {
            return "square.and.pencil"
        }
        // Shell / process (= terminal)
        if lower.contains("shell") || lower.contains("process") || lower.contains("exec")
            || lower.contains("bash") || lower.contains("command") {
            return "terminal"
        }
        // Calculator / math (= function notation)
        if lower.contains("calc") || lower.contains("math") || lower.contains("eval") {
            return "function"
        }
        // Web tools (= globe)
        if lower.contains("web") || lower.contains("fetch") || lower.contains("http")
            || lower.contains("url") {
            return "globe"
        }
        // Fallback (= generic tool glyph = Apple HIG "Settings"
        // equivalent for unknown tools).
        return "wrench.and.screwdriver"
    }

    /// T44-TOOL-STATUS-ICON (2026-09-18): map a tool call's status
    /// to a SF Symbol that visualises it (= hourglass for running,
    /// checkmark for complete, xmark for error). Companion to the
    /// T44 status indicator in the card header.
    ///
    /// Visual mapping:
    ///   - .running  → "hourglass" (= "in progress" affordance)
    ///   - .complete → "checkmark" (= Apple HIG success)
    ///   - .error    → "xmark" (= Apple HIG error)
    nonisolated static func statusIconName(for status: ChatMessagePart.ToolUsePart.Status) -> String {
        switch status {
        case .running: return "hourglass"
        case .complete: return "checkmark"
        case .error: return "xmark"
        }
    }

    /// T47-TOOL-DURATION (2026-09-18): format a tool execution
    /// duration in seconds as a human-readable string.
    ///   - < 1 second  → "234ms" (millisecond precision)
    ///   - < 60 seconds → "1.2s" (one decimal)
    ///   - >= 60 seconds → "2m 5s" (minutes + seconds)
    /// nonisolated (= pure utility function).
    nonisolated static func formatDuration(_ seconds: Double) -> String {
        if seconds < 1.0 {
            let ms = Int(seconds * 1000)
            return "\(ms)ms"
        }
        if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(remainingSeconds)s"
    }

    /// T45-STATUS-PULSE (2026-09-18): true when the tool call is
    /// still running (= the hourglass icon should pulse).
    private var isRunningStatus: Bool {
        toolUse.status == .running
    }

    /// T45-STATUS-PULSE (2026-09-18): target opacity for the
    /// status icon's autoreverse pulse (= 0.5 = halfway between
    /// 1.0 and 0.0 = visible but dimmed = the "still working"
    /// affordance). Faster than T17 reasoning pulse (= 1.2s vs
    /// 1.4s = a tool call should feel more "active").
    private var runningStatusOpacity: Double {
        0.5
    }
}

// MARK: - Tool-result part (= hermes ToolResultMessagePart)

/// Render a `.toolResult(ToolResultPart)` part (= the result of a
/// tool execution = Hermes ToolResultMessagePart). Sits visually
/// below the matching `.toolUse` card (= a "sibling" pair = the
/// same visual treatment + a checkmark icon when succeeded / a
