# Standards-Axis Code-Review Report v2 (post-FAIL remediation)

- **Spec under review**: `.scratch/2026-08-26-fcp-library-replica/spec.md` (revised, 306 lines, ~24 KB)
- **Prior report**: `code-review-2026-08-26-fcp-library-replica-standards-axis-report.md` (v1, FAIL)
- **Reviewer axis**: STANDARDS only — English-only + forbidden vocab + Apple HIG + Boss 8/22 + existing wenshu conventions + .ws layout conflict.
- **Real workspace verified**: `/Users/anbaiqiang/Documents/anbaiqiang.ws/` (`ls -la`, `find`, `cat Info.plist`).

---

## First-pass FAIL remediation verification

### F1 (CJK outside Boss OOB) — PASS

Spec L17-22 now defines three carve-out categories: (1) Boss OOB quotations, (2) UI label references, (3) FCP mapping table + cross-reference model + glossary entries. Every CJK line was re-checked against these categories.

- L6-9 (书架 / 世界观 / 角色 / 资料库): Boss OOB verbatim — **category 1**. PASS.
- L18-20 (carve-out self-reference, mentions 双轴 / 移动仓库 / 重置库): describes the carve-out itself — **category 1/2 self-reference**. PASS.
- L29-34 (FCP mapping headers 书架 / 一本书 / 章节 / 角色 / 世界观 / 资料库): **category 3**. PASS.
- L73-74, L77, L87, L89, L92, L93, L174 (Chinese `@` syntax + UI button labels 库属性 / 在 Finder 中显示 / 移动仓库 / 重置库 / 角色 / 世界观 / 资料库): **category 2** (UI label references; Swift source WILL carry these strings per Boss 8/25 'UI 全中文' carve-out — verified by precedent at `code-review-015.052-F1-standards-b18dd4691.md` Axis 9 PASS). PASS.
- L199, L206 (移动仓库 / 重置库): **category 2**. PASS.
- L200, L280, L306 (boss quotes 用户体验最完整 / 双轴每次都跑): **category 1**. PASS.
- L272 (CONTEXT.md glossary list 书架 / 书 / 世界观 / 角色 / 资料库 / 库属性 / 智能查询): **category 3** (CONTEXT.md is §11-exempt per AGENTS.md line 6). PASS.

Zero CJK hits fall outside the 3-category carve-out. Minor imprecision: the carve-out self-reference at L19 cites "L67/L70/L82/L86/L192/L199/L296" as UI label example lines, but `awk 'NR==70 || NR==82 || NR==192 || NR==296' spec.md` shows only L199 carries CJK (`移动仓库 / 重置库` button labels); the rest are context anchors. Carve-out is still accurate; tightening the list would reduce reviewer ambiguity (SUG-1).

### F2 (Boss 8/22 multi-file tickets 023/024/025) — PASS

Tickets 023, 024, 025 now carry explicit atomic-coupling justifications (spec L259-281).

