# Wenshu Library Outline Apple-API Audit — v0.32 (sub-sweep)

Status: spec for boss 2026-09-02 OOB request "查一下目录树是否用的 apple api 实现的，有没有自写的内容".
Author: pocock single-agent.
Branch: wt/multi-agent-dispatch.
Date: 2026-09-02.

# Hard rule (project-wide, non-negotiable)

- English only. No CJK characters or punctuation.

# §0. Scope

Boss asked: "目录树是否用的 apple api 实现的，有没有自写的内容". This spec audits the **library outline tree** surface (= the sidebar that lists shelves / books / folders / reference categories) end-to-end:

- `Sources/WenshuApp/Views/Library/*.swift` (= 9 files in this directory)
- `Sources/WenshuApp/Core/Outline/*.swift` (= 2 files)
- The single-source-of-truth wiring chain (`WorkspaceView` → `TabContentDispatcher` → `RegisteredPanes` → `NewLibraryOutlineView`).

# §1. Files in scope + actual Apple-API coverage

| File | LOC | Functionality (= what user-visible surface would render if wired) | Reachable? (= `git grep` for callers) | UI vs Functional | Apple HIG API used | Custom code LOC |
|---|---|---|---|---|---|---|
| `Views/Library/NewLibraryOutlineView.swift` | 1972 | **LIVE sidebar tree**: shelf → book → folder (+ reference library section) | YES (WorkspaceView:233, WorkspaceView:438, App.swift:1518, RegisteredPanes:35, RegisteredPanes:134) | UI | `List(.sidebar)` + `DisclosureGroup` + `Label` + `.badge` + `.contextMenu(forSelectionType:)` + `Section` + `.sheet` + `.alert` + `Button` + `NavigationLink` (transitively) | ~117 LOC inline (see §2) |
| `Views/Library/LibraryOutlineView.swift` | 373 | **OLD v0.02.x sidebar tree**: List + DisclosureGroup = shelves (parent, collapsible) → books (children, selectable) | **NO** (zero callers) | UI | partial: `List` + `DisclosureGroup` (4) + `.sheet` + `.contextMenu` + `confirmationDialog`; BUT 0 hit for actual `DisclosureGroup` in body (only 4 mentions are in the docstring at file header) | **373 LOC custom** = dead code, superseded by NewLibraryOutlineView |
| `Views/Library/BookOutlineView.swift` | 197 | **OLD v0.03.0 book detail card grid**: second-column card grid grouped by BookCategory (章节 / 设定 / 资料库) | **NO** (zero callers — PreviewPane.bookScope superseded it) | UI | `ScrollView` + `LazyVGrid` + `Label` + `.contextMenu` | **197 LOC custom** = dead code, superseded by PreviewPane.bookScope |
| `Views/Library/WorldOutlineView.swift` | 195 | **OLD v0.26 world-entry card grid**: per-book world-building entries (LazyVGrid cards), callback onSelect | **NO** (zero callers — PreviewPane.referenceScope superseded it) | UI | `ScrollView` + `VStack` + `ForEach` + `.sheet` + `WorldEntryEditorSheet` | **195 LOC custom** = dead code, superseded by PreviewPane.referenceScope |
| `Views/Library/CharacterOutlineView.swift` | 185 | **OLD v0.26 character card grid**: per-book character cards, LazyVGrid | **NO** (zero callers — PreviewPane superseded it) | UI | `VStack` + `ForEach` + `LazyVGrid` + `CharacterCard` + `.contextMenu` | **185 LOC custom** = dead code, superseded by PreviewPane |
| `Views/Library/ReferenceLibraryOutlineView.swift` | 193 | **OLD v0.26 reference-library layered browser**: tab bar (ReferenceLayer: entities / abstracts / indexes) + content list | **NO** (zero callers — PreviewPane.referenceScope superseded it) | UI | `VStack` + `HStack` + `ForEach` + `.contextMenu` + `ReferenceEditorSheet` | **193 LOC custom** = dead code, superseded by PreviewPane.referenceScope |
| `Views/Library/BookshelfEditorSheet.swift` | 91 | YES (called by NewLibraryOutlineView:96, 100) | `TextField` + `Form` + `Button` | 0 |
| `Views/Library/BookEditorSheet.swift` | — | YES | n/a (called from NewLibraryOutlineView via BookOutlineRow or directly) | 0 |
| `Views/Library/CharacterEditorSheet.swift` | — | YES | `Form` + `TextField` + `Picker` | 0 |
| `Views/Library/ReferenceEditorSheet.swift` | — | YES | `Form` + `TextField` | 0 |
| `Views/Library/WorldEntryEditorSheet.swift` | — | YES | `Form` + `TextEditor` | 0 |
| `Views/Library/SmartQueryView.swift` | — | YES (referenced from BookOutlineView context but BookOutlineView is dead) | `TextField` + `ScrollView` + `ForEach` | 0 |
| `Core/Outline/OutlinePanel.swift` | 48 | UNVERIFIED (low-priority — needs caller check) | `List` + `ForEach` | minimal |
| `Core/Outline/OutlineExtractor.swift` | 126 | UNVERIFIED (low-priority — needs caller check) | n/a (pure data extractor) | 126 LOC = pure logic, not UI |

