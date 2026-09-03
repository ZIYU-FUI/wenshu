# CLAUDE.md · 文枢 (Wenshu)

> Truth-source pointer: `AGENTS.md` (project baseline §11 + cross-role address hard constraint §12).
> v0.08 (2026-09-03 pocock single-agent purified version). AGENTS.md §11 baseline rewritten: 7 connector profiles (§11.2) + agent ↔ other Core module interaction principle (§11.3) + tool-only product positioning. No 6-role flow, no dispatch, no board — pocock reads this when working on wenshu.
> English-only rule applies to this file (see `AGENTS.md` top section). Sole address for the user = "老板".

---

## 1. Project Overview

> **文枢 = Apple stack exclusive long-form novel AI authoring platform** (2026-08-06 老板 拍板).

**Project baseline** (2026-08-06 老板 拍板, updated 2026-09-03):

- 老板 拍板 "self-built Swift/SwiftUI desktop app + self-built lightweight AI kernel + BYOK 7-connector LLM layer (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax cn). 老板 configures key and uses."
- **Stack** = Swift / SwiftUI single-process app + CoreData single-file `.ws` + Swift Concurrency actor serialization + LLM connector layer (7 profiles, BYOK, provider-agnostic, see AGENTS.md §11.2).
- **Do NOT reuse** = any external AI platform / any AI platform process / any AI platform CLI / any monorepo / legacy wenshu monorepo fork / legacy plugin route.
- **Core user** = person with long-form novel idea but no writing experience (ordinary user).
- **v1 LLM connector layer** = 7 profiles, user BYOK, no default recommendation (see AGENTS.md §11.2 for the 7 profiles).
- **`.ws` single file** = CoreData + attachments, locally self-managed.
- **Platform** = macOS-only (单 platform per 老板 8/18 拍; iPad / iPhone single Swift/SwiftUI code is structurally supported but not yet target).
- **Version format** = three digits (Hermes style). Middle digit = phase, third digit = hotfix.

**Baseline info**:

- Project root = `/Volumes/ANAN/Engineering/wenshu/`
- Sandbox = `~/Engineering/llm-call-test/` + `~/Engineering/wenshu-arch-experiments/{Exp5-CoreData,Exp6-Concurrency}/`
- Legacy monorepo fork (read-only) = `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/` (9.7 GB)
- LICENSE = MIT (project itself). Connector protocols honored separately (Anthropic-compatible protocol for minimax cn is one of 7 connector profiles).
- LLM API key = 老板 self-configured (stored in macOS Keychain). Never in project. User picks profile in Settings → LLM Connector pane; no default.

## 2. Tech Stack

| Layer | Tech | Version | Selection reason |
|-------|------|---------|------------------|
| Language | Swift | 6.4+ | Apple native. SwiftUI 6 covers all 3 platforms. |
| Desktop | SwiftUI | macOS 14+ (`.macOS(.v27)` single platform per 老板 8/18 拍) | Same code, 3-platform struct, macOS-first target. |
| Data store | CoreData | Apple framework | Cross-Apple, single-file, actor-friendly. |
| Concurrency | Swift Concurrency | Swift 5.5+ | actor serialization + Task async + AsyncSequence streaming. |
| LLM connector layer | 7 profiles (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax cn) | BYOK, provider-agnostic | Per AGENTS.md §11.2. minimax cn is one of 7 connectors (Anthropic-compatible). |
| Streaming | URLSession + self-built SSE parser | — | byte-level accumulation, event type classification. |
| Project format | `.ws` | CoreData store + attachments | Local single-file, cross-device copy. |
| LLM key store | macOS Keychain | Apple framework | Never in file, log, or commit. |
| Multi-device sync | Self cloud (iCloudID / OneDrive / Git / USB) | — | 文枢 does not participate. 文枢 does not sense. |
| Payment | Apple Developer Program | Individual $99 / year | Paid only on App Store release. |
| Tests | XCTest + `swift test` | SwiftPM | Apple official test framework. |

**Used** (landed):

- Swift / SwiftUI / CoreData / Swift Concurrency.
- 7 LLM connector profiles (BYOK, see AGENTS.md §11.2); minimax cn is the boss v0 test default.
- `.ws` single file as project data.
- macOS Keychain for LLM keys.

**NOT used** (P0 / v0.00.x phase):

