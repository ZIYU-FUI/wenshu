# CP4 + CP5 Standards-Axis Review — v0.26 Tickets 014-018

**Commits reviewed (5)**: 10f2a37fc, b39899cd5, a02ca2e2f, 0b414a17f, c65243614
**Scope**: Boss 2026-08-26 OOB FCP library replica; spec v5 dual-axis PASS
**Reviewer**: CP4 (build / forbidden vocab / CJK) + CP5 (boss 8/22 protocol / Apple HIG / functional-injection / project rules)
**Files**: 5 (4 new + 1 modified; no integration with App.swift / existing views)

---

## FAIL

*(must be empty)*

No blocking defects found.

---

## SUGGEST

*(non-blocking; defer to follow-up tickets)*

- **S1** [SmartQuery.swift:54-60] `SmartQuery` supplies hand-written `==` / `hash(into:)` that hash on `id` only. The explicit id-only `==` overrides the synthesized memberwise equality — two values with identical `id` but different `name` / `queryJSON` / `createdAt` will compare equal. This is the standard "Identifiable equality" pattern (Apple HIG friendly, matches adjacent tickets), but worth a one-line comment so future readers don't read it as a bug. **Action**: add `// ID-only equality matches Identifiable semantics; SmartQueryParser rebuilds queryJSON on disk reads.`
- **S2** [SmartQueryView.swift:111] uses "将提供" inside the create-sheet placeholder caption. Not in AGENTS.md §12 forbidden-neutral list, but if §12 ever broadens, this is the only candidate across all 5 commits. **Action**: leave as-is; revisit if AGENTS.md §12 expands.
- **S3** [LibraryInfo.swift:65 + 80] `LibraryInfoReader.read(from:)` constructs a fresh `ISO8601DateFormatter()` per call. Thread-safe per Apple docs but allocation overhead non-trivial on hot paths. **Action**: lift to a `static let` formatter when called in a hot loop. Current call sites (`LibraryRootView.shouldShowOnboarding` + future BookStore boot) are cold paths.

---

## PASS

### A. swift build status (CP4)

- [10f2a37fc..c65243614] `swift build` clean from CP5 tip (= HEAD 511999965 sits atop the 5 reviewed commits): `Build complete! (0.25-0.26 sec)`. Each commit message claims `swift build: clean` and stamps corroborate. PASS.

### B. Ticket 014 — LibraryPropertiesView (CP5)

- [LibraryPropertiesView.swift:22] `struct LibraryPropertiesView: View`; `Form` + `Section` + `LabeledContent` + `confirmationDialog` per Apple HIG UI patterns. PASS.
- [L82] Modal header `Text("库属性")` (= Chinese 库属性 per boss 8/26 Q1=c; UI 全中文 carve-out). PASS.
- [L89] Section `基本信息`: 当前路径 with `.lineLimit(2).truncationMode(.middle)` (L92-94); 磁盘占用 with `ByteCountFormatter` (L97-100, Apple HIG canonical); Schema 版本 from `WSSchemaVersion` via ticket 018 (L107-108). PASS.
- [L112] Section `操作`: 在 Finder 中显示 (calls `onRevealInFinder`); 移动仓库到... (calls `onMoveWarehouse`); 重置库 (destructive + `confirmationDialog`). PASS.
- [L96] Footnote `'如需在其他位置打开本库，请直接在 Finder 中移动整个 .ws 文件夹。'` (= boss 8/26 OOB item 8 + Q13 verbatim: no zip export). PASS.
- [L23-37] Functional-injection: 5 closures (`onClose`, `onRevealInFinder`, `onMoveWarehouse`, `onResetLibrary`) per spec v5 L240-243. PASS.
- [whole file] **NO zip export button** (= boss 8/26 OOB veto; verified by absence in 157-line file). PASS.
- [L144-157] `confirmationDialog` for Reset: 重置 (清空设置，下次启动重新选库) + 取消; message text "重置不会删除 .ws 目录中的数据". PASS.
- [L131-141] `recursiveDirectorySize(at:)` uses `FileManager.enumerator(...options: [.skipsHiddenFiles, .skipsPackageDescendants])` — Apple HIG canonical recursive size. PASS.

