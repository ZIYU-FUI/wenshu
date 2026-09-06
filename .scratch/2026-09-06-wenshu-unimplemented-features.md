# Wenshu Unimplemented Features Audit

**Date**: 2026-09-06
**Scope**: Count and classify all features marked as deferred / not yet implemented / full-impl requires boss拍 in the wenshu source tree.
**Method**: 4-scan grep + manual reading of doc comments.

## Categories of Unimplemented Work

### Category A — Boss-Decision Deferred (= 4 features, full-impl requires boss拍)

These are EXPLICIT scaffold files with "Behavior: TODO. Full impl requires boss拍" markers in the file header.

| # | File | Feature | Status |
| --- | --- | --- | --- |
| A1 | Editor/DragDropImageInsertion.swift | drag-drop image insertion into editor | scaffold only (= no drop target registration, no payload parse, no insert logic) |
| A2 | Editor/EditorOutlineBacklinksTabs.swift | editor outline + backlinks tabs (= 大纲 tree view + 反链 cross-reference) | scaffold only |
| A3 | Editor/LaTeXOptIn.swift | LaTeX formula toggle + MarkdownEngineLatex bridge | scaffold only |
| A4 | Editor/WikiLinkCreation.swift | ⌘K palette + reference-library autocomplete + insert | scaffold only |

### Category B — MVP-Not-Implemented (= 3 features, MVP scope deferred)

These are explicit MVP-scope stubs in the LayoutEditMode (layout-edit mode for the workspace pane tree).

| # | File | Feature | Status |
| --- | --- | --- | --- |
| B1 | Workspace/LayoutPicker/GridModel.swift:64 | LayoutEditMode 跨区 move-zone (= moves every zone on either side) | MVP not implemented |
| B2 | Workspace/LayoutPicker/ZoneEditor.swift:6-7 | rubber-band drag select across zones | MVP not implemented |

### Category C — Hermes 1:1 Port with Future-Implementation Dependency (= 3 features)

These are Hermes Desktop verbatim ports (= §11.3 wenshu-side wins pattern) where the function exists but the consumer (= caller) lands with future drag-drop / tab-strip UI tickets.

| # | File | Feature | Status |
| --- | --- | --- | --- |
| C1 | UI/Drag/NativeControlsInspector.swift:86 | windowDragStripWidth (= Hermes titlebarControlsPosition) | function exists, no caller (= drag-strip UI ticket) |
| C2 | State/LayoutTreeState.swift:635 | reorderPanesInGroup (= browser-tab drag semantics) | function exists, no caller (= drag-drop reorder UI ticket) |
| C3 | State/LayoutTreeState.swift:665 | setGroupTabStrip (= standing strip choice) | function exists + tabStrip field exists, no consumer (= tab-strip UI toggle ticket) |

### Category D — Hermes Stub Implementations (= 3 stubs)

These return placeholder strings marked "stub: ..." in the body. Some are explicitly deferred; some are behavioral stubs.

| # | File | Feature | Status |
| --- | --- | --- | --- |
| D1 | Core/Memory/MemoryProvider.swift:286 | GRDB-backed SQLite memory provider (= current SQLite impl is stub over in-memory backing) | stub returns placeholder string; full GRDB impl lands with v0.29+ migration ticket |
| D2 | Core/Agent/Skill/SkillAdapter.swift:172,174 | Skill invocation (= currently returns "stub: skill X is disabled" / "stub: invoked X") | stub; lands when SETTINGS-PERSISTENCE-002 gate enables skills |
| D3 | Core/Agent/Tool/ParagraphAITool.swift:158 | ParagraphAI stub (= returns "[ParagraphAI stub — action=expand] (no input) [expanded]") | stub for parity guard |

### Category E — Pending Implementation (= 2 specific TODOs in code comments)

| # | File | Feature | Status |
| --- | --- | --- | --- |
| E1 | Core/Memory/MemoryProvider.swift:286 | SQLiteMemoryProvider.getSystemPrompt() returns placeholder string | TODO comment: "replace with the GRDB-backed full implementation" |
| E2 | Core/Agent/Conversation/ContextEngine.swift:133 | per-book Character/World retrieval | "still pending per the original TODO scope" |
| E3 | Core/Agent/Conversation/ContextEngine.swift:182 | "callers that own a persisted MemoryStore can inject it here so per-book Character/World retrieval can land in a followup ticket without changing this entry point" | forward-looking wiring |

### Category F — Workspace Stub Views (= 1 placeholder)

| # | File | Feature | Status |
| --- | --- | --- | --- |
| F1 | Views/Chat/ChatZoneStubView.swift | stub view for chat-zone 2nd/3rd tab (= .search / .settings) | "开发中" placeholder; = display label only, no real chat |

### Category G — Provider Connector Stubs (= 1 explicit failure)

| # | File | Feature | Status |
| --- | --- | --- | --- |
| G1 | UI/LLMConnector/ConnectorTestButton.swift:85 | Gemini native connector (= test button returns .failure "Gemini native connector lands in ticket 007") | explicit failure message; = connector not implemented |