- Any external AI platform code / process / CLI.
- Any LLM provider framework (direct connect to LLM providers via wenshu connector layer — no LangChain / SwiftAI / Vercel AI SDK).
- Any cloud service / account / cross-device sync service.
- Any monorepo / npm / Python / Rust / Tauri / Vue.
- Any direct SQLite (use CoreData, no SQLite layer).
- Any user-installer script / any hermes self-bootstrap chain.
- Any iCloud sync integration (老板 self cloud).
- Any iOS / iPadOS / Catalyst adapter (dead code = delete).

## 3. Directory Structure

```
wenshu/                                                ← project root (v0.00.0)
├── README.md                                          ← project face (landed v0.07)
├── AGENTS.md                                          ← collaboration rules truth source (2026-08-22 English-only)
├── CLAUDE.md                                          ← this file (landed v0.08)
├── CONTEXT.md                                         ← domain glossary (see docs/agents/domain.md)
├── .hermes/                                           ← design drafts (v0.07 sketch truth source etc.)
├── wenshu.xcodeproj/                                  ← Xcode project (v0.01.0+)
├── Package.swift                                      ← SwiftPM entry (v0.01.0+)
├── Sources/
│   ├── WenshuApp/                                     ← SwiftUI App entry (macOS)
│   ├── WenshuCore/                                    ← core (cross-platform shared)
│   │   ├── Model/   (CDCharacter / CDChapter / CDNote / CDWorldRule / CDForeshadow / CDRevision / CDAIDraft)
│   │   ├── Store/   (WenshuStoreActor / PersistenceController / WenshuModel.xcdatamodeld)
│   │   ├── LLM/     (LLMProvider / connector profiles / SSEParser / LLMMessage)
│   │   ├── Search/  (ContextAssembler / ChapterSummarizer)
│   │   ├── Stage/   (StageGate / StageDetector)
│   │   ├── Marker/  (TodoMarker / ForeshadowMarker / InfoPointMarker / FactCheckMarker)
│   │   ├── Revision/(RevisionManager / DiffRenderer)
│   │   └── Style/   (BuiltinStyles / StyleDistiller / StyleInference)
│   ├── WenshuUI/                                      ← SwiftUI views (cross-platform)
│   │   ├── ChatView / ProjectListView / DashboardView / EditorView / RelationGraphView / TimelineView / EmotionCurveView / DetailView
│   └── WenshuPlatform/                                ← platform-specific (macOS / iPadOS / iOS)
└── Tests/
    ├── WenshuCoreTests/                               ← unit tests
    └── WenshuIntegrationTests/                        ← integration tests
```

## 4. Modules (文枢 perspective)

| Module | Path | Responsibility | Deps |
|--------|------|----------------|------|
| MainActor chat layer | `Sources/WenshuApp/` | User chat always responsive, stage gate, board render, `@` syntax parse | WenshuCore, WenshuUI |
| Background tasks | `Sources/WenshuCore/LLM/` + `/Search/` | LLM call, chapter summary, research, revision candidate, style distill | WenshuCore, LLM connector layer |
| Store actor | `Sources/WenshuCore/Store/` | CoreData write serialization, transaction, version mgmt | CoreData |
| LLM connector layer | `Sources/WenshuCore/LLM/` | 7 connector profiles (BYOK, see AGENTS.md §11.2), SSE streaming, key mgmt | Connector APIs |
| Stage gate | `Sources/WenshuCore/Stage/` | Idea / setting / outline / body stage switch, maturity judge | WenshuCore |
| Marker system | `Sources/WenshuCore/Marker/` | `※` todo / foreshadow / info-point / fact-check | WenshuCore |
| Revision candidate | `Sources/WenshuCore/Revision/` | Revision generation, redline diff, post-confirm | WenshuCore |
| Writing style | `Sources/WenshuCore/Style/` | Built-in + user reverse-inference + upload distill | WenshuCore |
| Context assembly | `Sources/WenshuCore/Search/` | Long-term memory → LLM minimal context | WenshuCore, LLM connector layer |
| Board | `Sources/WenshuUI/DashboardView.swift` | Main stage smart filter, detail page full expand | WenshuCore |
| Editor | `Sources/WenshuUI/EditorView.swift` | Body edit, selection right-click, marker, revision display | WenshuCore |
| Relation graph | `Sources/WenshuUI/RelationGraphView.swift` | Character relationship visualization | WenshuCore |
| Timeline | `Sources/WenshuUI/TimelineView.swift` | Story timeline | WenshuCore |
| Emotion curve | `Sources/WenshuUI/EmotionCurveView.swift` | Emotion / pacing / intensity curve | WenshuCore |

