# CLAUDE.md · 文枢 (Wenshu)

|> Truth-source pointer: `AGENTS.md` (project baseline §11 + cross-role address hard constraint §12).
|> Current wenshu = SwiftData (post-v0.72) + single executable target Sources/WenshuApp/ tree (= 1 WenshuApp target + 1 WenshuAppTests target; see Package.swift; = §3-§9 reflect this tree) (= post-2026-10-03 Apple multi-column rewrite; = §3-§9 reflect this tree; = the "v0.09 / v0.37 ship packet" baseline is the §11 era stamp). Long-term auto-pilot mode per 2026-09-03 (= I have push authority per "之前 push 就是你的活"). No 6-role flow, no dispatch, no board — pocock reads this when working on wenshu.
|> English-only rule applies to this file (see `AGENTS.md` top section). Sole address for the user = "老板".

---

## 1. Project Overview

> **文枢 = Apple stack exclusive long-form novel AI authoring platform** (= the canonical baseline).

**Project baseline** (= 2026-08-06, updated 2026-09-03):

- Project baseline: self-built Swift/SwiftUI desktop app + self-built lightweight AI kernel + BYOK LLM layer with 14 first-class + custom providers (= Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax / minimax cn / Nous / OpenAI Codex / GitHub Copilot / Copilot ACP / xAI OAuth / StepFun). The user configures key and uses.
- **Stack** = Swift / SwiftUI single-process app + SwiftData single-file `.ws` + Swift Concurrency actor serialization + LLM connector layer (14 first-class + custom, BYOK, provider-agnostic, see AGENTS.md §11.2).
- **Do NOT reuse** = any external AI platform / any AI platform process / any AI platform CLI / any monorepo / legacy wenshu monorepo fork / legacy plugin route.
- **Core user** = person with long-form novel idea but no writing experience (ordinary user).
- **v1 LLM connector layer** = 14 first-class + custom profiles, user BYOK, no default recommendation (see AGENTS.md §11.2).
- **`.ws` single file** = SwiftData + attachments, locally self-managed.
- **Platform** = macOS-only (single platform; iPad / iPhone single Swift/SwiftUI code is structurally supported but not yet target).
- **Version format** = three digits (Hermes style). Middle digit = phase, third digit = hotfix.

**Baseline info**:

- Project root = `/Volumes/ANAN/Engineering/wenshu/`
- Sandbox = `~/Engineering/llm-call-test/` + `~/Engineering/wenshu-arch-experiments/{Exp5-CoreData,Exp6-Concurrency}/`
- Legacy monorepo fork (read-only) = `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/` (9.7 GB)
- LICENSE = MIT (project itself). Connector protocols honored separately (Anthropic-compatible protocol for minimax cn is one of the 14 first-class profiles).
- LLM API key = self-configured (stored in macOS Keychain). Never in project. User picks profile in Settings → LLM Connector pane; no default.

## 2. Tech Stack

| Layer | Tech | Version | Selection reason |
|-------|------|---------|------------------|
| Language | Swift | 6.4+ | Apple native. SwiftUI 6 covers all 3 platforms. |
| Desktop | SwiftUI | macOS 14+ (`.macOS(.v27)` single platform) | Same code, 3-platform struct, macOS-first target. |
| Data store | SwiftData | Apple framework (= Apple-recommended; = replaced CoreData in v0.72 per AGENTS.md §11.4; = v1.79 chat-by-book row-level split per AGENTS.md §11.11 + docs/agents/v1.79-chat-by-book-row-split.md) | Cross-Apple, single-file, actor-friendly. |
| Concurrency | Swift Concurrency | Swift 5.5+ | actor serialization + Task async + AsyncSequence streaming. |
| LLM connector layer | 14 first-class + custom (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax / minimax cn / Nous / OpenAI Codex / GitHub Copilot / Copilot ACP / xAI OAuth / StepFun) | BYOK, provider-agnostic | Per AGENTS.md §11.2. minimax cn conforms to the Anthropic-compatible protocol (= one of the 14 first-class profiles). |
| Streaming | URLSession + self-built SSE parser | — | byte-level accumulation, event type classification. |
| Project format | `.ws` | SwiftData store + attachments | Local single-file, cross-device copy. |
| LLM key store | macOS Keychain | Apple framework | Never in file, log, or commit. |
| Multi-device sync | Self cloud (iCloudID / OneDrive / Git / USB) | — | 文枢 does not participate. 文枢 does not sense. |
| Payment | Apple Developer Program | Individual $99 / year | Paid only on App Store release. |
| Tests | XCTest + `swift test` | SwiftPM | Apple official test framework. |

