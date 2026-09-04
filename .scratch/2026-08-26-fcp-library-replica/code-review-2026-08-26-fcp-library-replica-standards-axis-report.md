# Standards-Axis Code-Review Report

- **Spec under review**: `.scratch/2026-08-26-fcp-library-replica/spec.md` (260 lines, 16 KB)
- **Reviewer axis**: STANDARDS only (= English-only + forbidden vocab + Apple HIG + Boss 8/22 protocol + existing wenshu conventions + .ws layout conflict). Spec axis deferred.
- **Boss 2026-08-26 OOB summary**: replicate FCP library management (single Shelf / Book / world + characters Book-private / reference library Shelf-shared).
- **Hard rules checked**: AGENTS.md §11 (English-only, forbidden vocabulary), §12 (sole address = 老板), Boss 8/22 (1 zone 1 ticket 1 commit, 1 file per commit unless atomic coupling), Apple HIG (NSOpenPanel / FileManager / sheet / NavigationStack), existing wenshu patterns (Book / Document / LibraryStoring / FileSystemLibraryStore / LibraryRootView).

---

## PASS

### A1. Forbidden vocabulary — clean

The 12 forbidden xianxia terms (`修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障`) are **zero hits** in the spec (Python regex scan of full file). The 14 forbidden neutral words are **zero hits** for the 12 multi-char forms. Single-char scan (`可 / 或 / 任意 / etc.`) also **zero hits**. Sole address `老板` does NOT appear in the spec body (the OOB block refers to `Boss 2026-08-26 OOB` in English, consistent with the protocol that 老板 is reserved for dialog, not spec text).

### A2. Apple HIG conventions — partial match

- `NSOpenPanel` is correctly used for path selection (line 31, 75). Matches existing `LibraryRootView.swift:200` pattern (`NSOpenPanel().beginSheetModal(for:)`).
- `FileManager.moveItem` for atomic .ws relocate (line 75) matches `FileSystemLibraryStore.swift:268` convention.
- Sheet presentation proposed for editor sheets (lines 162-178) matches `LibraryOutlineView.swift:93` `.sheet(item:)` pattern already in use.
- Apple HIG `Library Properties` panel as `Settings` menu item (line 70-77) matches the FCP-style Inspector pattern.

### A3. Existing storage convention — match for ticket-level detail

- `LibraryStoring` protocol pattern (lines 141-142): `WorldStoring` / `CharacterStoring` / `ReferenceStoring` mirrors `LibraryStoring.swift:88-196` protocol shape (rootURL, load/save/delete atomic + idempotent).
- `replaceItemAt` + tmp-file + atomic rename (line 143) matches `FileSystemLibraryStore.swift:111-136` canonical pattern.
- Codable struct pattern (lines 85-99, 106-122, 128-138) matches `Book.swift:56-148` pattern (`Identifiable, Hashable, Codable, Sendable` + id-based `==` + hash).
- `displayName` Chinese strings inside enum getter (line 96, 119) match `BookLength.displayName` (`Book.swift:47-53`) and `BookCategory.displayName` (`Document.swift:63-69`) carve-out.

### A4. Onboarding single-shelf enforcement

- `LibraryRootView.swift` modification (ticket 015, line 186) matches the existing `@AppStorage("wenshu.libraryPath")` (line 48) and `shouldShowOnboarding` predicate (line 50-70) pattern. Single-shelf decision (line 62-66) is consistent with existing v0.24 boss验收 logic.

### A5. App.swift wiring

- Ticket 019 (line 205-207) modifying App.swift to inject 4 stores via `.environment(...)` matches existing injection pattern at `App.swift:984` (`.environment(library)`) and `App.swift:1995` (`@Environment(WenshuLibrary.self) private var library`).

### B. Spec structure — well-formed

- All 25 tickets are listed with clear file targets. Tickets 001-022 follow the dominant "1 new file per ticket" pattern. Documentation ticket 024 targets 2 files. Code review ticket 025 is meta (no code change).