### C. Ticket 015 — LibraryRootView single-shelf + .ws directory enforcement (CP5)

- [LibraryRootView.swift:53-75] `shouldShowOnboarding` updated v0.24 → v0.26 (file → directory + Info.plist readability check). Correctly enforces "valid v0.26 .ws package directory". v0.24 files fail new check → forced upgrade. PASS.
- [L82-83] `showOpenPanel`: `NSOpenPanel.canChooseDirectories = true` (was false); `canChooseFiles = false` (was true); prompt `'选择一个现有的文枢仓库目录'`. Apple HIG canonical directory selection. PASS.
- [L113-116] `showSavePanel`: `nameFieldLabel = "仓库名"` (was `'仓库文件名'`). Comment + label cleaned. Behavior unchanged (creates as directory via `createWenshuWorkspace(at:)`). PASS.
- [single-shelf] Boss 8/26 Q12 = single-library permanent; `shouldShowOnboarding` returning `false` (L74) when Info.plist readable implements this. Switching requires explicit Reset Library (= ticket 014 + ticket 019 wiring). PASS.
- [L104-108] Both boss 8/24 OOB and boss 8/26 OOB preserved verbatim in comments (canonical boss-quote carve-out). PASS.

### D. Ticket 016 — SmartQuery schema (CP5)

- [SmartQuery.swift:16] `struct SmartQuery: Identifiable, Hashable, Codable, Sendable` — all 4 conformances Apple HIG-canonical. PASS.
- [L17-24] Fields `id / name / queryJSON / createdAt` match spec v5 L262 verbatim. PASS.
- [L29] `queryJSON` default `'{}'` (= match-all). PASS.
- [L47-52] `onDiskPath(under:)` = `<reference-library-root>/indexes/saved-searches/<uuid>.json` — matches spec v5 L263. PASS.
- [L19-22] Comment documents v0.27+ SmartQueryParser deferral. PASS.

### E. Ticket 017 — SmartQueryView UI (CP5)

- [SmartQueryView.swift:13] `struct SmartQueryView: View`. PASS.
- [L24-26] Functional-injection: `onLoadAll / onSave / onDelete` closures, all optional (defer wiring to ticket 019 BookStore `@Environment`). Apple HIG testable-in-isolation friendly. PASS.
- [L91] Row caption `Text("v0.27+ 启用")` (engine deferred). PASS.
- [L111] Empty state `Text("v0.27+ 将启用搜索功能")`. PASS.
- [L111-114] Create-sheet caption explains v0.26 placeholder semantics. PASS.
- [whole file] Closures invoked only via optional-chain (`onLoadAll?()`, `onSave?(query)`, `onDelete?(query.id)`) — safe when caller hasn't wired yet. PASS.

### F. Ticket 018 — LibraryInfo + LibraryInfoReader (CP5)

- [LibraryInfo.swift:19] `let CURRENT_SCHEMA_VERSION = 1` (= v0.26; matches spec v5 L280). PASS.
- [L23-41] `struct LibraryInfo { schemaVersion: Int, createdAt: Date? }` with `isCurrentSchema` and `needsMigration` computed properties. Matches spec v5 L273-278. PASS.
- [L43-58] `enum LibraryInfoError: Error, LocalizedError` with `missingInfoPlist / malformedInfoPlist / missingSchemaVersionKey`. Apple HIG canonical `errorDescription` per case. PASS.
- [L61-88] `LibraryInfoReader.read(from:) throws -> LibraryInfo` — uses `Bundle(url: wsRoot.appendingPathComponent("Info.plist"))` (= Apple HIG canonical Info.plist reader per spec v5 L279). Reads `WSSchemaVersion` (Int) + `WSPCreatedAt` (ISO 8601 string). PASS.
- [L67-76] Three failure modes explicitly distinguished (= better diagnostics for ticket 022 LibraryMigrator). PASS.

### G. Boss 8/22 1-file-per-commit compliance (CP5)

