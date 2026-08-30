# Standards-Axis Code-Review Report v4 (post major architecture revision)

- **Spec under review**: `.scratch/2026-08-26-fcp-library-replica/spec.md` (v4, 412 lines, ~38 KB; v3 was 329 lines, +83 lines = 8-section architecture revision).
- **Prior reports**: v1 FAIL, v2 PASS, v3 PASS (`standards-axis-report-v3.md`).
- **Reviewer axis**: STANDARDS only — English-only + forbidden vocab + Apple HIG + Boss 8/22 + existing wenshu conventions + .ws layout conflict.
- **Method**: re-grep every CJK line; full forbidden-vocab re-scan; per-change verification against the v3→v4 deltas in the parent brief (terminology, Book structure, layout, ticket 019/021/022/012/026); re-anchored carve-out citation block at L55-57 to actual line numbers.

---

## v4 change verification

### Change-1 — Terminology table at L3-13 → PASS
4 rows × 4 cols. Boss quote "库 = .ws, 书架 = 书的父级, 资料库 = 默认的书架, 用户不能删除, 不能重命名" captured at L7, L8, L10, L14. CJK falls into category 3.

### Change-2 — Book structure at L16-38 → PASS
8 folders at L22-29; 2 JSON files at L30-31. Folder-vs-JSON at L33-36. Diagram at L93-97 mirrors (8 folders L93, 8 sidecars L95, kanban + todo L96-97). 10 entries match ticket 021 (L304) + 022 (L316).

### Change-3 — FCP mapping at L63-79 → PASS
Library / Bookshelf / Book / Reference renamed. Foreshadowing / Placeholder / Kanban / Todo at L72-75 marked "not in FCP". Library Properties row at L78 = "Inspector Ctrl-Cmd-J".

### Change-4 — `.ws` layout at L82-105 → PASS
`shelves/<shelf-uuid>/{shelf.json, books/}` at L87-91. `reference-library/{raw, entities, abstracts, indexes}/` at L98-103. ReferenceLibrary sibling to `shelves/` (both root at L87, L98) = boss Q3 "在书架漏出" (L237).

### Change-5 — Ticket 019 at L283-293 → PASS
Single `BookStore` (@Observable) at L285. `@Environment(BookStore.self)` at L291 = Apple standard. L293: "NOT a separate Store instance per book... single store, observation-driven reload". Boss 8/26 "反面 apple 标准实现是对的" honored.

### Change-6 — Tickets 021 + 022 at L299-319 → PASS
021 creates `shelves/`, `reference-library/`, `cache/` + 10 entries per book. 022 moves `books/` → `shelves/<auto-id>/books/` (L312), auto-shelf "Default Shelf" (默认书架, L312). WSSchemaVersion=1 (L315). chat.sqlite preserved (L318).

### Change-7 — Ticket 012 at L234-243 → PASS
ReferenceLibrary = sibling to user `shelves/` (L236). 4-layer LLM Wiki at L239-241. L243 cites boss OOB verbatim ("用户不能删除，不能重命名").

### Change-8 — Ticket 026 NEW at L367-387 → PASS
2 NEW files at L370-371. Storage `kanban.json` + `todo.json` (L382). Boss "kanban/todo功能没实装" cited L384. Why-not-SQLite at L385 (JSON + Codable = Apple standard). Atomic-coupling at L387.

---

## Regression check

- **12 xianxia terms** (修真/渡劫/筑基/返虚/结丹/金丹/元婴/飞升/天劫/雷劫/心魔/魔障): 0 hits.
- **14 neutral words** (可/应当/或许/可能/应该/建议/考虑/试图/尽量/大概/也许/或/任意/大概率/通常/一般来说): 0 hits.
- **CJK**: 58 lines, all map to 3 carve-out buckets. 0 out-of-category.
- **⚠️ RE-SEQUENCE ⚠️** at L52 (shifted from v3 L15): preserved; ⚠️ (U+26A0) is Unicode. AGENTS.md §11 L16 contradiction remains real.
- **Apple HIG**: NSOpenPanel (L83, L135), FileManager.moveItem (L135), UserDefaults.wenshu.libraryPath (L83, L123, L135-136, L256, L258), SwiftUI @Environment (L285, L291), Bundle(url:) (L279), Settings modal (L130-136, L251), Apple HIG bundle pattern (L84, L108). All v3 signals preserved.
- **Wenshu conventions**: FileSystemLibraryStore precedent (L203), LibraryStoring injection (L291), LibraryRootView.swift:296-309 Info.plist writer (L84, L108). 老板 (§12) 0 occurrences; "Boss"/"boss" in 30+ lines.
- **Boss 8/22**: 1-file-per-commit default for 001-022, 025; atomic-coupling justifications retained for 023 (L321-328), 024 (L331-338), 026 (L387); 024b still PLANNING with boss-decision gate (L341).

### One documentation-accuracy issue (NOT a forbidden-vocab violation)
Carve-out citation block at L55-57 carries **stale line anchors** (spec body grew 83 lines, v3=329 → v4=412):

- L55 cites "L193, L273/L299" → actual: L252, L364/L412
- L56 cites "L74, L87, L89, L92, L93, L174, L199, L200, L206" → actual: L117, L130, L132, L135, L136, L116, L251, L252, L258
- L57 cites "L22-27, L66-70, L265" → L22-27 + L66-70 correct; L265 stale (should be L334)

Regression of SUG-2 from v3 (same class of stale-citation error). CJK content itself remains correctly categorised; only anchors drift. Not blocking, flagged for follow-up.

---

## VERDICT

**VERDICT: PASS.**

All 8 v3→v4 changes PASS. v3 PASS preserved across every axis: 0 forbidden vocab (12 xianxia + 14 neutral), 0 out-of-category CJK (58 lines, all in carve-out buckets), Apple HIG unchanged, Boss 8/22 intact, wenshu conventions matched, .ws layout conflict resolution carried forward.

The ⚠️ RE-SEQUENCE HARD REQUIREMENT ⚠️ remains unmissable at L52 and traceable to AGENTS.md §11 L16. Apple standard @Observable pattern in ticket 019 correctly described (single BookStore, observation-driven reload). ReferenceLibrary sibling-of-shelves claim matches boss Q3 verbatim. 10 standard entries per book itemized consistently across §Book structure (L22-31), layout (L93-97), and migration (L304, L316). JSON-vs-folder distinction documented at L33-36.

One minor issue flagged: L55-57 carve-out citation block carries stale line anchors due to spec growth. CJK content itself is correctly categorised; only anchors drift. Not blocking.

Spec body is internally consistent, references real on-disk files, and is ready to enter implementation — conditional on boss 8/22 §11 re-sequence (024 before 001), boss拍 on ticket 024b option (a/b/c), and a minor line-anchor refresh in L55-57.

Standards-axis v4 PASS. Spec axis review remains a separate pass.

---

*Standards-axis report v4 · 2026-08-26 · reviewer scope = English-only + forbidden vocab + Apple HIG + Boss 8/22 protocol + existing wenshu conventions + .ws layout conflict. Spec axis deferred to a separate review pass.*