---

## FAIL

### F1. CJK characters outside the Boss OOB block violate AGENTS.md §11

**Rule**: AGENTS.md §11 hard rule line 6: "All `.scratch/spec.md`, `.scratch/issues/`, `.scratch/backlog` files... follow the same English-only rule." AGENTS.md §11 line 5: "No Chinese characters. No CJK punctuation. No mixed CJK + Latin characters."

**Exception carved out**: Boss 2026-08-26 OOB block (lines 3-13) is a direct boss quote — Chinese is required there. Boss 8/25 'UI 全中文' carve-out applies to user-facing UI text inside `.swift` source files, NOT to spec document body text.

**Violations**:

| Line | CJK content | Status |
|------|-------------|--------|
| L20-25 | FCP mapping table headers: 书架 / 一本书 / 章节 / 角色 / 世界观 / 资料库 | NOT in OOB block (L20 > L13). Spec author choice. |
| L57 | `@角色.张三`, `@世界.江南`, `@资料.明代税收` | Example data, but Chinese names in spec body, not in OOB. |
| L60 | `all chapters mentioning 张三` | Spec body, not OOB. |
| L70, L72, L75, L76, L77 | UI text strings (`库属性...`, `在 Finder 中显示`, `移动仓库到...`, `导出整库为 zip`, `重置库`) quoted in spec | UI text inside `.swift` source is OK (Boss 8/25 carve-out). But SPEC TEXT (the description) contains these strings inline. The description should be English; the Chinese string is what the .swift file will contain. |
| L131 | `// e.g. "《万历十五年》", "Smith 2020"` | Source code comment. AGENTS.md §11 applies to comments in any committed file. |
| L157 | `parse @角色.<name> / @世界.<name> / @资料.<title>` | spec body text, not OOB. |
| L182, L189 | `移动仓库` + `重置库` quoted as button labels | Same as L70-77. |
| L183 | `用户体验最完整` (boss Q1=c justification) | Direct quote OK if framed as "per boss Q1=c: ..." but the quote itself is CJK in spec body. |
| L231 | `书架 / 书 / 世界观 / 角色 / 资料库 / 库属性 / 智能查询` (CONTEXT.md glossary entries) | The CONTEXT.md file itself is exempt per AGENTS.md §11 line 6 (it's a domain glossary). But the LIST inside the spec.md is CJK content. Acceptable IF we accept that spec describes what CONTEXT.md will contain. Borderline. |
| L233, L260 | `双轴 code-review` | spec body — non-English protocol name. Boss 8/25 protocol is colloquial; English paraphrase "dual-axis code-review" is more consistent. |

**Remediation**: Replace the CJK in the spec body (everything outside L3-13 Boss OOB block) with English. The Chinese `displayName` getter content is OK inside Swift code samples (matches `BookLength.displayName` carve-out). For UI button labels quoted in spec description, write the description in English and use `"..."` quotes around the actual Chinese string that will appear in the .swift source (e.g. `Button labeled "移动仓库" (= "Move warehouse")` is borderline; `Button labeled with the literal "移动仓库" (= Library Properties panel move button)` is acceptable IF framed as a quote of the future .swift content, NOT as spec authoring language).

**Severity**: FAIL (AGENTS.md §11 hard rule, blocking).

### F2. Boss 8/22 protocol violation — Tickets 023, 024, 025 exceed 1-file scope

**Rule**: Boss 8/22 protocol (per `AGENTS.md` v0.07.2 + prior wenshu tickets, e.g. `CONTEXT.md` line 67 "老板 2026-08-22 06:46 拍... add a principle"): "1 zone 1 ticket 1 commit, 1 file per commit unless atomic coupling."

**Violations**:

| Ticket | Header claim | Actual scope | Atomic justified? |
|--------|--------------|--------------|-------------------|
| 023 (L225) | `Tests for new stores (= 1 file per store, 3 files)` | **3 NEW files** (`WorldStoringContractTests.swift` + `CharacterStoringContractTests.swift` + `ReferenceStoringContractTests.swift`) | NO |
| 024 (L229) | `AGENTS.md §11 update + CONTEXT.md glossary (= 2 files)` | **2 MODIFIED files** (`AGENTS.md` + `CONTEXT.md`) | NO |
| 025 (L233) | `双轴 code-review batch (= per boss 8/25 protocol)` | Standards + Spec axis reports. Spec implies this produces a report file but no file target listed. | NO |

**Remediation**:
- Ticket 023: split into 023a / 023b / 023c, OR add explicit atomic-coupling justification (e.g. "3 contract test files are atomic because the Storing protocol surface changes between tickets 004-006 must be locked together with their contract tests before ticket 019 App.swift wiring runs"). Without that justification, this is a 3-file commit.
- Ticket 024: split into 024a (AGENTS.md §11 spec update) + 024b (CONTEXT.md glossary additions), OR add atomic-coupling justification ("AGENTS.md + CONTEXT.md must land together because the glossary entries in CONTEXT.md reference the §11 layout spec in AGENTS.md; splitting them would leave CONTEXT.md glossary referring to a §11 spec that doesn't yet exist").
- Ticket 025: clarify file scope. Standards + Spec reports are separate files. Either split into 025a (standards-axis-report.md) + 025b (spec-axis-report.md) OR add atomic-coupling justification.

**Severity**: FAIL (Boss 8/22 protocol, blocking per boss 拍).

### F3. .ws layout conflict — regression vs. v0.24 shipped state

**Actual current state** at `/Users/anbaiqiang/Documents/anbaiqiang.ws/` (boss real workspace):

```
Icon\r  (Finder icon metadata)
Info.plist  (Apple HIG bundle Info.plist, 544 B, ACTIVE)
chat.sqlite  (45 KB, ACTIVE — chat history from v0.23-v0.24)
assets/   (empty)
backups/  (empty)
books/    (empty)
chapters/ (empty)
shelves/  (empty)
```

**Proposed new layout** (spec L31-54):

```
info.json          <- RENAMED (was Info.plist)
library.sqlite     <- NEW (no chat.sqlite migration specified)
books/             <- PRESERVED
shared/            <- NEW
cache/             <- NEW
```

**Conflicts**:

1. `Info.plist` → `info.json`: The Apple HIG bundle pattern (LibraryRootView.swift:296-309 already writes `Info.plist` with `CFBundlePackageType = "WSPC"` + `CFBundleIdentifier`). Renaming to `info.json` breaks:
   - The bundle contract that NSSavePanel / Finder registers (`Info.plist` is the canonical bundle metadata file).
   - Any existing `NSWorkspace.setIcon` + `Info.plist` registration in v0.24 (`LibraryRootView.swift:296-309`).
   - Backward compat with `LibraryRootView.swift:64` trigger check `if !libraryPath.hasSuffix(".ws")` (still OK, since `.ws` extension is preserved) but the internal layout change is silent.
2. `chat.sqlite` (45 KB, ACTIVE) NOT in proposed layout: Where does chat history go? The v0.21+ chat module writes here. Spec proposes `library.sqlite` but does NOT specify migration of `chat.sqlite` data. This is data loss unless `LibraryMigrator` (ticket 022) handles it. Spec ticket 022 (L219-223) ONLY mentions `rename chapters/ → drop; rename shelves/ → drop; keep books/; create shared/, cache/, info.json`. **`chat.sqlite` is not migrated** — silent data loss for boss's own 45 KB of chat history.
3. `assets/` + `backups/` + `chapters/` + `shelves/` dropped without explicit re-mapping. Ticket 022 says "rename shelves/ → drop; rename chapters/ → drop" but `assets/` and `backups/` are not mentioned. Are these user data or system data? Spec doesn't say.
4. `library.sqlite` is proposed for "cross-cutting tags, smart queries, search index, references index" (L33) but it overlaps with `chat.sqlite` usage from v0.21+ chat module. Two `.sqlite` files in one `.ws` = concurrent SQLite writers on different files, but if both are opened by the same `FileManager` instance this is fine; but spec doesn't document this.

**Remediation**:
- Rename `info.json` → `Info.plist` (preserves Apple HIG bundle pattern, no regression to v0.24 shipped code at `LibraryRootView.swift:296-309`).
- Make `LibraryMigrator` (ticket 022) explicitly migrate `chat.sqlite` → `library.sqlite` (rename + schema merge if needed) — OR document `chat.sqlite` as a sub-table of `library.sqlite` from day 1.
- Document where `assets/` + `backups/` go: option (a) drop and user re-creates, option (b) migrate to `cache/assets/` + `cache/backups/`, option (c) keep at root.
- Add notes explaining that `library.sqlite` lives alongside the (migrated or retained) `chat.sqlite` to avoid writer confusion.

**Severity**: FAIL (data loss risk + regression vs v0.24 shipped layout).

### F4. AGENTS.md §11 wording drift — claim "filesystem JSON + .md, NOT CoreData" contradicts §11 baseline

**Rule**: AGENTS.md §11 line 16: "Stack = Swift / SwiftUI + **CoreData** + single-process coroutine + self-built lightweight AI kernel." §11 line 19: "`.ws` single file = **CoreData** + attachments, locally self-managed."

**Spec claim**: Spec line 13 "Constraint: the architectural shape mirrors FCP... but the internal layout is wenshu-specific (**filesystem JSON + .md, NOT CoreData**)."

**Conflict**: This contradicts AGENTS.md §11 baseline directly. The spec proposes replacing CoreData with filesystem JSON + .md, which IS an architectural decision that contradicts the project baseline. Per Boss 8/22 protocol + AGENTS.md §11, this requires explicit boss 拍板 to amend §11, NOT a silent spec assumption.

**Spec line 230-231 also acknowledges this**: "`AGENTS.md`: replace aspirational CoreData + .ws single file wording with the new .ws internal layout spec" — this is ticket 024's scope, but the spec body L13 contradicts §11 BEFORE ticket 024 lands. The spec itself is internally consistent (it plans the AGENTS.md update), but a reader seeing only the spec body before ticket 024 lands will see a contradiction.

**Remediation**: Either (a) make the spec body L13 a forward-reference to ticket 024 ("see ticket 024 for AGENTS.md §11 update; this spec assumes the boss has approved the §11 amendment"), OR (b) sequence ticket 024 FIRST (before ticket 001 lands).

**Severity**: FAIL (AGENTS.md §11 baseline conflict, blocking).

---

## SUGGEST

### S1. Spec header lacks a single-paragraph summary before the design section

The spec jumps straight from Boss OOB (L3-13) to the FCP mapping table (L17-27). A 2-3 line English summary after the OOB would orient readers (e.g. "This spec implements FCP-style 3-layer library management on the wenshu filesystem, replacing v0.24 CoreData intent with explicit JSON + .md files at three levels: Shelf (single .ws) / Book (per-book private world+characters) / Shelf-shared references and smart queries.").

### S2. `displayName` Chinese strings in Ticket 001 + 002 should cite the carve-out explicitly

The spec line 100 says "Per boss: file written English-only; Chinese displayNames live in `displayName` getter (matches BookLength pattern)." This is correct but only mentions it ONCE. Tickets 002 (Character) also has `displayName` (L119) and `colorHex` (L120). Add the same carve-out citation to each ticket that contains `displayName` Chinese getter content to avoid reviewer ambiguity.

### S3. Library Properties panel — explicit "modal sheet" vs "window" choice

Spec line 71 says "Opens a modal sheet containing..." This matches Apple HIG (`presenting inspector as a sheet for modal-yet-non-blocking detail`, per `developer.apple.com/documentation/swiftui/sheet`). However, FCP's actual Library Properties Inspector is a non-modal floating panel (NSPanel / `windowLevel` = `.floating`). The spec uses "modal sheet" which is HIG-correct but FCP-different. Add a 1-line justification: "We choose modal sheet over floating NSPanel because... (a) simpler SwiftUI implementation, (b) Apple HIG canonical for properties dialogs, (c) matches existing wenshu `BookEditorSheet` pattern."

### S4. `@`-syntax parser (Ticket 007) needs a perf note

Spec line 157 says "resolves at load time, cached". The `Document.refIds` are resolved at load time from a name-based lookup against character/world/reference indexes. For a Book with 50 chapters × 20 references each, this is 1000 lookups at load time. Add a note: "Cache strategy = `Document._refIdCache: [String: UUID]?` invalidated on character/world/reference rename. v0.27+ can promote to in-memory index at app launch."

### S5. `info.json` schema versioning (Ticket 018) is awkward when paired with `Info.plist`

If the team keeps `Info.plist` for Apple HIG bundle registration AND adds `info.json` for schema version, the two files carry overlapping metadata. Suggest merging: keep `Info.plist` + add `CFBundleVersion` is already there (line 302 of `LibraryRootView.swift` already uses `CFBundleShortVersionString = "0.24.0"`). The schema version field can live in `Info.plist` as a custom key `WSSchemaVersion`. This removes the need for `info.json` entirely.

### S6. Tests count claim at L254

Spec L254 says "all tests pass (= existing 584 + new ~120 = ~700)". This is forward-looking and likely accurate, but the spec has no `Tests/` directory baseline count. Suggest cross-referencing the actual count from `find Tests -name '*Tests.swift' | wc -l` at the time of writing.

---

## VERDICT

**VERDICT: FAIL**

Summary of blocking failures:

1. **F1 (CJK outside Boss OOB)**: 19+ CJK hits outside L3-13 violate AGENTS.md §11 English-only hard rule. Most are legitimate UI-text carve-outs but the spec body itself is not a Swift source file and the §11 carve-out doesn't apply to `.scratch/spec.md`.
2. **F2 (Boss 8/22)**: 3 tickets (023, 024, 025) span >1 file without explicit atomic-coupling justification. Pure protocol violation.
3. **F3 (.ws layout)**: 45 KB of active `chat.sqlite` data + `Info.plist` registration are at risk. Migration shim ticket 022 does NOT cover `chat.sqlite`, `assets/`, or `backups/`. Pure data-loss risk for boss's real workspace.
4. **F4 (AGENTS.md §11)**: Spec body L13 contradicts §11 baseline ("filesystem JSON + .md, NOT CoreData") before ticket 024 lands the amendment. Forward-reference or sequence fix needed.

Recommended remediation order:
1. Add `.scratch/2026-08-26-fcp-library-replica/` to `POLLUTION_ALLOWLIST` in `Tools/wenshu-devtool/commit_filter.py` if the team accepts CJK in this dir (consistent with other `.scratch/*` allowlist entries). OR scrub CJK from the spec body.
2. Split tickets 023 + 024 into atomic 1-file tickets, OR add explicit atomic-coupling justifications.
3. Expand ticket 022 to migrate `chat.sqlite` + document `assets/` + `backups/` disposition. Keep `Info.plist` as the metadata file (Apple HIG bundle pattern).
4. Either reorder so ticket 024 lands first, or add forward-reference disclaimer in spec L13.

6 SUGGEST items are non-blocking improvements; they sharpen spec quality but don't block implementation.

*Standards-axis report v1 · 2026-08-26 · reviewer scope = English-only + forbidden vocab + Apple HIG + Boss 8/22 protocol + existing wenshu conventions + .ws layout conflict. Spec axis deferred to a separate review pass.*
