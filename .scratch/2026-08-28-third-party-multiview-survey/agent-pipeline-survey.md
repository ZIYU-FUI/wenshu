# Wenshu Agent / Chat Pipeline — Third-Party Library Survey

Date: 2026-08-28
Scope: macOS-only SwiftPM SwiftUI (Swift 6.4, `.macOS(.v27)`)
Constraint: **ADR-0008** blocks any third-party view-framework / pane / dock / split / drag library. Apple stack exclusive for view architecture. Survey is limited to libraries that **do not replace** view architecture.

Read-only research. No SwiftPM `Package.swift` modified.

---

## 1. MCP (Model Context Protocol) Swift SDK

**Question:** Does wenshu need an official Swift MCP client/server to interface with the wenshu-core agent system?

### 1.1 `modelcontextprotocol/swift-sdk` (official)

- **GitHub:** https://github.com/modelcontextprotocol/swift-sdk
- **Stars / forks:** 1.2k / 160 (verified)
- **License:** MIT (new contributions moving to Apache-2.0 per #177 — mixed)
- **macOS support:** Yes (iOS / macOS / visionOS / Mac Catalyst). Latest tag: `0.10.2`.
- **SwiftPM:** `.package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.2")`
- **One-liner:** Official Swift MCP — `Client`, `Server`, transports (`StdioTransport`, HTTP/Network), Tools/Resources/Prompts/Sampling/Elicitation per the 2025-11-25 spec.
- **Wenshu module fit:** `agent` / `conductor`. Today's `AgentProtocol` is in-process A2A JSON-RPC 2.0; MCP is a separate protocol with different semantics.
- **ADR-0008 verdict:** **ALLOWED** (pure protocol SDK). **CASE-BY-CASE on adoption**: MCP commits wenshu to a public wire contract. Tier 3 per MCP governance (`modelcontextprotocol/modelcontextprotocol#2326`).
- **Recommendation:** **Defer.** Revisit when wenshu needs to call external MCP servers or expose sub-agents as an MCP server.

### 1.2 `DePasqualeOrg/swift-mcp` (alternative)

- **GitHub:** https://github.com/DePasqualeOrg/swift-mcp
- **Stars:** not verified in this window — **flag for verification before adoption.**
- **License:** verify per repo `LICENSE`.
- **Note:** Submitted as Tier 1 candidate with 100% conformance on 30/30 server and 18/18 client suites (see #2326).
- **ADR-0008 verdict:** **CASE-BY-CASE** — protocol SDK only.

---

## 2. SSE / Streaming HTTP client

URLSession `.bytes(for:)` already streams HTTP bodies; wenshu needs spec-compliant `text/event-stream` parsing, `Last-Event-ID` reconnection, and backoff.

### 2.1 `mattt/EventSource`

- **GitHub:** https://github.com/mattt/EventSource
- **Stars:** 116 (verified via SPI)
- **Activity:** 23 commits / 8 releases over ~1 year; latest tag `1.4.1`; Swift Package Index last-updated 2026.
- **License:** MIT
- **macOS support:** Yes (Apple + Linux via AsyncHTTPClient transport).
- **SwiftPM:** `.package(url: "https://github.com/mattt/EventSource.git", from: "1.4.0")`
- **One-liner:** Spec-compliant SSE client with `AsyncSequence`, auto-reconnect with configurable retry, `Last-Event-ID` tracking.
- **Wenshu module fit:** `provider` — directly applicable to OpenAI-compatible `/v1/chat/completions` SSE.
- **ADR-0008 verdict:** **ALLOWED — RECOMMENDED PRIMARY CANDIDATE** for SSE.

### 2.2 URLSession + hand-rolled parser

- **What it is:** `URLSession.shared.bytes(for: request).lines` plus an SSE state machine.
- **Wenshu module fit:** `provider`. ~150 LOC.
- **ADR-0008 verdict:** **ALLOWED.** Recommended for v0.x to avoid a new dependency; migrate to `mattt/EventSource` once reconnection matters.

---

## 3. Chat UI components (cells only — NOT a pane replacement)

ADR-0008 forbids libraries that replace window/pane/split/dock. Below are cell-level primitives.

### 3.1 `FluidGroup/swiftui-messaging-ui`

- **GitHub:** https://github.com/FluidGroup/swiftui-messaging-ui
- **Stars / forks:** 76 / 7 (verified)
- **License:** Apache-2.0
- **macOS support:** Yes (SPI build matrix).
- **SwiftPM:** `.package(url: "https://github.com/FluidGroup/swiftui-messaging-ui", from: "1.6.0")` (2.0.0-beta available)
- **Min deployment:** iOS 17 / Swift 6.0 / Xcode 26 — well below wenshu's Swift 6.4 + `.macOS(.v27)`.
- **One-liner:** Primitive chat components — `TiledView` (stable scroll-prepend, no jumps when loading older messages), `TiledCellContent` protocol, per-cell `CellStateStorage`, typing indicator, header content, keyboard safe-area handling.
- **Wenshu module fit:** `chat` — the "stable prepending" problem is the single hardest sub-problem in a chat UI and this library solves only that.
- **ADR-0008 verdict:** **CASE-BY-CASE — leans ALLOWED.** `TiledView` is a scroll container, not a pane/dock/split. Recommended path: import only the `TiledCellContent` protocol + `CellStateStorage` and compose inside wenshu's own `ChatView`. Maintainer: Hiroshi Kimura (muukii).

### 3.2 `exyte/Chat`

- **GitHub:** https://github.com/exyte/Chat
- **Stars / forks:** ~1,798 / 318 (verified)
- **License:** MIT
- **macOS support:** Yes, but readme focuses on iOS.
- **SwiftPM:** `.package(url: "https://github.com/exyte/Chat", from: "3.0.2")` (release 2026-05-27)
- **One-liner:** SwiftUI chat UI framework with customizable message cells, media picker, sticker keyboard, swipe actions, reply/edit/delete.
- **ADR-0008 verdict:** **VIEW-FRAMEWORK-FORBIDDEN** for `ChatView` (full chat pane); ALLOWED for individual renderers only. **Do not adopt the shell.**

### 3.3 `EnesKaraosman/SwiftyChat`

- **GitHub:** https://github.com/EnesKaraosman/SwiftyChat
- **Stars:** 349 (SPI)
- **License:** MIT
- **ADR-0008 verdict:** Same as exyte/Chat — full chat shell, VIEW-FRAMEWORK-FORBIDDEN. Listed for completeness.

### 3.4 Hand-rolled cells

- Chat bubble, code-block cell, thinking-trace cell, and tool-use card can each be plain SwiftUI `View`s in 50–150 LOC. ADR-0008 prefers Apple-stack primitives here.

---

## 4. Markdown + code-highlight rendering for chat messages

Content rendering only — no view-framework involvement, no pane replacement.

### 4.1 `gonzalezreal/swift-markdown-ui`

- **GitHub:** https://github.com/gonzalezreal/swift-markdown-ui
- **Stars:** ~3.9k / 554 forks (verified)
- **License:** MIT
- **macOS support:** Yes — macOS 12.0+ (some features need macOS 13+).
- **SwiftPM:** `.package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0")`
- **Status:** **Maintenance mode** as of Dec 2025 — author now actively develops `gonzalezreal/textual` (see #437). Existing releases still supported.
- **One-liner:** Markdown rendering as a SwiftUI `Markdown(_:)` view; GFM-compatible (headings, lists, task lists, blockquotes, code blocks, tables, images, links); themes + custom block/text style hooks.
- **Wenshu module fit:** `chat` — chat-message body rendering, especially fenced code blocks, tables, lists.
- **ADR-0008 verdict:** **ALLOWED — RECOMMENDED PRIMARY CANDIDATE** for markdown.

### 4.2 `gonzalezreal/textual` (successor)

- **GitHub:** https://github.com/gonzalezreal/textual
- **Stars:** 842 (verified)
- **License:** MIT
- **SwiftPM:** `.package(url: "https://github.com/gonzalezreal/textual", from: "0.1.0")` (verify latest tag before pinning)
- **One-liner:** SwiftUI-native rich-text engine grown from MarkdownUI; Markdown as one input among many, plus attachments, selection, performance improvements.
- **Wenshu module fit:** `chat`. More future-proof than MarkdownUI.
- **ADR-0008 verdict:** **ALLOWED — RECOMMENDED for new adoption** if wenshu needs attachments or fine-grained selection.

### 4.3 `raspu/Highlightr`

- **GitHub:** https://github.com/raspu/Highlightr
- **Stars:** ~1,861 (SPI)
- **License:** MIT
- **macOS support:** Yes (macOS 10.10+).
- **SwiftPM:** `.package(url: "https://github.com/raspu/Highlightr.git", .upToNextMajor(from: "2.2.0"))` (latest `2.3.0`, 2025-06-18)
- **One-liner:** macOS/iOS syntax highlighter wrapping `highlight.js` (185 langs, 89 themes); returns `NSAttributedString`.
- **Caveat:** README **explicitly deprecates** it as of 2026 — recommends `HighlighterSwift`.
- **ADR-0008 verdict:** **ALLOWED but not recommended** (upstream-deprecated). Consider `smittytone/HighlighterSwift` or Apple `swift-syntax` for Swift-only.

### 4.4 `JohnSundell/Splash`

- **GitHub:** https://github.com/JohnSundell/Splash
- **Stars:** 1,872 (verified)
- **License:** MIT
- **SwiftPM:** `.package(url: "https://github.com/JohnSundell/Splash", .upToNextMajor(from: "0.16.0"))`
- **One-liner:** Pure-Swift syntax highlighter (no JS); outputs `NSAttributedString`, HTML, or SwiftUI `Text`. Currently Swift-only.
- **Wenshu module fit:** `chat` — code-block cells where assistant emits Swift.
- **ADR-0008 verdict:** **ALLOWED — RECOMMENDED for Swift-only** code blocks. For multi-language, use `smittytone/HighlighterSwift`.

### 4.5 `1amageek/swift-artifact` (LLM artifact renderer)

- **GitHub:** https://github.com/1amageek/swift-artifact
- **Stars:** ~6–10 (SPI; small but recent)
- **License:** Verify per repo `LICENSE`.
- **macOS support:** Yes — `.macOS(.v26)` in latest manifest per SPI dump.
- **SwiftPM:** `.package(url: "https://github.com/1amageek/swift-artifact.git", from: "0.17.0")`
- **One-liner:** SwiftUI library for LLM-generated artifact blocks (Markdown, JSON, CSV, Code, SVG, GeoJSON, HTML, React, Mermaid, LaTeX, Vega-Lite, GLTF, USDZ) with **streaming partial render** during model output. Pluggable renderer protocol.
- **Wenshu module fit:** `chat` — directly addresses tool-use cards and rich artifact cells. Streaming partial render matches wenshu's token-by-token assistant output.
- **ADR-0008 verdict:** **ALLOWED for cells/renderers; CASE-BY-CASE for the umbrella** (transitively imports `CodeEditSourceEditor` and `swift-knowledge-graph`, both view-heavy). Recommend adopting **only** `ArtifactCore` + `ArtifactRenderer` + `ArtifactView` + `ArtifactNativeRenderer`; **skip** `ArtifactWebRenderer` (WKWebView-heavy).

### 4.6 Excluded from current scope

- `nodes-app/swift-markdown-engine` (AppKit/TextKit 2 Markdown **editor**, 963 ★, Apache-2.0) — editor pane, out of chat-cell scope.
- `qeude/SwiftDown` (SwiftUI Markdown **editor**, 571 ★, MIT) — editor pane, out of chat-cell scope.

---

## Summary recommendations

| Area | Primary recommendation | Secondary | Notes |
|---|---|---|---|
| 1. MCP SDK | Defer | Track `modelcontextprotocol/swift-sdk` v0.10.x | Not required for current in-process A2A. |
| 2. SSE | URLSession `.bytes(for:)` first; adopt `mattt/EventSource` v1.4.x | — | Apple-native first. |
| 3. Chat UI cells | Hand-roll first; adopt `FluidGroup/swiftui-messaging-ui` primitives if needed | `1amageek/swift-artifact` cells | Avoid exyte/Chat, SwiftyChat shells. |
| 4. Markdown + highlight | `gonzalezreal/textual` (new) or `gonzalezreal/swift-markdown-ui` (stable) | `JohnSundell/Splash` for Swift-only blocks | Skip Highlightr — upstream-deprecated. |

---

## Verified URLs

- https://github.com/modelcontextprotocol/swift-sdk
- https://github.com/modelcontextprotocol/modelcontextprotocol/issues/2326
- https://github.com/mattt/EventSource
- https://github.com/gonzalezreal/swift-markdown-ui
- https://github.com/gonzalezreal/textual
- https://github.com/FluidGroup/swiftui-messaging-ui
- https://github.com/exyte/Chat
- https://github.com/EnesKaraosman/SwiftyChat
- https://github.com/raspu/Highlightr
- https://github.com/JohnSundell/Splash
- https://github.com/1amageek/swift-artifact
- https://swiftpackageindex.com/mattt/EventSource
- https://swiftpackageindex.com/gonzalezreal/swift-markdown-ui
- https://swiftpackageindex.com/FluidGroup/swiftui-messaging-ui
- https://swiftpackageindex.com/exyte/Chat
- https://swiftpackageindex.com/raspu/Highlightr
- https://swiftpackageindex.com/keywords/chat

## Uncertain / not verified in this window

- `mattt/ollama-swift` — exact star count not retrieved; relevant only if wenshu later adds an Ollama provider.
- `DePasqualeOrg/swift-mcp` — star count not retrieved; verify before adoption.
- `nodes-app/swift-markdown-engine` and `qeude/SwiftDown` — stars verified but excluded from current scope (editor surface).