**Used** (landed):

- Swift / SwiftUI / SwiftData (= Apple-recommended) / Swift Concurrency.
- 14 first-class + custom LLM profiles (BYOK, see AGENTS.md §11.2); minimax cn is one of the 14.
- `.ws` single file as project data.
- macOS Keychain for LLM keys.

**NOT used** (P0 / v0.00.x phase):

- Any external AI platform code / process / CLI.
- Any LLM provider framework (direct connect to LLM providers via wenshu connector layer — no LangChain / SwiftAI / Vercel AI SDK).
- Any cloud service / account / cross-device sync service.
- Any monorepo / npm / Python / Rust / Tauri / Vue.
- Any direct SQLite (use SwiftData, Apple-recommended persistence on macOS 14+; = no raw SQLite layer in new code).
- Any user-installer script / any hermes self-bootstrap chain.
- iCloud sync integration (user self cloud).
- iOS / iPadOS / Catalyst adapter (dead code = delete).

## 3. Directory Structure

```
wenshu/                                                ← project root
├── README.md                                          ← project face
├── AGENTS.md                                          ← collaboration rules truth source (English-only)
├── CLAUDE.md                                          ← this file
├── CONTEXT.md                                         ← domain glossary (see docs/agents/domain.md)
├── .hermes/                                           ← design drafts
├── Package.swift                                      ← SwiftPM entry (.macOS(.v27) single platform)
├── Sources/
│   └── WenshuApp/                                     ← SwiftUI App entry (macOS)
│       ├── App.swift                                  ← @main entry + AppRootScene
│       ├── DesignTokens.swift                         ← Apple HIG-measured spacing / radius / shadow tokens
│       ├── App/                                       ← scene-level orchestration
│       ├── Chat/                                      ← chat zone (ChatView, ChatSlashCommandAutocomplete)
│       ├── Core/                                      ← domain logic (Agent / Chat / LinkGraph / Memory / Provider / Search / Tools / Notifications / Auth / Foundation)
│       ├── Domain/                                    ← pure value types (Book / BookFolderCatalog / SmartQuery / ...)
│       ├── Editor/                                    ← markdown editor (EditorActions / EditorView)
│       ├── Persistence/                               ← SwiftData @Model + Container + Repositories
│       ├── Resources/                                 ← AppIcon.icns + Info.plist
│       ├── Settings/                                  ← user settings pane
│       ├── State/                                     ← @Observable state layer
│       ├── Storage/                                   ← file-system stores (LibraryMigrator / FileSystemReferenceStore)
│       ├── UI/                                        ← reusable SwiftUI components (IconStyles / DesignTokens / Layout / Segmented / Memory / PaneTabBar / ComponentIndex.md)
│       └── Views/                                     ← feature views (Chat / Library / Onboarding / SpecializedTools / Workspace / Kanban / Graph / Outline / LinkGraph / LinkBack / Windows / Tools / Todo / LayoutPicker / Inspection)
└── Tests/
    └── WenshuAppTests/                                ← XCTest + Swift Testing
        ├── Persistence/                               ← ContainerTests / Repository tests
        ├── Views/                                     ← feature view tests
        ├── Agent/                                     ← conductor / connector / tool tests
        └── Integration/                               ← IntegrationPlanEndToEndTests
```

## 4. Modules (文枢 perspective)

