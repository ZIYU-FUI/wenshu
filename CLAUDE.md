# CLAUDE.md · 文枢 (Wenshu)

> Auto-loaded project context when CC (future Claude Code CLI) starts.
> Truth-source pointer: @AGENTS.md (project baseline §11 + cross-role address hard constraint §12)
> v0.02.0 layout grammar (5 zones + collapse + drag) — see @AGENTS.md §11
> Project baseline v0.07 (2026-08-18 pocock single agent purified version)

**English-only rule applies to this file** (see AGENTS.md top section). Sole address for the user = "老板". Do not use earlier honorific forms.

---

## 1. Project Overview

> **文枢 = Apple stack exclusive long-form novel AI authoring platform** (2026-08-06 老板拍板)

**Project baseline** (2026-08-06 老板拍板):
- 老板拍板 "self build Swift/SwiftUI desktop app + self build lightweight AI kernel + minimax cn LLM (Anthropic compatible, minimax official recommended), you configure key and use"
- **Stack = Swift/SwiftUI single-process app + CoreData single-file `.ws` + Swift Concurrency actor serialization + LLM provider abstraction (minimax cn, Anthropic compatible)**
- **Do NOT reuse**: any external AI platform / any AI platform process / any AI platform CLI / any monorepo / legacy wenshu monorepo fork / legacy plugin route
- **Core user**: person with long-form novel idea but no writing experience (ordinary user)
- **v1 LLM provider**: minimax cn (老板 configures API key, Anthropic compatible)
- **`.ws` single file** = CoreData + attachments, locally self managed
- **Platform**: macOS / iPad / iPhone (same Swift/SwiftUI code, interaction adapted)
- **Version format**: three digits (Hermes style), middle digit = phase, third digit = hotfix

**Baseline info**:
- Project root = `/Volumes/ANAN/Engineering/wenshu/`
- Sandbox = `~/Engineering/llm-call-test/` + `~/Engineering/wenshu-arch-experiments/{Exp5-CoreData,Exp6-Concurrency}/`
- Legacy monorepo fork = `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/` (read-only, 9.7GB)
- LICENSE = MIT (project itself), minimax cn protocol honored separately
- LLM API key = 老板 self configured (stored in macOS Keychain), never in project

## 2. Tech Stack

| Layer | Tech | Version | Selection reason |
|-------|------|---------|------------------|
| Language | Swift | 6.4+ | Apple native, SwiftUI 6 covers all 3 platforms |
| Desktop | SwiftUI | iOS 17 / iPadOS 17 / macOS 14+ | Same code, 3 platforms, auto-adapt |
| Data store | CoreData | Apple framework | Cross-Apple, single-file, actor-friendly |
| Concurrency | Swift Concurrency | Swift 5.5+ | actor serialization + Task async + AsyncSequence streaming |
| LLM provider | minimax cn | Anthropic compatible | minimax official recommended, supports thinking block / tool_use / 1M context, SSE streaming |
| Streaming | URLSession + self-built SSE parser | - | byte-level accumulation, event type classification |
| Project format | `.ws` | CoreData store + attachments | Local single-file, cross-device copy |
| LLM key store | macOS Keychain | Apple framework | Never in file, log, or commit |
| Multi-device sync | Self cloud (iCloudID / OneDrive / Git / USB) | - | 文枢 does not participate, 文枢 does not sense |
| Payment | Apple Developer Program | Individual $99/year | Paid only on App Store release |
| Tests | XCTest + `swift test` | SwiftPM | Apple official test framework |

**Used** (landed):
- Swift / SwiftUI / CoreData / Swift Concurrency
- minimax cn LLM (Anthropic compatible)
- `.ws` single file as project data
- macOS Keychain for LLM key

**NOT used** (P0 / v0.00.x phase):
- Any external AI platform code / process / CLI
- Any LLM provider framework (direct connect to minimax cn, no LangChain / SwiftAI / Vercel AI SDK)
- Any cloud service / account / cross-device sync service
- Any monorepo / any npm / any Python / any Rust / any Tauri / any Vue
- Any direct SQLite (use CoreData, no SQLite layer)
- Any user-installer script / any hermes self-bootstrap chain
- Any iCloud sync integration (老板 self cloud)

## 3. Directory Structure