- **Ticket 023 (L259-267)** — 3 NEW contract test files for World/Character/Reference Storing protocols. Justification: protocols from tickets 004/005/006 land in single-file tickets, but `swift test` runs against the whole package. If contract tests split, the user lives with 1 verified + 2 unverified protocols. Logically defensible.
- **Ticket 024 (L269-276)** — 2 MODIFIED files (AGENTS.md + CONTEXT.md). Justification: AGENTS.md §11 amendment backs the "NOT CoreData" claim; CONTEXT.md glossary references the new entities. Splitting leaves inconsistency (AGENTS-only = orphan glossary terms; CONTEXT-only = glossary points to §11 spec that doesn't exist yet). Logically defensible.
- **Ticket 025 (L278-281)** — 2 review report files, NO code change. Justification: boss 8/25 standing instruction "双轴每次都跑" mandates dual-axis batch review; single-axis reports are non-compliant.

All three justifications are logically defensible AND consistent with wenshu commit-log precedent: `git log` shows commits like `v0.25.1 ticket 017 + 018 — chapter preview / editor icons`, `v0.25.1 ticket 012 + 013 — second-column`, and `082ff6f86 fix(wenshu): v0.25.1 ticket 039 — 双轴 code-review fixes (Standards axis FAIL)` combine logically-coupled tickets in single commits.

### F3 (.ws layout conflict) — PASS

The spec now resolves all four sub-conflicts from v1:

1. **Info.plist is KEPT** (not renamed to info.json) — spec L41, L67, L218, L229. `Info.plist` stays at .ws root with `CFBundlePackageType=WSPC` already shipped by `LibraryRootView.swift:296-309` (verified by `grep -n "Info.plist\|CFBundle" LibraryRootView.swift` showing lines 294-303). `WSSchemaVersion` added as custom key inside existing `Info.plist` (L67, L229). Matches Standards SUGGEST-5 from v1.
2. **chat.sqlite (45 KB ACTIVE) is PRESERVED at .ws root** — spec L42, L68, L256. Workspace confirms `chat.sqlite` is 45056 bytes. No data loss.
3. **assets/ + backups/ are PRESERVED** — spec L69; ticket 022 L251 lists both in PRESERVE block.
4. **chapters/ + shelves/ at .ws root DROPPED only-if-empty** — spec L70; ticket 021 L244; ticket 022 L252.

Ticket 022's PRESERVE/DROP/CREATE/WRITE lists (L251-254) cover every file/dir actually present in `/Users/anbaiqiang/Documents/anbaiqiang.ws/` (verified via `find`):
- `Icon\r` — preserved by absence of DROP. ✓
- `Info.plist` — PRESERVE + WRITE `WSSchemaVersion = 1` (L254). ✓
- `chat.sqlite` — PRESERVE (L251) + explicit CRITICAL note (L256). ✓
- `assets/`, `backups/`, `books/` — PRESERVE (L251). ✓
- `chapters/`, `shelves/` — DROP only if empty (L252). ✓
- CREATE: `shared/references/`, `shared/smart/`, `cache/` (L253). ✓

All 8 actual items in the boss's real workspace are accounted for.

### F4 (AGENTS.md §11 CoreData contradiction) — PASS

Spec L15 carries explicit NOTE-on-§11: "§11 baseline line 16 currently declares 'Stack = ... CoreData ...'. This spec's 'NOT CoreData' claim therefore contradicts §11 until ticket 024 lands the §11 amendment. The spec assumes ticket 024 ships FIRST (re-sequence dependency: 024 before 001)."

The re-sequence (024 before 001) is documented (L15), AND ticket 024's scope at L271 explicitly includes "AGENTS.md §11 amendment: replace aspirational CoreData + .ws single file wording with the new .ws internal layout spec (= Standards F4 remediation)". Real `AGENTS.md §11` line 16 (verified via `read_file`) shows "Stack = Swift / SwiftUI + CoreData + single-process coroutine + self-built lightweight AI kernel." — contradiction correctly identified and amendment path is in ticket 024's scope.

---

## New PASS (improvements over v1)

**N1. Library Properties panel UX is HIG-correct.** Spec L86-93 declares the panel as a Settings menu item opening a modal sheet, with `NSOpenPanel` for path selection (L92) and `FileManager.moveItem` for atomic .ws relocate. Matches existing `LibraryRootView.swift:200` and `FileSystemLibraryStore.swift:268` conventions. Rollback on failure (L92) is HIG-correct for destructive UX.

**N2. .ws internal layout uses Apple's recommended 3-layer pattern.** Spec L38-63 uses canonical macOS application-support pattern: Info.plist at root (Apple HIG bundle), JSON index files alongside .md bodies, explicit `cache/` for derived data. Matches `WenshuWorkspaceMigrator.swift:39` precedent.

**N3. Cross-reference model consistent with boss Q2=a decision.** Spec L72-77 documents `@<type>.<name>` syntax with load-time resolution into `Document.refIds`. Each of 3 reference types (character / world / reference) maps to one Boss OOB Chinese entity (角色 / 世界观 / 资料库). Chinese→English type map is explicit (L73) so Swift source stays English-only.

**N4. Apple stack enforcement at spec level.** Spec cites macOS-only single platform (no iOS/iPadOS/Catalyst traces, consistent with `AGENTS.md §11` line 20 boss 8/18 拍) and uses only Apple APIs (SwiftUI + AppKit + Foundation + CoreData-not-used). No third-party SDK mentions.

---

## Remaining FAIL

None. All four first-pass FAILs (F1-F4) are remediated. The spec body is internally consistent, references real on-disk files, and the .ws layout migration plan covers every item in the boss's real workspace.

---

## New SUGGEST (non-blocking improvements)

**SUG-1. Line-number anchors in the CJK carve-out are slightly stale.** Only L199 actually carries CJK on the lines listed at L19 (L67/L70/L82/L86/L192/L296 are context anchors). Carve-out is still accurate, but tightening to "L67, L86, L92, L93, L199, L200" would reduce reviewer ambiguity.

**SUG-2. Spec could explicitly cite the prior wenshu multi-file commit precedent.** Atomic-coupling justifications at L259-281 are defensible on first principles but do not cite the wenshu commit-log precedent (`v0.25.1 ticket 017 + 018`, `082ff6f86 fix ... 双轴 code-review`). Adding a 1-line precedent cite would preempt v3 reviewer questions.

**SUG-3. Ticket 022 should explicitly handle "books/ is empty" case.** The boss's real workspace has an EMPTY `books/` (verified via `ls -la`). The migrator's PRESERVE block keeps `books/` regardless of emptiness — correct (an empty books/ may be a fresh user). Could note: "Empty `books/` is PRESERVE (= keep the empty directory). Migrator never deletes `books/` non-emptily."

**SUG-4. Smart query scope is under-documented.** Spec L208-214 (tickets 016 + 017) declares SmartQuery schema + UI but does not document how smart queries interact with cross-references (e.g., "find all chapters referencing character X"). Implied by FCP Smart Collection pattern (L35). Could add: "Smart queries may use `refIds` filters (= `entity UUID IN Document.refIds`) to find chapters referencing a specific character / world entry / reference." Non-blocking; spec axis.

**SUG-5. Ticket 022's `WSSchemaVersion = 1` write should specify idempotency order.** Spec L254 says "WRITE: WSSchemaVersion = 1 to existing Info.plist" and L256 says "Does NOT touch Info.plist if WSSchemaVersion key already exists (= idempotent)". Reordering to "READ existing Info.plist; if WSSchemaVersion key absent, WRITE it; else skip" improves clarity. Non-blocking; spec-axis.

---

## VERDICT

**VERDICT: PASS**

All four first-pass FAILs are remediated with real evidence:

- **F1**: 3-category carve-out at L17-22; every CJK line falls into one of three categories (verified line-by-line via grep + category mapping).
- **F2**: Atomic-coupling justifications at L259-281 are logically defensible AND consistent with wenshu commit-log precedent.
- **F3**: Info.plist kept, chat.sqlite preserved, assets/ + backups/ preserved, chapters/ + shelves/ dropped only-if-empty. Ticket 022 lists cover all 8 items in the real workspace.
- **F4**: Re-sequence 024-before-001 documented at L15; ticket 024 scope includes the §11 amendment (L271).

Zero forbidden vocabulary hits (12-term + 14-neutral-word scan both empty). Apple HIG conventions match (NSOpenPanel, FileManager, sheet presentation, Settings menu, Info.plist bundle pattern). Single-shelf model + Library Properties panel + cross-reference `@` syntax align with boss 2026-08-26 OOB (Q1=c, Q2=a, Q2=single-shelf, Q3=a). The spec is ready to enter the implementation phase.

Five non-blocking SUGGEST items sharpen spec quality but do not block. Standards-axis v2 PASS — the spec body is now compliant with AGENTS.md §11 + §12, Boss 8/22 protocol, and Apple HIG conventions.

**Note on allowlist**: This report enumerates CJK verbatim to prove the carve-out compliance (consistent with v1 report precedent at `.scratch/code-review-*`). The dir `.scratch/2026-08-26-fcp-library-replica/` may need a `POLLUTION_ALLOWLIST` entry in `Tools/wenshu-devtool/commit_filter.py` (see `wenshu-pollution-defense` skill). Non-blocking for standards-axis verdict.

---

*Standards-axis report v2 · 2026-08-26 · reviewer scope = English-only + forbidden vocab + Apple HIG + Boss 8/22 protocol + existing wenshu conventions + .ws layout conflict. Spec axis deferred to a separate review pass.*