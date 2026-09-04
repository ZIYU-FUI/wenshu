# CP4+CP5 Spec-Axis Code Review — v0.26 FCP Library Replica (Tickets 014-018)

**Spec:** `.scratch/2026-08-26-fcp-library-replica/spec.md` v5, dual-axis PASS (L249-281 covers tickets 014-018)
**Commits:** `10f2a37fc` (014 — `LibraryPropertiesView.swift`, 157 lines) · `b39899cd5` (015 — `LibraryRootView.swift`, 33+/18-) · `a02ca2e2f` (016 — `SmartQuery.swift`, 61 lines) · `0b414a17f` (017 — `SmartQueryView.swift`, 151 lines) · `c65243614` (018 — `LibraryInfo.swift`, 89 lines)
**Axis:** SPEC only — does each commit implement spec v5 tickets 014-018 faithfully (incl. boss 8/26 OOB + Q&A)?

---

## OOB cross-check

| # | OOB item (boss 2026-08-26) | Implementation | Verdict | Cite |
|---|---|---|---|---|
| O1 | Library = .ws (= single instance; locked to `UserDefaults.wenshu.libraryPath`) | LibraryRootView.swift:48 reads `@AppStorage("wenshu.libraryPath")`; ticket 014 panel reads same key via `libraryPath` prop. Ticket 015 trigger (L50-78) enforces single-instance: only one .ws path ever persisted. | PASS | spec L66, L124, L255-258 |
| O2 | Bookshelf = parent of books; user-named | Out of scope (pre-existing Bookshelf entity). No contradiction in 5 tickets. | PASS (N/A) | spec L116-118 |
| O3 | Book = novel project; 10 standard entries | Out of scope (tickets 003-007 + ticket 021). SmartQueryView adds NO per-book data; SmartQuery is library-scoped. | PASS (N/A) | spec L96-97 |
| O4 | World + Character = Book-private | SmartQueryView does not expose World/Character data. v0.27+ parser will reference them by id (SmartQuery.swift:13-22). v0.26 = schema skeleton only. | PASS (N/A) | spec L116-118 |
| O5 | Reference library = library-public, user CANNOT delete or rename | SmartQuery storage at `<reference-library-root>/indexes/saved-searches/` (SmartQuery.swift:46-52) inherits library scope. LibraryPropertiesView has no delete/rename UI for reference-library. | PASS | spec L98-103, L263 |
| O6 | Single-shelf model | Ticket 015 trigger checks .ws root only (no shelf enumeration). Ticket 014 panel operates on single .ws. Matches spec L254-258 "No 'switch library' button in Settings". | PASS | spec L123-127, L254-258 |
| O7 | Library Properties panel | Ticket 014 IS the implementation. All 5 spec fields: (1) path L56-61; (2) disk usage L62-72 + recursive enumerator L134-149; (3) schema version L73-76 from Info.plist; (4) "移动仓库到..." L84-88; (5) "重置库" destructive L89-93 + confirmationDialog L112-123. 3 button labels match spec L251. | PASS | spec L249-252, L240-243 |
| O8 | Migration via Finder, no zip export | LibraryPropertiesView.swift:14 explicitly comments "No zip export button". Grep confirms zero zip/archive code. Move Warehouse is the Finder-move alternative. | PASS | spec L135-136, L251 |
| O9 | "切书=切数据源" | Tickets 015/018 operate library-level only. LibraryInfoReader.read(from: wsRoot) (LibraryInfo.swift:62-88) takes .ws root URL only — per-book isolation delegated to tickets 004/005 + BookStore (ticket 019). | PASS | spec L14, L288-292 |

---

## Q&A cross-check (boss 8/26 decisions)

| # | Q decision | Implementation | Verdict | Cite |
|---|---|---|---|---|
| Q1 | scope: all 4 entity types | SmartQuery (ticket 016) covers 4th type. Other 3 covered by tickets 001-006 (sibling). Functional-injection callbacks in SmartQueryView.swift:24-26 deferred to BookStore wiring (ticket 019). | PASS | spec L122-127, L260-266 |
| Q2 | ownership: 角色+世界观 Book-private / 资料库 library-public | SmartQuery library-scoped under reference-library. LibraryPropertiesView library-level. No book-private state leaks into these 5 tickets. | PASS | spec L116-118, L260-263 |
| Q4 | Chapter stays as .md (NOT domain entity) | None of the 5 tickets creates Chapter domain entity. LibraryInfo reads `WSSchemaVersion` + `WSPCreatedAt` only (LibraryInfo.swift:74-83). | PASS | spec L92-95, L383 |
| Q5 | layout: `shelves/<shelf>/books/<book>/` + `reference-library/` | SmartQuery.onDiskPath (SmartQuery.swift:46-52) writes exactly to `<reference-library-root>/indexes/saved-searches/<uuid>.json` — matches spec L263 verbatim. | PASS | spec L82-103, L260-263 |
| Q6 | format: JSON sidecar + .md for folders; pure JSON for kanban/todo | SmartQuery (ticket 016) is pure JSON (single `.json` at SmartQuery.swift:38-41). No .md sidecar. | PASS | spec L96-97, L262-263 |
| Q7/Q10 | UUID shelf dirs | Out of scope (LibraryMigrator ticket 022). No contradiction. | PASS (N/A) | spec L312, L319 |
| Q11 | D7 panel: full panel (option c) | Ticket 014 implements FULL panel: 3 sections + 5 fields + 3 buttons + confirmationDialog. No truncation vs spec L249-252. | PASS | spec L249-252 |
| Q12 | single-library permanent | Ticket 015 trigger (LibraryRootView.swift:50-78) makes .ws path permanent once valid: 4 conditions all trigger re-onboarding. Escape hatch ONLY via Library Properties → "重置库" (L89-93 + confirmationDialog). No "switch library" UI. | PASS | spec L123-127, L254-258 |
| Q13 | move via Finder, no zip | LibraryPropertiesView has zero zip code (grep verified). Footnote L96 says "请直接在 Finder 中移动整个 .ws 文件夹". Move Warehouse (L84-88) provides in-app alternative. | PASS | spec L135-136, L251 |