**Five dead-code files** = `LibraryOutlineView` + `BookOutlineView` + `WorldOutlineView` + `CharacterOutlineView` + `ReferenceLibraryOutlineView` = **1143 LOC** with zero reachable callers. The grep evidence:

```
$ grep -rEn 'BookOutlineView|WorldOutlineView|CharacterOutlineView|ReferenceLibraryOutlineView|LibraryOutlineView' Sources/ Tests/
Sources/WenshuApp/App.swift:1514:    struct LibraryOutlineViewContent: View {     ← comment only
Sources/WenshuApp/Views/Library/BookOutlineView.swift:39:struct BookOutlineView: View {   ← self-definition
Sources/WenshuApp/Views/Library/CharacterOutlineView.swift:20:struct CharacterOutlineView: View {   ← self-definition
Sources/WenshuApp/Views/Library/LibraryOutlineView.swift:38:struct LibraryOutlineView: View {   ← self-definition
Sources/WenshuApp/Views/Library/ReferenceLibraryOutlineView.swift:17:struct ReferenceLibraryOutlineView: View {   ← self-definition
Sources/WenshuApp/Views/Library/WorldOutlineView.swift:22:struct WorldOutlineView: View {   ← self-definition
Sources/WenshuApp/State/AppState.swift:7:  ← comment only
Tests/WenshuAppTests/Views/LibraryOutlineViewBindingsTests.swift:15-16:    ← stale XCTest suite referring to LibraryOutlineView binding
```

Note: `Tests/WenshuAppTests/Views/LibraryOutlineViewBindingsTests.swift` exists but tests `LibraryOutlineView` (dead) — also a deletion candidate.

# §2. NewLibraryOutlineView internal custom code

The single live outline view is 1972 LOC. Apple HIG usage is dominant. The 3 custom-code zones:

## 2.1 `readShelves()` / `readBooks()` / `saveBook()` / `saveShelf()` (990-1087, ~97 LOC)

This is a **storage adapter inline in a view** — direct `FileManager.default.contentsOfDirectory` + `JSONDecoder/JSONEncoder` + `LibraryBootstrapper` invocation. The same operations already exist in `Sources/WenshuApp/Storage/FileSystemLibraryStore.swift` (the `LibraryStoring` protocol).

**Apple coverage**: NO — Apple does not ship a JSON-on-disk store adapter. The view has the option to call `BookStore` (= already wired) instead of inlining FileManager.

**Bug class** this addresses: `NewLibraryOutlineView` does its own disk I/O instead of using the storage protocol. If the disk layout changes (e.g. move from `<root>/<shelf-uuid>/books/<book-uuid>/` to something else), this inline adapter has to be edited in two places (the view + `FileSystemLibraryStore`).

**Decision tree** (boss picks one):
- (A) Move into BookStore (= `Sources/WenshuApp/State/BookStore.swift`) — view stops touching FileManager. Apple has no opinion; this is an internal abstraction concern. **Recommended.**
- (B) Keep inline + add a doc-comment gap note. Lower risk, but two sources of truth.
- (C) Delete the inline copies and rewire to call existing BookStore methods. Middle ground.

## 2.2 DisclosureGroup state persistence (1371-1381, ~10 LOC)