| Module | Path | Responsibility | Deps |
|--------|------|----------------|------|
| App entry | `Sources/WenshuApp/App.swift` + `Sources/WenshuApp/App/AppRootScene.swift` | SwiftUI App + NavigationSplitView root scene | SwiftUI |
| MainActor chat layer | `Sources/WenshuApp/Views/Chat/` | User chat always responsive, slash commands, tool diff preview | Core |
| Background agent tasks | `Sources/WenshuApp/Core/Agent/` | LLM call, chapter summary, research, revision candidate, style distill, librarian, todo, kanban, specialized tools | Core |
| SwiftData @Model + Container | `Sources/WenshuApp/Persistence/` | 28 explicit @Model classes + WSPersistenceContainer + 8 Repositories | SwiftData |
| LLM connector layer | `Sources/WenshuApp/Core/Agent/Connector/` | 14 first-class + custom (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax / minimax cn / Nous / OpenAI Codex / GitHub Copilot / Copilot ACP / xAI OAuth / StepFun); BYOK per AGENTS.md §11.2 | Connector APIs |
| Memory + context | `Sources/WenshuApp/Core/Memory/` + `Sources/WenshuApp/Core/Search/` | WSMemoryProvider + CSSearchableIndexSearch | Core |
| Notifications | `Sources/WenshuApp/Core/Notifications/` | AppNotifications | AppKit |
| Auth pool | `Sources/WenshuApp/Core/Auth/` | AuthPool | Security |
| Tools layer | `Sources/WenshuApp/Core/Tools/` | AVMediaTools + cross-tool helpers | Core |
| Library state | `Sources/WenshuApp/State/` + `Sources/WenshuApp/Views/Library/` | LayoutTreeState + SidebarService + LibraryRootView | App entry |
| Workspace / Editor / Tools panes | `Sources/WenshuApp/Views/Workspace/` + `Sources/WenshuApp/Editor/` + `Sources/WenshuApp/Views/Tools/` | EditorView + PreviewPane + specialized tools | App entry |
| Specialized tools UI | `Sources/WenshuApp/Views/SpecializedTools/` | IdeaLibraryView / CharacterLifecycleView / ForeshadowingView / etc. | Core |
| Kanban + Todo + Bookmark UI | `Sources/WenshuApp/Views/Kanban/` + `Sources/WenshuApp/Views/Todo/` | SubAgentProgressView / TodoListView | Core |

## 5. Web / IPC Interface (文枢 specific)

文枢 is a desktop app. No external Web / IPC. All internal comm via Swift actor / NotificationCenter / `@Published`.

| Internal interface | Path | Use |
|--------------------|------|-----|
| `WSPersistenceContainer` | `Sources/WenshuApp/Persistence/Container.swift` | SwiftData ModelContainer. Single ModelContainer per app (= 28 @Model classes). |
| `LLMConnector` protocol | `Sources/WenshuApp/Core/Agent/Connector/LLMConnector.swift` | Abstract LLM call. 14 first-class + custom profiles conform (Anthropic native / OpenAI native / OpenAI-compatible / Gemini native + OpenAI Codex OAuth + GitHub Copilot ACP). See AGENTS.md §11.2. |
| `ContextAssembler` (= `CSSearchableIndexSearch`) | `Sources/WenshuApp/Core/Search/CSSearchableIndexSearch.swift` | Long-term memory → LLM minimal context (Apple Core Spotlight backed). |
| Stage gate | not yet implemented (= pre-pinned for v0.41+ backlog; = see wenshu-pocock-workflow references) | (placeholder) |

## 6. Project Conventions

- **Code style** = Swift official API Design Guidelines + SwiftLint standard config (`swift run swiftlint` inside `wenshu/`).
- **Tests** = XCTest + Swift Testing (`swift test` in `wenshu/` root).
- **Git** = git (self-managed, no GitHub repo needed for local dev).
- **Do not add** any dep mgmt tool, ORM, HTTP client framework, JSON parser framework — use Swift stdlib.

