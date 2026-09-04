# Spec — Wenshu editor migration: adopt swift-markdown-engine (boss 2026-09-04 拍 '尝试接入')

- Date: 2026-09-04
- Boss OOB 2026-09-04 verbatim: '听起来是可以的, hermes swift 化的工作在同步进行中, 和你现在接入这个库, 有没有影响? 如果没有, 可以尝试接入。如果我未来需要做 IOS PAD 端, 但我不会走代码复用的逻辑, 会完整再开发一次。有没有影响'
- Boss follow-up OOB: '好, 加 PO 全链路方法论, 跑接入'
- Boss verdict on option choice: A = adopt nodes-app/swift-markdown-engine as the wenshu chapter editor (boss accepted A over B/C in 2026-09-04 round 1)
- Methodology source: wenshu `.scratch/2026-08-19-frontend-integration/35-skills-methodology.md` (po main flow 6 steps, boss 8/19 拍 must keep verbatim). Current spec is the output of step 2 (to-spec) after step 1 (grill-with-docs) completed in 2026-09-04 round 1.
- Spec status: spec written by agent 2026-09-04, ready for step 3 (to-tickets).
- Implementation status: not started. Tracer-bullet ticket = issue 001 of this spec.
- Source repo: `https://github.com/nodes-app/swift-markdown-engine` (verified 971★ / Apache-2.0 / 3 contributors / macOS-only / TextKit 2 / 0.12.0 latest 2026-08-10).
- Wenshu repo: `/Volumes/ANAN/Engineering/wenshu/`
- Worktree: `.worktrees/editor-001-adopt-engine` (branch `wt/editor-001`).
- Apple HIG hard constraint (preserved from §11): no custom token values, parent chrome owns shape/spacing/bg, child only tap/display.

## 0. Boss decisions, verbatim from 2026-09-04 grill round 1