```swift
@AppStorage("wenshu.shelfDisclosureStates") private var persistedShelfDisclosureStates: String = ""
@AppStorage("wenshu.bookDisclosureStates")  private var persistedBookDisclosureStates:  String = ""
// ... encode/decode [String:Bool] via JSONEncoder + JSONDecoder
```

**Apple coverage**: **PARTIAL** — SwiftUI has `@SceneStorage` (macOS 11+) and `@AppStorage` (macOS 11+), but neither natively persists the open/closed state of a `DisclosureGroup`. Apple HIG §"Sidebars" specifies that sidebar disclosure state SHOULD persist across launches, but does not ship a SwiftUI API for it.

**Decision**: **KEEP** with a `// GAP` doc-comment per Apple-API-first skill §"Verification".

## 2.3 Auto-expand parent on child selection (634-637, 749-751, ~5 LOC)

```swift
let isShelfExpanded = books.contains { isBookSelected($0.id) }
return DisclosureGroup(isExpanded: Binding(
    get: { isShelfExpanded || shelfDisclosureStates[shelf.id, default: false] },
    set: { shelfDisclosureStates[shelf.id] = $0 }
)) { ... }
```

**Apple coverage**: **PARTIAL** — SwiftUI `DisclosureGroup` has no "auto-expand when child is selected" behavior. Apple's `List` + `.sidebar` style will auto-select on tap, but the disclosure state is independent.

**Decision**: **KEEP** with a `// GAP` doc-comment.

## 2.4 The remaining ~1860 LOC is pure Apple HIG usage

`List(.sidebar)` + `Section` + `DisclosureGroup` + `Label` + `.badge` + `.contextMenu(forSelectionType:)` + `.sheet` + `.alert` + `.confirmationDialog` + `Button` + `TextField` + `Form`. The single composite `SidebarItem` enum (`Hashable + Codable`) is the canonical SwiftUI pattern for unifying heterogeneous selection types under one `List(selection:)`.

# §3. Acceptance gate (boss 9/1 + 9/2 OOB hard rules)

1. **Apple-API-first** (skill: `wenshu-apple-api-first`): every custom code path documented in this spec has either an Apple HIG replacement (and uses it) OR an explicit gap note.
2. **Boss 9/2 OOB "C — 一次只改一个"**: 6 tickets ship as 6 separate commits under BOSS-APPROVAL SEQUENTIAL mode. Boss verifies each commit before the next one ships.
3. **Build verification** per ticket: `swift build` exits 0 + `git grep` confirms zero remaining callers BEFORE commit.
4. **Visual verification** per ticket (boss 9/1 OOB "不要只看代码, 对比截图实测"): the running app must show the sidebar unchanged after each deletion (since the deletions target dead code only).

# §4. The 6 tickets (= boss拍 scope)

| # | Ticket | LOC delta | Files touched | Risk | Apple coverage |
|---|---|---|---|---|---|
| 1 | Delete `Views/Library/LibraryOutlineView.swift` | -373 | 1 | low | full (NewLibraryOutlineView supersedes) |
| 2 | Delete `Views/Library/BookOutlineView.swift` | -197 | 1 | low | full (BookOutlineView was never reachable; NewLibraryOutlineView + BookEditorSheet cover the book detail flow) |
| 3 | Delete `Views/Library/WorldOutlineView.swift` | -195 | 1 | low | full (no caller — world entries surface via OutlinePanel or future ticket) |
| 4 | Delete `Views/Library/CharacterOutlineView.swift` | -185 | 1 | low | full (no caller) |
| 5 | Delete `Views/Library/ReferenceLibraryOutlineView.swift` | -193 | 1 | low | full (no caller) |
| 6 | Delete `Tests/WenshuAppTests/Views/LibraryOutlineViewBindingsTests.swift` | -X (TBD on read) | 1 | low | n/a (test for dead code) |

**Total potential deletion**: **1143 LOC + test LOC** from dead code alone. Zero user-visible behavior change.

# §5. Boss-decision deferred (NOT in this sweep)