## 7. Security (pocock must-read, derived from AGENTS.md §11)

- **Data asset = self-managed** — `.ws` single file = the project data. 文枢 no cloud, no sign, no upload.
- **Cross-device = self-managed** — copies `.ws` via iCloud / OneDrive / Git / USB. 文枢 does not participate.
- **Multi-device multi-entry via master router** — iPhone-recorded ideas go through master process. No direct modification of main project (avoid multi-end concurrent overwrite).
- **Conflict resolution = version + post-decide** — file-level version, validate on open, mismatch = backup old + create new copy.
- **Data survives uninstall** — after uninstall 文枢, `.ws` preserved.
- **LLM keys in macOS Keychain** — never plaintext in file, log, commit message. Each of the 14 first-class + custom profiles has its own Keychain entry (see AGENTS.md §11.2 + §11.3).
- **Archived legacy monorepo fork read + write blocked** — `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/` is read-only history. pocock cannot modify.

## 8. Verification (pocock must-run after coding)

```bash
# wenshu/ root
cd /Volumes/ANAN/Engineering/wenshu

# Build
swift build

# Unit tests
swift test

# Integration tests
swift test --filter WenshuIntegrationTests

# Code style
swift run swiftlint

# User journey test
# macOS actually runs:
# 1. swift run WenshuApp or open wenshu.xcodeproj
# 2. Create project
# 3. Write one-sentence story
# 4. AI extrapolate
# 5. Generate character / world skeleton
# 6. Close and reopen
# 7. Cross-device copy .ws to iPad
# 8. iPad opens same .ws, validate data consistency
```

## 9. Project Baseline Context (pocock must-read first)

> **Most important section. pocock reads first when taking on a task.**

文枢 = Swift / SwiftUI self-built desktop app + SwiftData + 14-first-class + custom LLM layer (BYOK, see AGENTS.md §11.2). **Forbidden**:

- Introduce any external AI platform dependency.
- Introduce any LLM framework (LangChain / SwiftAI / Vercel AI SDK / OpenAI Swift Client etc.).
- Introduce any monorepo / npm / Python / Rust / Tauri / Vue.
- Direct connect SQLite (use SwiftData, Apple-recommended persistence on macOS 14+; = no raw SQLite layer in new code).
- Any user-installer script / any hermes self-bootstrap chain.
- iCloud sync integration (user self cloud).
- Change LICENSE text.
- Change LLM connector layer signature (change = escalate).
- Change `.ws` schema (add / remove entity / change field type = escalate).
- Skip quality gate (change = escalate).
- Decide product requirement.
- Configure LLM keys (each of 14 first-class + custom providers must be self-configured; see AGENTS.md §11.2).
- Upload `.ws` to cloud.
- Touch any hermes self-owned file under `~/.hermes/`.
- Touch any file under `.archive/wenshu-monorepo-fork/`.
- Touch `~/wenshu-plugin/` (legacy plugin era artifact, retired).
- Write any file to `~/.wenshu/` (dir retired).
- Self-write `wenshu` CLI (文枢 = Swift desktop app, not CLI).
- Write wrong model name (8/6 real test: when active profile is minimax cn, it silently falls back to `MiniMax-M3`; task must specify minimax official model name).

**minimax cn model whitelist** (2026-08-06 from minimax official docs; applies when active connector profile = minimax cn per AGENTS.md §11.2):

- `MiniMax-M3` (recommended, 1M context, Coding / Agentic SOTA).
- `MiniMax-M2.7` / `MiniMax-M2.7-highspeed` (60 TPS / 100 TPS).
- `MiniMax-M2.5` / `MiniMax-M2.5-highspeed`.
- `MiniMax-M2.1` / `MiniMax-M2.1-highspeed`.
- `MiniMax-M2`.
- `M2-her` (chat scenario, 64K context).

**minimax cn endpoint + auth** (when active connector profile = minimax cn):