### Category H — Workspace Sample Placeholder (= 1 file)

| # | File | Feature | Status |
| --- | --- | --- | --- |
| H1 | Workspace/WorkspaceView.swift:1299 | sample preview body (= Markdown lorem ipsum for preview) | "placeholder until ticket 027-35 wires [real data]" |

### Category I — Component-Level Stubs (= 2 small files from earlier extraction)

These were extracted from WorkspaceView in apple-001 Q2 slice 9 (= atomic moves, not implementations).

| # | File | Feature | Status |
| --- | --- | --- | --- |
| I1 | Views/Workspace/EditorContentPlaceholder.swift | Color.clear placeholder for editor pane | empty placeholder (= background uniformity via ZonePerRegionChrome) |
| I2 | Views/Workspace/PreviewTabBackground.swift | Color.clear placeholder for preview pane tab background | empty placeholder |

## Summary

**Total unimplemented features identified: 21**

| Category | Count | Description |
| --- | --- | --- |
| A — Boss-decision deferred (full impl) | 4 | editor 4 features (drag-drop image / outline+backlinks / LaTeX / wikilink) |
| B — MVP-not-implemented (LayoutEditMode) | 2 | layout-edit cross-zone move + rubber-band select |
| C — Hermes 1:1 port (future consumer) | 3 | drag-strip width / pane reorder / tab-strip set |
| D — Hermes stubs (returns placeholder) | 3 | GRDB SQLite memory / Skill adapter / ParagraphAI |
| E — Pending TODO in code | 3 | GRDB SQLite + Character/World retrieval (×2) |
| F — Workspace stub view | 1 | chat-zone 2nd/3rd tab |
| G — Provider connector stub | 1 | Gemini native connector |
| H — Workspace placeholder | 1 | sample preview body |
| I — Component-level stubs (extraction) | 2 | Editor/Preview placeholders |
| **Total** | **21** | |

## By Domain (= where the unimplemented work lives)

| Domain | Count | Items |
| --- | --- | --- |
| Editor (= in-editor features) | 4 | A1 (drag-drop image), A2 (outline+backlinks tabs), A3 (LaTeX), A4 (WikiLink creation) |
| Workspace layout edit mode | 2 | B1, B2 |
| Hermes-port public API (= no caller yet) | 3 | C1, C2, C3 |
| Hermes stub implementations | 3 | D1, D2, D3 |
| Memory + Context engine | 3 | E1, E2, E3 |
| Workspace placeholders | 4 | F1, H1, I1, I2 |
| LLM connectors | 1 | G1 |

## Boss拍 Status (= which features need a boss decision to unblock)

| Feature | Why boss-decision needed | Effort estimate |
| --- | --- | --- |
| A1 (drag-drop image) | architectural: drop target + payload parse + insert | medium |
| A2 (outline+backlinks tabs) | architectural: tree view design + cross-reference schema | large |
| A3 (LaTeX) | architectural: MarkdownEngineLatex product adoption + toggle UX | large |
| A4 (WikiLink) | architectural: ⌘K palette + autocomplete | medium |
| B1 (cross-zone move) | architectural: drag semantics in LayoutEditMode | medium |
| B2 (rubber-band select) | architectural: drag UX across zones | medium |
| C1 (drag-strip width) | product: when drag-strip UI ticket lands | small |
| C2 (pane reorder) | product: when drag-drop reorder UI ticket lands | small |
| C3 (tab-strip) | product: when tab-strip UI toggle ticket lands | small |

**9 features are unblocked ONLY by boss architectural decision (= boss拍 A vs B vs C for each).** The remaining 12 are pending implementation tickets (= boss decided the scope, just need scheduling).

## Closed / Implemented-Recently (for context)

- SMC ticket 003 — WikiLink navigation (= closes the `// TODO: ticket 027-35 navigation` placeholder closure in `EditorActions.swift:44-45`).
- v0.40 apple-001 phase 3 ticket 4a — ChatZoneTab rawValue ASCII + displayLabel mapping (= replaces legacy CJK enum rawValues).
- v0.40 apple-001 phase 3 ticket 6 — SettingView i18n sweep (= closes all CJK violations in SettingView).

## Cross-References

- `.scratch/2026-09-04-apple-methodology/apple-self-check.md` §2 (= Tier-2/Tier-3 candidates deferred).
- `.scratch/2026-09-04-hermes-port-gap-audit.md` (= §11.3 Hermes-port gap = 18 partial + 8 missing modules).
- `.scratch/backlog-split-files-refactor.md` (= scope item 8 = "Tier-2/Tier-3 Apple-API-first candidates that remain after the readiness work").
- `.scratch/2026-09-06-wenshu-code-audit.md` (= 7 orphan functions = forward-looking public API = matches category C here).
- `.scratch/2026-09-06-wenshu-code-audit-verification.md` (= detailed verification of category C).

---

*Generated 2026-09-06 via 4-scan grep + manual verification.*
*21 unimplemented features identified. 9 require boss architectural decision. 12 are pending implementation tickets.*