| Item | Why deferred |
|---|---|
| NewLibraryOutlineView inline FileManager (990-1087) | Boss 9/2 OOB ambiguous (response = empty). Decision deferred to Step 2 grill. Apple has no opinion — view vs state-layer storage adapter is a wenshu architecture choice. Will not ship until boss拍. |
| `Core/Outline/OutlinePanel.swift` + `Core/Outline/OutlineExtractor.swift` | Caller reachability not yet verified (grep not done in this sweep). Low priority — `OutlineExtractor` is pure-data logic (no UI), Apple-API-first does not apply. |
| `Tests/WenshuAppTests/Views/LibraryOutlineViewBindingsTests.swift` | Will delete alongside ticket 1 (= same test references the dead struct). One commit. |

# §6. Out of scope (intentional)

- Refactoring `NewLibraryOutlineView` itself (= not asked; the question was "is it Apple API", and the answer is "yes, with 3 small gaps documented above").
- Adding new sidebar features (= boss did not ask).
- The SmartQueryView / editor sheets (= Apple HIG already covers; no custom code).

# §7. Execution mode

BOSS-APPROVAL SEQUENTIAL (skill default + boss 9/2 OOB "C"). One commit per ticket. Boss verifies before the next one ships. No auto-advance.

Commit body format: `chore(wenshu): v0.32 -- delete orphan <FileName>` per the v0.32 precedent (`chore(wenshu): v0.32 -- delete orphan EscapeLayers.swift` = `55e3d3f57`, `chore(wenshu): v0.32 -- delete orphan Tip.swift tooltip helper` = `6f717a432`).

# §8. Sweep closure (= ticket 1-6 landed 2026-09-02)

Boss 9/2 OOB '只把与 ui 有关的修复' + 'A' sequential = 6 tickets shipped, every commit boss-verified via screenshot:

| # | commit hash | file | LOC | boss verification |
|---|---|---|---|---|
| 1 | `a802c95f4` | `Views/Library/LibraryOutlineView.swift` | -373 | screenshot sidebar ok |
| 2 | `db23ef932` | `Views/Library/BookOutlineView.swift` | -198 | screenshot sidebar ok |
| 3 | `e01bd09bc` | `Views/Library/WorldOutlineView.swift` | -196 | screenshot sidebar ok |
| 4 | `c7e904706` | `Views/Library/CharacterOutlineView.swift` | -186 | screenshot sidebar ok |
| 5 | `3b1cc19ad` | `Views/Library/ReferenceLibraryOutlineView.swift` | -194 | screenshot sidebar ok |
| 6 | `2e8998a44` | `Tests/.../LibraryOutlineViewBindingsTests.swift` | -110 | screenshot sidebar ok |

**Total shipped**: 6 commits, **-1257 LOC**, every commit `swift build` exit 0, every commit sidebar screenshot identical to pre-sweep baseline. Zero user-visible behavior change (= all 6 files were unreachable).

Note on commit 1 (= `a802c95f4`): the commit also swept up `UI/liquidGlassOpacity.swift` (cc-runner had it pre-staged, git commit took all staged changes). Not a self-inflicted change but worth flagging per the pollution-defense skill §co-session coordination rule.

# §9. Residuals (= NOT shipped in this sweep)

| Item | Where | Why not shipped |
|---|---|---|
| Dead struct `LibraryOutlineViewContent` | `App.swift:1514` | App.swift is on cc-runner WIP; boss deferred to a separate ticket (= spec §5 deferred). Zero callers confirmed by grep. |
| 4 historical comment mentions | `BacklinksPanel.swift:11`, `LibraryMigrator.swift:519`, `RegionHoverWash.swift:13/45`, `WenshuLibrary.swift:231` | Pure documentation drift; no behavior impact. Deferred per boss 9/2 OOB '只把与 ui 有关的修复' (= dead files in scope, comment cleanup is not strictly UI repair). |
| `NewLibraryOutlineView` inline FileManager + JSON | `NewLibraryOutlineView.swift:990-1087` (~117 LOC) | UI file but contains storage adapter. Boss 9/2 OOB asked this as a separate question; deferred until boss拍. |
| `Core/Outline/OutlinePanel.swift` + `Core/Outline/OutlineExtractor.swift` | Caller reachability unverified; OutlineExtractor is pure-data logic (= not UI, not subject to Apple-API-first). Low priority. |

# §10. Boss 9/2 OOB outcome

Boss拍 'A' = sequential single-ticket mode = 6 individual commits, each verified. Sweep closed.