- Endpoint = `https://api.minimaxi.com/anthropic/v1/messages`.
- Auth = `X-Api-Key: *** (`Authorization: Bearer *** also OK).
- SSE streaming, event sequence = `message_start` → `content_block_start` → `ping` → `content_block_delta` → `content_block_stop` → `message_delta` → `message_stop`. No `[DONE]` terminator.
- Content block types = `text` / `thinking` / `tool_use` / `image`.
- Tool use = `tools: [{name, description, input_schema}]` + `tool_choice: {type: auto}`.

**Other 6 connector profile endpoints** (per AGENTS.md §11.2; user self-configures base URL + key in Settings → LLM Connector pane):

- Anthropic: `https://api.anthropic.com/v1/messages` (Anthropic native; `x-api-key` + `anthropic-version: 2023-06-01`).
- OpenAI: `https://api.openai.com/v1/chat/completions` (OpenAI native; `Authorization: Bearer ***`).
- DeepSeek: `https://api.deepseek.com/v1/chat/completions` (Anthropic-compatible).
- Gemini: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` (Gemini native).
- Ollama: `http://localhost:11434/v1/chat/completions` (OpenAI-compatible; no auth, local).
- OpenRouter: `https://openrouter.ai/api/v1/chat/completions` (OpenAI-compatible; one key, all models).

**pocock key file list** (current at v0.72 SwiftData + 14-first-class + custom LLM era):

- `Sources/WenshuApp/App.swift` — SwiftUI App entry.
- `Sources/WenshuApp/App/AppRootScene.swift` — NavigationSplitView root scene.
- `Sources/WenshuApp/Persistence/WS*.swift` — SwiftData @Model classes (schema change requires escalation).
- `Sources/WenshuApp/Persistence/Container.swift` — SwiftData ModelContainer setup (= 28 @Model classes, single container per app).
- `Sources/WenshuApp/Core/Agent/Connector/LLMConnector.swift` — LLM connector protocol (14 first-class + custom BYOK profiles conform per AGENTS.md §11.2).
- `Sources/WenshuApp/Core/Agent/Connector/SSEParser.swift` — SSE streaming parser (by event type).
- `Sources/WenshuApp/Core/Search/CSSearchableIndexSearch.swift` — context assembly (Apple Core Spotlight).
- `Sources/WenshuApp/Editor/EditorView.swift` — body editor.

## 10. References

- Truth source = `AGENTS.md` (project baseline §11 + §11.1 third-party lib policy + §11.2 LLM connector profiles + §11.3 agent ↔ other Core module interaction principle + cross-role address hard constraint §12).
- Project face = `README.md`.
- Domain glossary = `CONTEXT.md`.
- Sandbox experiments:
  - `~/Engineering/llm-call-test/` — experiment 4: minimax cn LLM call (Anthropic-compatible).
  - `~/Engineering/wenshu-arch-experiments/Exp5-CoreData/` — experiment 5: CoreData single file.
  - `~/Engineering/wenshu-arch-experiments/Exp6-Concurrency/` — experiment 6: Swift Concurrency + CoreData.
- Legacy monorepo fork (read-only) = `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/`.
- minimax cn API = `https://api.minimaxi.com/anthropic/v1/messages`.
- minimax cn docs = `https://platform.minimaxi.com/docs/llms.txt`.
- minimax cn model whitelist = see §9.
- Apple Developer Program = paid individual $99 / year on release.
- iOS 27 simulator = not yet public. iPad / iPhone real-machine test pending iOS 27 sim public release.

---

*CLAUDE.md · 2026-09-03 v0.08.0 (initial) → 2026-10-04 v0.09+ (Q99 dual-axis path / spec drift fix-up; = §3-§9 rewrote to current tree; = the Q99 SPEC axis run added §3 directory structure, §4 modules table, §5 interface table, §9 pocock key file list sync to Sources/WenshuApp/ post-v0.72 SwiftData era; = the v0.08 minimax cn narrative + 14-first-class + custom BYOK architecture retained from initial ship) · English-only · project root = `/Volumes/ANAN/Engineering/wenshu/`*