```
wenshu/                                                ← project root (v0.00.0)
├── README.md                                          ← project face (landed v0.07)
├── AGENTS.md                                          ← collaboration rules truth source (2026-08-22 English-only)
├── CLAUDE.md                                          ← this file (landed v0.07)
├── .hermes/                                           ← design drafts (v0.07 sketch truth source etc.)
├── wenshu.xcodeproj/                                  ← Xcode project (v0.01.0+)
├── Package.swift                                      ← SwiftPM entry (v0.01.0+)
├── Sources/
│   ├── WenshuApp/                                     ← SwiftUI App entry (macOS)
│   ├── WenshuCore/                                    ← core (cross-platform shared)
│   │   ├── Model/   (CDCharacter / CDChapter / CDNote / CDWorldRule / CDForeshadow / CDRevision / CDAIDraft)
│   │   ├── Store/   (WenshuStoreActor / PersistenceController / WenshuModel.xcdatamodeld)
│   │   ├── LLM/     (LLMProvider / MinimaxProvider / SSEParser / LLMMessage)
│   │   ├── Search/  (ContextAssembler / ChapterSummarizer)
│   │   ├── Stage/   (StageGate / StageDetector)
│   │   ├── Marker/  (TodoMarker / ForeshadowMarker / InfoPointMarker / FactCheckMarker)
│   │   ├── Revision/(RevisionManager / DiffRenderer)
│   │   └── Style/   (BuiltinStyles / StyleDistiller / StyleInference)
│   ├── WenshuUI/                                      ← SwiftUI views (cross-platform)
│   │   ├── ChatView / ProjectListView / DashboardView / EditorView / RelationGraphView / TimelineView / EmotionCurveView / DetailView
│   └── WenshuPlatform/                                ← platform specific (macOS / iPadOS / iOS)
└── Tests/
    ├── WenshuCoreTests/                               ← unit tests
    └── WenshuIntegrationTests/                        ← integration tests
```

## 4. Modules (文枢 perspective)

| Module | Path | Responsibility | Deps |
|--------|------|----------------|------|
| MainActor chat layer | `Sources/WenshuApp/` | User chat always responsive, stage gate, board render, @ syntax parse | WenshuCore, WenshuUI |
| Background tasks | `Sources/WenshuCore/LLM/` + `/Search/` | LLM call, chapter summary, research, revision candidate, style distill | WenshuCore, LLM provider |
| Store actor | `Sources/WenshuCore/Store/` | CoreData write serialization, transaction, version mgmt | CoreData |
| LLM provider | `Sources/WenshuCore/LLM/` | minimax cn (Anthropic compatible), SSE streaming, key mgmt | minimax cn API |
| Stage gate | `Sources/WenshuCore/Stage/` | Idea / setting / outline / body stage switch, maturity judge | WenshuCore |
| Marker system | `Sources/WenshuCore/Marker/` | ※todo / foreshadow / info-point / fact-check | WenshuCore |
| Revision candidate | `Sources/WenshuCore/Revision/` | Revision generation, redline diff, post-confirm | WenshuCore |
| Writing style | `Sources/WenshuCore/Style/` | Built-in + user reverse-inference + upload distill | WenshuCore |
| Context assembly | `Sources/WenshuCore/Search/` | Long-term memory → LLM minimal context | WenshuCore, LLM provider |
| Board | `Sources/WenshuUI/DashboardView.swift` | Main stage smart filter, detail page full expand | WenshuCore |
| Editor | `Sources/WenshuUI/EditorView.swift` | Body edit, selection right-click, marker, revision display | WenshuCore |
| Relation graph | `Sources/WenshuUI/RelationGraphView.swift` | Character relationship visualization | WenshuCore |
| Timeline | `Sources/WenshuUI/TimelineView.swift` | Story timeline | WenshuCore |
| Emotion curve | `Sources/WenshuUI/EmotionCurveView.swift` | Emotion / pacing / intensity curve | WenshuCore |

## 5. Web / IPC Interface (文枢 specific)

文枢 is a desktop app, no external Web/IPC. All internal comm via Swift actor / NotificationCenter / @Published.

| Internal interface | Path | Use |
|--------------------|------|-----|
| `WenshuStore` actor | `Sources/WenshuCore/Store/` | CoreData write serialization, only cross-module write entry |
| `LLMProvider` protocol | `Sources/WenshuCore/LLM/LLMProvider.swift` | Abstract LLM call, MinimaxProvider is only impl (Anthropic compatible) |
| `ContextAssembler` | `Sources/WenshuCore/Search/ContextAssembler.swift` | Long-term memory → LLM minimal context |
| `StageGate` | `Sources/WenshuCore/Stage/StageGate.swift` | Stage gate main controller |