## 5. Web / IPC Interface (文枢 specific)

文枢 is a desktop app. No external Web / IPC. All internal comm via Swift actor / NotificationCenter / `@Published`.

| Internal interface | Path | Use |
|--------------------|------|-----|
| `WenshuStore` actor | `Sources/WenshuCore/Store/` | CoreData write serialization. Only cross-module write entry. |
| `LLMConnector` protocol | `Sources/WenshuCore/LLM/LLMConnector.swift` | Abstract LLM call. 7 connector profiles conform (Anthropic native / OpenAI native / OpenAI-compatible / Gemini native). See AGENTS.md §11.2. |
| `ContextAssembler` | `Sources/WenshuCore/Search/ContextAssembler.swift` | Long-term memory → LLM minimal context. |
| `StageGate` | `Sources/WenshuCore/Stage/StageGate.swift` | Stage gate main controller. |

## 6. Project Conventions

- **Code style** = Swift official API Design Guidelines + SwiftLint standard config (`swift run swiftlint` inside `wenshu/`).
- **Tests** = XCTest + Swift Testing (`swift test` in `wenshu/` root).
- **Git** = git (老板 self-managed, no GitHub repo needed for local dev).
- **Do not add** any dep mgmt tool, ORM, HTTP client framework, JSON parser framework — use Swift stdlib.

## 7. Security (pocock must-read, derived from AGENTS.md §11)

- **Data asset = 老板 self-managed** — `.ws` single file = 老板 project data. 文枢 no cloud, no sign, no upload.
- **Cross-device = 老板** — 老板 copies `.ws` via iCloud / OneDrive / Git / USB. 文枢 does not participate.
- **Multi-device multi-entry via master router** — iPhone-recorded ideas go through master process. No direct modification of main project (avoid multi-end concurrent overwrite).
- **Conflict resolution = version + 老板 post-decide** — file-level version, validate on open, mismatch = backup old + create new copy.
- **Data survives uninstall** — after uninstall 文枢, `.ws` preserved.
- **LLM keys in macOS Keychain** — never plaintext in file, log, commit message. 7 connector profiles each have their own Keychain entry (see AGENTS.md §11.2 + §11.3).
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

文枢 = Swift / SwiftUI self-built desktop app + CoreData + 7-connector LLM layer (BYOK, see AGENTS.md §11.2). **Forbidden**:

- Introduce any external AI platform dependency.
- Introduce any LLM framework (LangChain / SwiftAI / Vercel AI SDK / OpenAI Swift Client etc.).
- Introduce any monorepo / npm / Python / Rust / Tauri / Vue.
- Direct connect SQLite (use CoreData, no SQLite layer).
- Any user-installer script / any hermes self-bootstrap chain.
- Any iCloud sync integration (老板 self cloud).
- Change LICENSE text.
- Change LLM connector layer signature (change = escalate to 老板).
- Change `.ws` schema (add / remove entity / change field type = escalate to 老板).
- Skip quality gate (change = escalate to 老板).
- Decide product requirement for 老板.
- Configure LLM keys for 老板 (each of 7 connectors must be self-configured; see AGENTS.md §11.2).
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

**pocock key file list** (v0.08 phase, post-baseline-rewrite):

- `Sources/WenshuApp/App.swift` — SwiftUI App entry.
- `Sources/WenshuApp/MainView.swift` — main view.
- `Sources/WenshuCore/Model/*.swift` — CoreData entity (schema change requires 老板 拍).
- `Sources/WenshuCore/Store/WenshuStoreActor.swift` — CoreData write serialization.
- `Sources/WenshuCore/LLM/LLMConnector.swift` — LLM connector protocol (7 profiles conform).
- `Sources/WenshuCore/LLM/SSEParser.swift` — SSE streaming parser (by event type).
- `Sources/WenshuCore/Stage/StageGate.swift` — stage gate.
- `Sources/WenshuCore/Search/ContextAssembler.swift` — long-term memory → LLM context.
- `Sources/WenshuUI/EditorView.swift` — body editor.

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

*CLAUDE.md v0.08.0 · 2026-09-03 pocock single agent · AGENTS.md §11 baseline rewrite (§11.2 7 connector profiles + §11.3 agent ↔ other Core module interaction principle + product-positioning rule) sync to CLAUDE.md · minimax cn narrative (16 mentions) rewritten to 7-connector BYOK architecture · English-only · project root = `/Volumes/ANAN/Engineering/wenshu/`*