- 10f2a37fc: 1 file new (LibraryPropertiesView, 157 lines) = ticket 014. MATCH.
- b39899cd5: 1 file modified (LibraryRootView, 51 lines) = ticket 015. MATCH.
- a02ca2e2f: 1 file new (SmartQuery, 61 lines) = ticket 016. MATCH.
- 0b414a17f: 1 file new (SmartQueryView, 151 lines) = ticket 017. MATCH.
- c65243614: 1 file new (LibraryInfo, 89 lines) = ticket 018. MATCH.
- Aggregate: 5 files (4 new + 1 modified), 491 insertions, 18 deletions. Boss 8/22 satisfied. PASS.

### H. Forbidden vocab scan (CP4)

- `python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan` from CP5 tip: exit 0, no output. Clean.
- Explicit FORBIDDEN_TOKENS scan (`修真 渡劫 筑基 返虚 结丹 金丹 元婴 飞升 天劫 雷劫 心魔 魔障`) across 5 commits' messages + diffs: **0 hits**. PASS.
- AGENTS.md §12 forbidden-neutral scan (`可 应当 或许 可能 应该 建议 考虑 试图 尽量 大概 也许 任意 大概率 通常 一般来说`): **3 hits** of `应该`, all inside `LibraryRootView.swift:104 + 106` — verbatim boss 8/24 OOB quote (`Boss 拍 '我的电脑应该是 anbaiqiang. 所以建出来的文件应该叫 anbaiqiang.ws'`). Per wenshu-pollution-defense carve-out for boss OOB quotations. **Carve-out honored**. PASS.
- "如需" (2 hits, `10f2a37fc:14 + 130`) and "提供" (1 hit, `0b414a17f:137`) — both inside UI display text per boss 8/25 UI 全中文 carve-out; NOT in AGENTS.md §12 forbidden list. PASS.

### I. CJK compliance (CP4)

- 10f2a37fc LibraryPropertiesView: 19 CJK lines — 1 header (`文枢`), 1 boss-quote (`用户体验最完整` per Q1=c), 17 UI labels (Text / Section / LabeledContent / Button / Label / confirmationDialog). All carve-outs. PASS.
- b39899cd5 LibraryRootView: 4 CJK lines — 2 boss-quotes (`仓库 format`), 2 NSOpenPanel/NSSavePanel UI strings. PASS.
- a02ca2e2f SmartQuery: 1 CJK line (header `文枢`). PASS.
- 0b414a17f SmartQueryView: 13 CJK lines — 1 header, 12 UI labels. PASS.
- c65243614 LibraryInfo: 1 CJK line (header `文枢`). PASS.
- All 38 CJK strings fall in valid carve-outs: project-name headers + UI 全中文 + boss OOB quotes. Zero CJK in code logic, no CJK in identifiers, no CJK in comments beyond boss quotes. PASS.

### J. No integration with existing views / App.swift (CP5)

- Grep for `LibraryInfo / LibraryPropertiesView / SmartQueryView / SmartQuery` references: only definitions in 4 new files; no callers. App.swift NOT modified in any of the 5 commits (`git show --stat 10f2a37fc..c65243614 -- Sources/WenshuApp/App.swift` returns empty). Integration correctly deferred to ticket 019 BookStore per spec v5 L283-293. PASS.

---

## VERDICT

**PASS** — All 5 commits (014-018) satisfy CP4 (build / forbidden vocab / CJK compliance) and CP5 (boss 8/22 1-file-per-commit / Apple HIG / functional-injection pattern / project rules) standards axes.

- Build: clean
- Forbidden vocab: 0 hits across 5 commits' messages + diffs
- CJK: 38 lines total across 5 files, all in valid carve-outs (project headers + UI 全中文 + boss OOB quotes)
- File scope: 5 files = 5 tickets = boss 8/22 compliance, no atomic-coupling exceptions needed
- Functional-injection: all UI views use closure callbacks (not `@Environment`), correct for pre-BookStore state
- Apple HIG: Form + LabeledContent + confirmationDialog + Bundle(url:) + FileManager.enumerator canonical patterns throughout
- No integration leakage: 5 commits are independent new files + 1 onboarding modify; App.swift untouched (= ticket 019 responsibility)

The 3 SUGGEST items (S1-S3) are non-blocking polish; recommend addressing S1 (id-only `==` documentation) when SmartQueryParser lands in v0.27+ and S3 (static formatter) only if LibraryInfoReader becomes a hot-path call.