## 6. Project Conventions

- **Code style**: Swift official API Design Guidelines + SwiftLint standard config (`swift run swiftlint` inside wenshu/)
- **Tests**: XCTest + Swift Testing (`swift test` in wenshu/ root)
- **Git**: git (老板 self managed, no GitHub repo needed for local dev)
- **Do not add** any dep mgmt tool, ORM, HTTP client framework, JSON parser framework — use Swift stdlib

## 7. Security (CC must-read, derived from AGENTS.md §11)

- **Data asset = 老板 self managed** — `.ws` single file = 老板 project data, 文枢 no cloud, / no sign, / no upload
- **Cross-device = 老板** — 老板 copies `.ws` / iCloud / OneDrive / Git / USB, 文枢 no participation
- **Multi-device multi-entry via master router** — iPhone-recorded ideas must go through master process, no direct modification of main project (avoid multi-end concurrent overwrite)
- **Conflict resolution: version + 老板 post-decide** — file-level version, validate on open, mismatch = backup old + create new copy
- **Data survives uninstall** — after uninstall 文枢, `.ws` preserved
- **LLM key in macOS Keychain** — never plaintext in file, log, commit message
- **Archived legacy monorepo fork read+write blocked** — `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/` is read-only history, CC cannot modify

## 8. Verification (CC must-read after coding)

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

## 9. Project Baseline Context (CC must-read)

> **This section is most important, CC reads first when taking on task**

文枢 = Swift/SwiftUI self-built desktop app + CoreData + minimax cn LLM (Anthropic compatible). **Forbidden**:

- Introduce any external AI platform dependency
- Introduce any LLM framework (LangChain / SwiftAI / Vercel AI SDK / OpenAI Swift Client etc.)
- Introduce any monorepo / any npm / any Python / any Rust / any Tauri / any Vue
- Direct connect SQLite (use CoreData, no SQLite layer)
- Any user-installer script / any hermes self-bootstrap chain
- Any iCloud sync integration (老板 self cloud)
- Change LICENSE text
- Change LLM provider signature (change = escalate to PM)
- Change `.ws` schema (add/remove entity / change field type, change = escalate to PM)
- Skip quality gate (change = escalate to PM)
- Decide product requirement for 老板
- Configure LLM key for 老板 (key must be self-configured)
- Upload `.ws` to cloud
- Touch any hermes self owned file under `~/.hermes/`
- Touch any file under `.archive/wenshu-monorepo-fork/`
- Touch `~/wenshu-plugin/` (legacy plugin era artifact, retired)
- Write any file to `~/.wenshu/` (dir retired)
- Self write `wenshu` CLI (文枢 = Swift desktop app, not CLI)
- Write wrong model name (8/6 real test: minimax silently falls back to `MiniMax-M3`, task must specify minimax official model name)

**minimax cn model whitelist** (2026-08-06 from minimax official docs):
- `MiniMax-M3` (recommended, 1M context, Coding / Agentic SOTA)
- `MiniMax-M2.7` / `MiniMax-M2.7-highspeed` (60 TPS / 100 TPS)
- `MiniMax-M2.5` / `MiniMax-M2.5-highspeed`
- `MiniMax-M2.1` / `MiniMax-M2.1-highspeed`
- `MiniMax-M2`
- `M2-her` (chat scenario, 64K context)

**minimax cn endpoint & Auth**:
- Endpoint: `https://api.minimaxi.com/anthropic/v1/messages`
- Auth: `X-Api-Key: <key>` (Authorization: Bearer <key> also ok)
- SSE streaming, event sequence: `message_start` → `content_block_start` → `ping` → `content_block_delta` → `content_block_stop` → `message_delta` → `message_stop`, no [DONE] terminator
- Content block types: `text` / `thinking` / `tool_use` / `image`
- Tool use: `tools: [{name, description, input_schema}]` + `tool_choice: {type: auto}`