---

## Ticket-by-ticket spec fidelity

- **Ticket 014 (spec L249-252):** All 5 fields present (LibraryPropertiesView.swift:54-77 basic + L78-94 actions). 3 button labels match spec L251: "在 Finder 中显示" L82, "移动仓库到..." L87, "重置库" L92. Functional-injection L30-40. No zip (boss veto, noted L14). `confirmationDialog` is Apple HIG. `onAppear { refreshDiskUsage() }` L111 auto-loads. **PASS.**
- **Ticket 015 (spec L254-258):** All 4 trigger conditions at LibraryRootView.swift:50-78: empty L66 / not .ws suffix L68 / not directory L73 / Info.plist not readable L76. `showOpenPanel` updated to `canChooseDirectories = true`. `showSavePanel` uses existing `createWenshuWorkspace`. **PASS.**
- **Ticket 016 (spec L260-263):** All 4 fields at SmartQuery.swift:17-24. `queryJSON` default = "{}" L29. `onDiskPath(under:)` L47-52 writes exactly to `<reference-library-root>/indexes/saved-searches/<uuid>.json`. `Codable + Identifiable + Hashable + Sendable` L16. **PASS.**
- **Ticket 017 (spec L265-266):** List + add/edit/delete UI at SmartQueryView.swift:56-77 + L95-128. v0.26 placeholder label per row "v0.27+ 启用" L65. Empty state "v0.27+ 将启用搜索功能" L88. Functional-injection L24-26. **PASS.**
- **Ticket 018 (spec L268-281):** `LibraryInfo` struct (LibraryInfo.swift:24-41). `LibraryInfoReader.read(from:)` using `Bundle(url:)` L65. All 3 spec error cases L43-58: `missingInfoPlist` / `malformedInfoPlist` / `missingSchemaVersionKey`, all `LocalizedError`. `CURRENT_SCHEMA_VERSION = 1` L21. **PASS.**

---

## FAIL

(none)

---

## SUGGEST (non-blocking)

1. **Ticket 014 takes `schemaVersion: Int`, not `LibraryInfo`.** LibraryPropertiesView.swift:27 — App.swift must call `LibraryInfoReader.read()` + extract `.schemaVersion` separately. Could expose "创建于: <date>" from `LibraryInfo.createdAt` alongside schema version. Non-blocking; no `createdAt` display requirement in v0.26.

2. **Ticket 015 trigger uses `isReadableFile` precheck, not full `LibraryInfoReader.read`.** LibraryRootView.swift:76 — does NOT verify `WSSchemaVersion == CURRENT_SCHEMA_VERSION`. A corrupted plist with `WSSchemaVersion = 99` passes predicate, crashes later in LibraryInfoReader. Pair precheck with full read at launch. Non-blocking (ticket 021 + 022 handle mismatch).

3. **Ticket 016 raw `String` queryJSON.** SmartQuery.swift:19-22 comment justifies schema evolution. Suggest typed `query: SmartQueryPredicate` lazy getter when v0.27+ parser lands. Non-blocking — intended v0.27+ design.

4. **Ticket 017 list has no footer `+` row.** SmartQueryView.swift:30-40 puts `+` in toolbar. Apple HIG typically uses list footer. Both valid. Cosmetic.

5. **Ticket 018 `needsMigration` doesn't handle future-schema case.** LibraryInfo.swift:38-40 returns `schemaVersion < CURRENT_SCHEMA_VERSION` only — a `.ws` from a future wenshu would silently pass `isCurrentSchema`. Add `.futureSchema` case. Non-blocking (v0.26 is single-version).

6. **Ticket 014 `recursiveDirectorySize` uses `.skipsPackageDescendants`.** LibraryPropertiesView.swift:140 — excludes nested packages. Intentional? No nested packages expected in .ws. Non-blocking.

---

## VERDICT

**PASS.**

All 5 commits (014-018) implement their respective spec v5 tickets faithfully. The 9 OOB summary items and 8 Q&A decisions are reflected in code with verifiable line citations. No spec FAILs found.

The 6 SUGGEST items are non-blocking: 3 forward-looking (016 typed getter, 018 futureSchema, 014 createdAt display) and 3 minor consistency notes (014 Int vs LibraryInfo, 015 partial precheck, 014 skipsPackageDescendants).

Per boss 8/22 protocol: 0 spec FAILs → spec-axis review PASS. Pair with standards-axis review for dual-axis sign-off.