| # | Question | Boss verdict | Rationale |
|---|---|---|---|
| Q1 | Migration approach | A = swift-markdown-engine (end-to-end TextKit 2 editor) | Boss accepted after seeing 5 JS editor options all archived/JS-only/zero Swift, swift-markdown-engine = only macOS-native TextKit 2 Markdown editor with active maintenance |
| Q2 | Apache-2.0 patent terms | No impact on wenshu (wenshu is closed-source personal writing tool, no patent litigation intent) | Boss accepted explanation of MIT vs Apache-2.0 = copyright identical, only difference is patent grant + patent retaliation clause |
| Q3 | Concurrent with hermes-core-translation | No conflict (zero file overlap; Package.swift additive only) | Boss accepted, sequenced per PO cadence = spec first, implement after approval |
| Q4 | Future iOS/iPad port impact | Zero impact (swift-markdown-engine = macOS-only; iOS will be independently built per boss's stated approach) | Boss accepted, wenshu-side protocol design (WikiLinkResolver / EmbeddedImageProvider) becomes design reference for iOS port |

### 0.1 Truth-survey findings (boss Q4 = truth-survey mode 2026-09-04)

| Source | Finding | Spec impact |
|---|---|---|
| **A** swift-markdown-engine README | 3 SPM products: `MarkdownEngine` (zero deps), `MarkdownEngineCodeBlocks` (pulls HighlighterSwift), `MarkdownEngineLatex` (pulls SwiftMath) | §3.5 specifies `MarkdownEngineCodeBlocks` as wenshu pin (= already has HighlighterSwift) |
| **A** swift-markdown-engine ARCHITECTURE.md | `NativeTextViewWrapper` is `NSViewRepresentable` (SwiftUI entry); 4 service protocols with no-op defaults | §3.5 specifies 4 protocols to implement |
| **A** swift-markdown-engine GitHub | 971★, Apache-2.0, 3 contributors (luca-chen198 / Nicolas-Py / xandaaaa), Munich+Zurich team, 0.12.0 latest 2026-08-10, half-year 5 minor releases | §3.5 acceptance: 100★ + 12-month + macOS-first all met (AGENTS.md §11.1) |
| **B** wenshu Package.swift | `swiftlang/swift-markdown` + `smittytone/HighlighterSwift` + `gonzalezreal/textual` already pinned; zero NSTextView, zero NSViewRepresentable, zero TextEditor | §3.5 pin compatible; existing HighlighterSwiftBridge integrates via `MarkdownEditorServices.syntaxHighlighter` |
| **B** wenshu `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` L1539-1573 | `EditorEditContent` currently uses Apple SwiftUI `TextEditor` (= HIG multi-line text input; US-13 = no custom NSTextView wrapper) | §3.6 swap point: `EditorEditContent.body` `TextEditor(...)` → `WenshuMarkdownEditor(text:draftId:services:)` |
| **B** wenshu `.scratch/2026-09-03-hermes-core-translation/` | 11 ticket structure (10 code + 1 docs) is the in-flight pattern; current `wt/editor-001` worktree is parallel branch | §4 ticket decomposition mirrors that pattern; branch strategy = same single worktree model |
| **C** AGENTS.md §11.1 | Third-party lib 4-criteria gate: 100★ + 12mo active + MIT/Apache/BSD + macOS-first | swift-markdown-engine passes all 4 (971★, 24-day-old latest release, Apache-2.0, macOS 14+ only) |

## 1. Problem statement

Wenshu chapter editing currently runs on Apple SwiftUI `TextEditor` (per `WorkspaceView.swift` L1539-1573, `EditorEditContent`). This gives users HIG-standard multi-line text input with system undo/redo/find/spelling, but zero Markdown awareness: `# ` stays as raw `# `, `**bold**` stays as `**bold**`, code fences are plain text, wiki-links are unlinked, images are raw paths.

Wenshu's product positioning (§11) is "writing tool, not LLM platform" — the editor IS the surface where the writing happens. A raw text widget forfeits the live styling, word counters on heading lines, code-fence rendering, and cross-reference linking that the rest of wenshu (reference-library 4-layer structure, BacklinksPanel, character cards) is built around.

Adopt `nodes-app/swift-markdown-engine` (verified macOS-only TextKit 2 Markdown editor, 971★, Apache-2.0, 3 maintainers, 0.12.0 = current stable). The engine ships a SwiftUI bridge (`NativeTextViewWrapper` = `NSViewRepresentable`), 4 service protocols with no-op defaults, and pre-built bridges for `HighlighterSwift` (= already in wenshu Package.swift) and `SwiftMath`. Wenshu implements only the 2 protocols with wenshu-specific data sources (wiki-link resolver, image embed provider).

## 2. Scope (Scope A = end-to-end adopt swift-markdown-engine)

### 2.1 In-scope (single ticket = 001)

| Layer | Change |
|---|---|
| Package.swift | +1 dependency: `swift-markdown-engine` from 0.12.0, product = `MarkdownEngineCodeBlocks` |
| Editor/ | New `Sources/WenshuApp/Editor/` directory = WenshuMarkdownEditor wrapper + 2 service adapters |
| Views/Workspace/ | `EditorEditContent.body` swap: `TextEditor(text:)` → `WenshuMarkdownEditor(text:draftId:services:)` |
| Tests/ | New `Tests/WenshuAppTests/Editor/` directory with 5 tests covering protocol implementations + editor mount |

### 2.2 Out-of-scope (deferred to future tickets if boss拍)

- **iOS / iPad port** — swift-markdown-engine is macOS-only; iOS gets independent editor (boss confirmed 2026-09-04).
- **Live split preview** — v0.34 B-25 already does preview = `swift-markdown` rendered side-by-side; not changed by this ticket.
- **Drag-drop image insertion** — `EmbeddedImageProvider` accepts embed-by-id; drag-drop UI is a future ticket.
- **Wiki-link creation UI** — `WikiLinkResolver` resolves existing links; creation UX is future.
- **LaTeX rendering** — `SwiftMath` is a transitive dep of `MarkdownEngineLatex` (which we do NOT adopt in 001); boss opt-in via future ticket if needed.
- **Editor placeholder (大纲 / 反链 tabs)** — `WorkspaceView.swift` L391-392 currently shows `EditorPlaceholder()` for non-edit tabs; not changed by 001.

## 3. Design

### 3.1 Architecture (wenshu-side wins principle)

Per AGENTS.md §11.3 (= boss 2026-09-03 ratification): when an external library provides infrastructure that wenshu has data for, **wenshu-side wins**. Library provides the protocol shape + default behavior; wenshu provides the data layer.

```
┌─────────────────────────────────────────────────────────────────┐
│  WorkspaceView.EditorEditContent (v0.34 B-25 layout, unchanged) │
└──────────────────────────┬──────────────────────────────────────┘
                           │ body: text Binding<String>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  WenshuMarkdownEditor  (NSViewRepresentable)                    │
│  - id: UUID  (= stable per tab, required by engine)             │
│  - text: Binding<String>                                        │
│  - services: MarkdownEditorServices                             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  nodes-app/swift-markdown-engine (v0.12.0)                      │
│  - NativeTextViewWrapper  (SwiftUI bridge)                      │
│  - 4 service protocols + no-op defaults                         │
│  - TextKit 2 layout + AST parser + incremental restyle          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌──────────────┐  ┌────────────────┐  ┌──────────────────────┐
│ Reference    │  │ Reference      │  │ HighlighterSwift     │
│ Library      │  │ Library        │  │ Bridge               │
│ WikiLink     │  │ Image          │  │ (= transitive via    │
│ Resolver     │  │ Provider       │  │  MarkdownEngineCode- │
│ (wenshu)     │  │ (wenshu)       │  │  Blocks product)     │
└──────────────┘  └────────────────┘  └──────────────────────┘
```

### 3.2 Wiki-link resolution semantics

Wenshu reference-library holds cross-book entities (`raw/`, `entities/`, `abstracts/`, `indexes/` per AGENTS.md §11). Chapter text uses Obsidian-style `[[Name]]` and `[[Name|alias]]` to reference entities.

Resolution algorithm:

1. Receive `displayName: String, range: NSRange` from engine.
2. Search `reference-library/entities/` for entity file with matching `name` field (= case-insensitive, trim whitespace).
3. If hit: return `WikiLinkResolution(id: entityUUID, exists: true)`. Engine renders link in `systemBlue` + underline.
4. If miss: return `WikiLinkResolution(id: nil, exists: false)`. Engine renders link in `secondaryLabelColor` + dashed underline.

Engine guarantees synchronous call (per `MarkdownEditorServices` doc comment); wenshu resolution is filesystem read = ~1ms, no async needed.

### 3.3 Image embed semantics

Wenshu image embedding uses Obsidian-style `![[name]]` (= engine writes the raw `![[name]]` to text storage; on render, engine asks provider for NSImage).

Provider algorithm:

1. Receive `embedName: String` from engine.
2. Search order:
   - Active book's `shelves/<shelf-uuid>/books/<book-uuid>/characters/` (= chapter-local character portraits)
   - Active book's `shelves/<shelf-uuid>/books/<book-uuid>/worlds/` (= chapter-local world map images)
   - Library's `reference-library/raw/` (= cross-book raw materials)
3. Match by file basename (without extension, case-insensitive).
4. If hit: return `NSImage(contentsOfFile:)`. Engine renders inline at the embed site.
5. If miss: return nil. Engine renders a broken-embed placeholder.

### 3.4 Syntax highlighter = HighlighterSwiftBridge

Transitive via `MarkdownEngineCodeBlocks` product. Engine ships the bridge; wenshu wires it:

```swift
configuration.services = MarkdownEditorServices(
    syntaxHighlighter: HighlighterSwiftBridge()
)
```

No wenshu code needed; HighlighterSwift already pinned in Package.swift.

### 3.5 Package.swift delta

```swift
// in dependencies array, alphabetized per existing pattern
.package(url: "https://github.com/nodes-app/swift-markdown-engine", from: "0.12.0"),

// in target dependencies, alphabetized
.product(name: "MarkdownEngineCodeBlocks", package: "swift-markdown-engine"),
```

Pin rationale: `from: "0.12.0"` = latest stable per `git ls-remote --tags` 2026-09-04. Per swift-markdown-engine README "Production use is fine — pin a specific version (0.x.y) in your Package.swift", pre-1.0 = minor-version pin (matches wenshu existing pattern with `EPUBKit 0.5.0`, `Textual 0.5.0`).

### 3.6 WorkspaceView.swift delta

`EditorEditContent.body` (WorkspaceView.swift L1539-1573 currently):

```swift
// before (v0.34 B-25):
TextEditor(text: $draft)
    .font(.body)

// after (v0.39 ticket 001):
WenshuMarkdownEditor(text: $draft, draftId: tab.id.uuidString, services: services)
    .frame(minHeight: 200)
```

The `services: MarkdownEditorServices` instance is constructed by the caller (`EditorEditContent`) from the current `BookStore` + `WenshuLibrary` (= provides reference-library root path + active book uuid). One `services` instance per edit session (= bound to the active tab's chapter).

### 3.7 New files (5 files, ~460 LOC total)

| File | LOC | Role |
|---|---|---|
| `Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift` | ~80 | `NSViewRepresentable` wrapping `NativeTextViewWrapper`; stabilizes `text` binding lifecycle |
| `Sources/WenshuApp/Editor/ReferenceLibraryWikiLinkResolver.swift` | ~120 | `WikiLinkResolver` conformance; reads reference-library entities |
| `Sources/WenshuApp/Editor/ReferenceLibraryImageProvider.swift` | ~80 | `EmbeddedImageProvider` conformance; resolves `![[name]]` to NSImage |
| `Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift` | ~30 | Builds `MarkdownEditorServices` from current AppState (1 per edit session) |
| `Tests/WenshuAppTests/Editor/WenshuMarkdownEditorAdapterTests.swift` | ~150 | 5 tests: wiki-link hit, wiki-link miss, image hit, image miss, editor mount |

### 3.8 Tests

Per wenshu test pattern (AGENTS.md §11.1, Q182.4 reusable patterns):

| Test | Verifies |
|---|---|
| `testWikiLinkResolver_hit` | Given entity `Anna` exists in reference-library, resolver returns `exists: true` with non-nil id |
| `testWikiLinkResolver_miss` | Given `Unknown` does not exist, resolver returns `exists: false`, id = nil |
| `testImageProvider_hit_characterPortrait` | Given `Anna.png` exists in book's `characters/`, provider returns non-nil NSImage |
| `testImageProvider_miss` | Given `ghost.png` does not exist, provider returns nil |
| `testWenshuMarkdownEditor_mounts` | ViewInspector: mount `WenshuMarkdownEditor(text: .constant(""), draftId: UUID().uuidString, services: factory)` produces a view (no crash) |

All tests use `@MainActor` (per Q182.4: any test func touching DesignTokens = @MainActor; here, `AppState` is `@MainActor`-isolated).

### 3.9 Verification (Z + X dual-track per AGENTS.md skill recipe)

- **Z (golden-file contract)**: Not applicable for 001 (no algorithm to golden-test; no chat-format preservation like hermes translation).
- **X (e2e dual-track)**: Single X-test = launch wenshu app, open chapter, type `# Hello`, verify heading style applied within 100ms. Documented in issue 001 acceptance criteria §5.3.

## 4. Ticket decomposition

Per PO Step 3 (to-tickets): 1 ticket for 001 (tracer-bullet). Future tickets = owner-driven.

### 4.1 Tracer-bullet ticket = 001

`001-adopt-swift-markdown-engine.md` — full spec in `.scratch/2026-09-04-editor-migration/issues/001-*.md`. Acceptance = §5 of that issue.

### 4.2 Future tickets (not in 001, optional follow-ups if boss拍)

- **002 (opt-in)**: Adopt `MarkdownEngineLatex` product for math writing use cases
- **003 (opt-in)**: Wiki-link creation UX (e.g. ⌘K palette)
- **004 (opt-in)**: Drag-drop image insertion UX
- **005 (defer)**: iOS port = separate project

## 5. Acceptance criteria (ticket 001)

Per Q146/Q175 boss cadence: each ticket = 1 RULE 1 commit.

- [ ] Package.swift: `.package(url: "...swift-markdown-engine", from: "0.12.0")` + `.product(name: "MarkdownEngineCodeBlocks", package: "swift-markdown-engine")` added; `swift build` succeeds with zero warning.
- [ ] `Sources/WenshuApp/Editor/` = 4 new files (WenshuMarkdownEditor + 2 service adapters + factory).
- [ ] `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` `EditorEditContent.body` swapped from `TextEditor` to `WenshuMarkdownEditor` (single-commit delta, no other changes).
- [ ] `Tests/WenshuAppTests/Editor/WenshuMarkdownEditorAdapterTests.swift` = 5 tests, all pass.
- [ ] End-to-end X-test (manual, documented in issue §5.3): launch wenshu app, open any chapter, type `# Hello` → heading style applied within 100ms; type `**bold**` → bold style; type `[[Anna]]` (with Anna in reference-library) → blue underlined link; type `[[Ghost]]` (no entity) → gray dashed link.
- [ ] Liquid Glass chrome preserved: AppTitlebar / AppStatusbar height unchanged; chapter zone padding unchanged.
- [ ] No new dependency conflicts (hermes-core-translation work in `wt/multi-agent-dispatch` branch is untouched; Package.swift additive).
- [ ] Commit message follows wenshu convention: `feat(wenshu): v0.39 ticket 001 -- adopt swift-markdown-engine as chapter editor (= Apache-2.0, macOS-only TextKit 2 markdown engine)`

## 6. Risks + mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| swift-markdown-engine API drift (pre-1.0) | Low | Pin `from: "0.12.0"`; per wenshu existing pattern with `EPUBKit 0.5.0` / `Textual 0.5.0`; WenshuEditorServicesFactory isolates protocol construction so future API change = 1 file diff |
| Apache-2.0 attribution obligation | None | wenshu About page already shows third-party licenses; add swift-markdown-engine entry |
| Liquid Glass chrome break | Low | Editor view is wrapped in `EditorEditContent` chrome wrapper (= v0.34 B-25 established); no chrome touched |
| Tab identity for undo | Mitigated | Engine requires stable `documentId: UUID` per spec; we pass `tab.id.uuidString` |
| hermes-core-translation merge conflict | None | Different file scope (Core/Agent/ vs Editor/ + 1 line in WorkspaceView); Package.swift additive |

## 7. Auto-pilot status

Per Q182 (boss 2026-09-03 OOB "push 不归 ANAN 管, 之前 push 就是你的活" + "采纳你的推荐" stance):

- Boss拍 2026-09-04 "好, 加 PO 全链路方法论, 跑接入" = full plan approval.
- Agent proceeds without per-commit approval.
- Progress reports every ~5 commits (= 001 is single commit + tests, so report at end of 001).
- After 001 ships (= merge to main), agent reports and awaits boss verification before 002 (if any).

## 8. Cross-references

- AGENTS.md §11 baseline = wenshu stack rules (preserved; no changes)
- AGENTS.md §11.1 third-party lib policy = swift-markdown-engine passes 4-criteria gate
- AGENTS.md §11.3 wenshu-side wins = library provides protocols, wenshu provides data
- `.scratch/2026-08-19-frontend-integration/35-skills-methodology.md` = PO 6-step methodology
- `.scratch/2026-09-03-hermes-core-translation/spec.md` = parallel spec (different file scope; precedent for spec structure)
- `.scratch/2026-09-04-editor-migration/issues/001-adopt-swift-markdown-engine.md` = issue 001 (next file)

*Spec written 2026-09-04 by wenshu auto-pilot (= pocock single-agent) per boss OOB "好, 加 PO 全链路方法论, 跑接入".*