**CC change key file list** (v0.07 phase):
- `Sources/WenshuApp/App.swift` — SwiftUI App entry
- `Sources/WenshuApp/MainView.swift` — main view
- `Sources/WenshuCore/Model/*.swift` — CoreData entity (schema change requires PM拍)
- `Sources/WenshuCore/Store/WenshuStoreActor.swift` — CoreData write serialization
- `Sources/WenshuCore/LLM/MinimaxProvider.swift` — minimax cn impl (Anthropic compatible)
- `Sources/WenshuCore/LLM/SSEParser.swift` — SSE streaming parser (by event type)
- `Sources/WenshuCore/Stage/StageGate.swift` — stage gate
- `Sources/WenshuCore/Search/ContextAssembler.swift` — long-term memory → LLM context
- `Sources/WenshuUI/EditorView.swift` — body editor

## 10. References

- Truth source: `AGENTS.md` (project baseline §11 + cross-role address hard constraint §12)
- Project face: `README.md`
- Sandbox experiments:
  - `~/Engineering/llm-call-test/` — experiment 4: minimax cn LLM call (Anthropic compatible)
  - `~/Engineering/wenshu-arch-experiments/Exp5-CoreData/` — experiment 5: CoreData single file
  - `~/Engineering/wenshu-arch-experiments/Exp6-Concurrency/` — experiment 6: Swift Concurrency + CoreData
- Legacy monorepo fork (read-only): `/Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/v0.x-monorepo-fork-2026-08-06/`
- minimax cn API: `https://api.minimaxi.com/anthropic/v1/messages`
- minimax cn docs: `https://platform.minimaxi.com/docs/llms.txt`
- minimax cn model whitelist: see §9
- Apple Developer Program: paid individual $99/year on release
- iOS 27 simulator: not yet public, iPad / iPhone real machine test pending iOS 27 sim public release

---

*CLAUDE.md v0.07.1 · 2026-08-22 pocock single agent · English-only cleanup · project root = `/Volumes/ANAN/Engineering/wenshu/`*

---

## Agent skills

### Issue tracker

Local markdown: `.scratch/<feature>/issues/<NNN>-<slug>.md`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default 5 roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Stored as `state:` field at the top of each issue file. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` (root) + `docs/adr/NNNN-<slug>.md`. Update `CONTEXT.md` when a new domain word enters the codebase. Write an ADR for every hard-to-reverse decision. See `docs/agents/domain.md`.

### Full workflow

35 po skills active on this repo. Mandatory flow when taking on new work:

1. **`/ask-matt`** — pick the right flow (router, every task starts here).
2. **`/grill-with-docs`** — sharpen the idea by interview, leave a paper trail in `CONTEXT.md` and ADRs.
3. **`/wayfinder`** — only when the fog is too thick to hold in one session; chart a map of decision tickets.
4. **`/to-spec`** — collapse the conversation into a buildable spec.
5. **`/to-tickets`** — split the spec into one issue per file under `.scratch/<feature>/issues/`.
6. **`/triage`** — only for incoming issues not created by `to-tickets`.
7. **`/implement`** per ticket — drives `/tdd` internally, then `/code-review` (two axes, Standards + Spec) before commit.
8. **`/code-review`** — review the diff between a fixed point and HEAD on both axes. Run on every change before committing.
9. **`/domain-modeling`** — keep `CONTEXT.md` glossary clean.
10. **`/improve-codebase-architecture`** — periodic deepening opportunities scan.

Vocabulary underneath (auto-loaded via `CONTEXT.md` + ADR reads):

- **`/codebase-design`** — deep-module vocabulary for module shape design.
- **`/diagnosing-bugs`** — 4-phase root cause debugging; refuses to theorise without a tight feedback loop.
- **`/resolving-merge-conflicts`** — work a conflict by intent, never by line-picking.

Standalone (off the main flow):

- **`/grill-me`** / **`/grilling`** — interview primitive, no repo state.
- **`/prototype`** — throwaway code to answer a design question, kept as a primary source.
- **`/research`** — delegated background reading; primary sources only.
- **`/wizard`** — human-only steps (provisioning, credentials, migrations).
- **`/wait-what`** — corrective for a message that didn't land.
- **`/teach`** — multi-session learning workspace.
- **`/writing-for-agents`** — skill / AGENTS.md / spec writing.
- **`/to-questionnaire`** — when a decision needs someone else's input.
- **`/handoff`** — compact a conversation for another agent.

Boundary tools (when crossing phases):

- **`/clear`** — empty the window at a phase boundary.
- **`/compact`** — compress + seed a fresh session.
- **`/subagent`** — short reasoning subtask, returns a report.