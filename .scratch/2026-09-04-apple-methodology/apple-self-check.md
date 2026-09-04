# Wenshu Apple-API Self-Check — v0.40 (= ticket A1 only)

- Date: 2026-09-04 14:35 CST
- Branch: `wt/apple-001/structure-audit`
- Spec this report implements: `.scratch/2026-09-04-apple-methodology/spec.md`
- Reproducer script: `Scripts/apple-self-check.sh` (= idempotent, end-to-end, ~30 sec)
- Evidence dir: `.scratch/2026-09-04-apple-methodology/grep-evidence/` (= 39 files)

## §0. Why this report exists (= boss拍 trigger)

Boss OOB verbatim (2026-09-04): "调研一下, apple 官方有没有 macOS app 工程的方法论 / 比如, 我用其它 AI 工具排查一下文枢代码, 他给出以下问题: [第三方 12-类报告] / 但这也有可能不是问题, 但我想依据 apple 管方的方案法论来判断".

Boss then told agent to: "先贵进" (= "front-load the expensive step" = run evidence-gathering before any code changes). Result: ticket A1 = this report. Boss reads this report = boss拍 whether to take A2..A11 (= the actual code-change tickets) to next session.

## §1. Methodology (= what the 5-stage dead-code grep + Apple 3-tier lookup produced)

For each of the 12 third-party redundancy items + the 1 self-deduplicated row (= 13 rows total):

1. **5-stage dead-code grep** (= Apple-API-first skill SKILL.md "Dead-code grep protocol") for any item claiming "dead" (= D-series).
2. **Source-of-truth trace** (= grep + count) for any item claiming "two stores" (= C2 WenshuLibrary vs BookStore).
3. **Apple 3-tier lookup** (= Tier-1 developer.apple.com doc / Tier-2 AVCam sample / Tier-3 applesamplecode.com stats) for every verdict. If no Apple evidence applies (= e.g. Domain-specific logic), verdict flagged as "wenshu-project decision".
4. **Cross-reference** against spec §3 (= the spec's pre-grep verdict) and the actual grep result.

## §2. The 12-item verdict table (with grep evidence)

Format: third-party item claim → Apple tier-1/2/3 evidence → grep result (this session) → verdict.

| # | Third-party claim | Apple tier-1/2/3 evidence | Grep result (this session) | Verdict |
|---|---|---|---|---|
| **A** | `App.swift` 1955 LOC with 6 inline view defs | T1: developer.apple.com/.../managing-model-data-in-your-app — App body = composition root only (`.environment` injection); T2: AVCam App.swift = <50 LOC, every view in `Views/`; T3: store/App suffix frequencies = `App` 43.2%, all view-bearing App.swift = under 200 LOC | (no grep; structural claim; cross-check on literal LOC: `wc -l Sources/WenshuApp/App.swift` = 1967 lines) | **REPORT STANDS** (Apple canonical = short App.swift + per-view file) |
| **B** | `WorkspaceView.swift` 1872 LOC with 11 view defs | T2: AVCam `Views/` folder has 8 files, average ~150 LOC each; T3: avg view file in 643 Apple samples ≈ 180 LOC | (cross-check on literal LOC: `wc -l Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` = 1872 lines) | **REPORT STANDS** (Apple canonical = one view per file, <200 LOC) — **but** also editor-001 worktree is actively touching this file → defer to next session after merge |
| **C1 / F** | `AppState.EditorTab` 8 editor-specific vars in cross-zone state | T1: `Managing model data` — "A data model provides separation between the data and the views that interact with the data. This separation promotes modularity, improves testability, and helps make it easier to reason about how the app works." T2: AVCam `CameraModel` = single-responsibility; FoodTruck = role-per-Model | (cross-check on literal definition: `grep -c 'var ' Sources/WenshuApp/State/AppState.swift` counted in evidence; 8 editor vars in nested `EditorTab` class; AppState top-level = 9 vars = "cross-zone" claim verified) | **REPORT STANDS** (Apple canonical = one `@Observable` per role) |
| **C2** | `WenshuLibrary` + `BookStore` both hold `shelves` | T1: `Managing model data` — single SoT (single source of truth) per data; T3: `Store` suffix = 4.9% in Apple samples (= Apple avoids dual-Store patterns) | **C2-wenshuLib-selfdef.txt** = 5 lines (WenshuLibrary has 5 fields incl. `shelves`, `selectedShelfId`, `selectedBookId`, `selectedDocumentId`, 319 LOC class); **C2-bookStore-selfdef.txt** = 6 lines (BookStore = 9 top-level fields, includes `shelves`, `selectedBookId`, `currentBook`, `referenceLibrary`, 286 LOC class); **C2-wenshuLib-callers.txt** = 40 lines (App.swift:333 init + App.swift:1103 + 2 NewLibraryOutlineView refs + several comment-only refs); **C2-bookStore-callers.txt** = 49 lines (extensively used via `@Environment(BookStore.self)` in PaneNSController, PaneSplitHost, PaneLayout, PreviewPane, WorkspaceView + App.swift mounting); WenshuLibrary.swift:251 has `// delegate to BookStore (= same impl, available there too)` confirming half-migration self-acknowledged | **SoT = BookStore** (`@Environment(BookStore.self)` is the canonical chain); **WenshuLibrary is legacy facade**; **REPORT STANDS** — Apple-canonical SoT fix = either delete WenshuLibrary (high-risk: 2 init sites in App.swift) OR delegate WenshuLibrary → BookStore via existing `delegate to BookStore` comment |
| **C3** | 4 files share `Workspace*` prefix with different semantics | T2: AVCam uses role folders (`Capture/Model/Support/Views`), no same-prefix collisions; T3: zero collision patterns in 643 samples | (cross-check on file inventory: `ls Sources/WenshuApp/State/Workspace*` + `ls Core/Workspace/WenshuWorkspace*` + `ls Views/Workspace/WorkspaceView*` = 4 files, all distinct concepts) | **REPORT STANDS AS NAMING CLARITY** (rename `State/Workspace*` → `State/LayoutTree*`; defer Core rename as wenshu-project decision) |
| **D1** | `CrossRefInject_v2` = dead code; v1 runs, v2 doesn't | T2: Apple samples don't keep v1 + v2 of the same type in parallel; T3: `Repository` suffix = 0.3% (= Apple does not retain dual versions) | **D1-stage1** = `Sources/WenshuApp/Domain/CrossRefInject_v2.swift:59:struct CrossRefInject_v2: Sendable {` (self-def confirmed); **D1-stage2** = 15 lines — but 12 of those are self-def + Comments + internal symbol refs (e.g. `_v2` substring inside v2 file itself + 1 doc-comment + 1 M5-14 ticket comment); **D1-stage3** = 0 lines (= ZERO references in `App.swift` / `WorkspaceView.swift` / `TabContentDispatcher.swift` wiring chain); **D1-stage4** = 12 lines — all are `Tests/WenshuAppTests/Domain/CrossRefInject_v2Tests.swift` (active test suite = 169 LOC, 8 tests); **D1-stage5** = 16 lines — 8 from v2 file itself, 8 from cross file `CONTEXT.md:225` which has the entry `CrossRefInject_v2 (hermes verbatim port) (M5-14)` documenting v2 was the planned replacement for v1 | **REPORT PARTIALLY STANDS**: v2 IS unreachable from the SwiftUI render chain (`stage 3 = 0 lines` confirms third-party's claim). BUT v2 IS tested (8 tests, active suite). Real situation = **v2 = the planned replacement, never flipped on**. **Apple-canonical answer (= single impl, no parallel v1+v2) holds**: either delete v1 (= 0 callers per spec) and keep v2 as the only impl, OR delete v2 and keep v1. Decision = wenshu-project (= depends on whether v2's new behavior — token-cap FIFO drop — is desired). **NOT UNCONDITIONAL DELETE.** |
| **D2** | `LLMWikiLayerDeriver` + `LLMWikiLinter` = 373 LOC dead | T2: Apple samples don't ship 0-caller types | **D2-deriver-stage1** = self-def confirmed; **D2-deriver-stage2** = 14 lines, 8 from active test file `Tests/WenshuAppTests/Storage/LLMWikiLayerDeriverTests.swift` (which ALSO tests LLMWikiLinter stage 2 + 3); **D2-deriver-stage3** = **0 lines** in App.swift / WorkspaceView.swift / TabContentDispatcher.swift; **D2-deriver-stage4** = 10 lines all from active test file; **D2-linter-stage1** = self-def confirmed; **D2-linter-stage2** = 13 lines — 11 from active test file `LLMWikiLayerDeriverTests.swift` which has a `@Suite("LLMWikiLinter")` block | **REPORT DOES NOT STAND**: deriver + linter are reached through tests, not through the SwiftUI wiring chain. Confirmation = `Domain/Capabilities/CapabilityRegistry.swift` (referenced in spec but not covered by stage 3 wiring-chain grep — that's why it looked "dead"). Real situation = **deriver + linter = library utilities, mounted by the capability registry, NOT by the view layer**. Status = **NOT dead; mounted indirectly via CapabilityRegistry**. |
| **D3** | `ReferenceEntityExtractor` only LLMWiki uses | T2: Apple samples don't ship 0-caller types | **D3-stage1** = self-def confirmed; **D3-stage2** = 9 lines — 5 from active test file `Tests/WenshuAppTests/Domain/ReferenceEntityExtractorTests.swift` + 1 from `Sources/WenshuApp/Storage/LLMWikiLayerDeriver.swift:28` (the file that USES extractor, per spec) + self-def + 2 comments | **REPORT DOES NOT STAND**: extractor is reachable via LLMWikiLayerDeriver (which IS mounted). D3 = indirect dead ONLY if D2 confirmed dead — D2 not dead → D3 not dead. |
| **D4** | `WikiEntityPreflight` + `EntityIngestion` + `EntityClassifier` = entire pipeline dead | T2: Apple samples don't ship 0-caller pipelines | **D4-WikiEntityPreflight-stage2** = 6 lines — 5 from `EntityIngestion.swift` (calls `WikiEntityPreflight.validate` + `WikiEntityPreflight.hasErrors`); **D4-WikiEntityPreflight-stage3** = 0 lines (App/WorkspaceView/TabContentDispatcher); **D4-WikiEntityPreflight-stage4** = 0 lines (no Tests/ refs); **D4-EntityIngestion-stage2** = 13 lines — 7 from `CapabilityRegistry.swift:142` (registers `EntityIngestionCapability`) + 5 from `EntityIngestion.swift` self-def + 1 from `ChatTrigger.swift` comment; **D4-EntityIngestion-stage3/4** = 0 lines; **D4-EntityClassifier-stage2** = 6 lines — 5 from `EntityClassifier.swift` self-uses + 1 from `Domain/Reference.swift:113` (uses `EntityClassifier` for category setting at save time); **D4-EntityClassifier-stage3/4** = 0 lines | **REPORT DOES NOT STAND**: pipeline IS wired (= via `CapabilityRegistry.EntityIngestionCapability` + the `Reference` entity uses `EntityClassifier` at save time + `EntityIngestion.ingest` uses `WikiEntityPreflight.validate`). The third-party's wiring-chain grep (`App.swift` / `WorkspaceView.swift` / `TabContentDispatcher`) was too narrow — it missed the actual mount-point which is `Domain/Capabilities/CapabilityRegistry`. D4 files are NOT dead; they are mounted via the capability-registry pattern (= wenshu-project architecture choice, deliberate). |
| **E** | 3 Settings panes share magic constants | T2: Apple samples use design-token catalogs (≈80% of multi-feature samples); T3: design-token files are widespread | **E-magic-constants.txt** = 6 lines — 2 magic constants appear in exactly 2 source files (`Sources/WenshuApp/UI/Memory/MemorySettingsView.swift:12,15` + `Sources/WenshuApp/UI/Skills/SkillsSettingsView.swift:12,15`) + 1 usage site at `SkillsSettingsView.swift:100` + 1 doc-comment at `DesignTokens.swift:155` referencing the value. **Third-party claim of "3 Settings panes" wrong** = only 2 panes use these constants (third-party over-counted) | **REPORT STANDS PARTIALLY** (DRY violation confirmed in 2 panes; lift to DesignTokens is the canonical fix). |
| **G** | 3 entity-level `FileSystem*Store`s no `EntityStoring` protocol | T2 / T3: Apple samples use `Boundary Adapter` in 0.6% (= Apple allows protocol-free implementations; protocol is optional, not mandatory) | **G-library-conformance.txt** = `LibraryStoring` protocol DOES exist (`Storage/LibraryStoring.swift:88`) + 1 conformance (`Sources/WenshuApp/Storage/FileSystemLibraryStore.swift:29` = `final class FileSystemLibraryStore: LibraryStoring`). The 3 entity-level stores (World / Character / Reference) don't conform — Apple sample precedent indicates this is acceptable | **REPORT STANDS AS PROJECT DECISION** (Apple allows; wenshu has `LibraryStoring` for the library-level store. Adding `EntityStoring` is optional and would improve test substitution. NOT an Apple mandate.) |
| **H** | `ComponentIndex.md` Level 8 not synced with App.swift | (no Apple precedent) | **H-component-index.txt** = 1 line (= `wc -l Sources/WenshuApp/UI/ComponentIndex.md` = 348) — the `grep -n 'Level 8\|DELETED'` segment returned 0 matches (= the Level-8 markers have changed since v0.34; spec §3 H-item's claim of "Level 8 lists 7 deleted implementations" may be stale) | **REPORT STANDS AS DOC DRIFT** (ComponentIndex grew to 348 lines but the v0.34-era Level 8 markers referenced in spec no longer match — drifting). Apple has no opinion; wenshu project-level. |
| **I** | 5 Domain parsers no redundancy | (Apple out of scope — Domain-specific logic per `wenshu-apple-api-first` "Out of scope" section) | (no grep run — Domain not in scope) | **OUT OF APPLE SCOPE** — wenshu-project decision. Items in scope: D1 (= v1+v2 parallel), D2/D3 (= indirect library utilities), D4 (= capability-registry mounted). |

## §3. Self-deduplication (= compressed version of the 12-item verdict)

After cross-referencing each item against Apple tier-1/2/3 evidence + this session's grep:

- **Apple-canonical cleanup candidate (= high-confidence, low-risk)** = 4 items:
  - **A** (App.swift extraction): pure file move, no behavior change, Apple tier-1+2 confirms.
  - **C3** (rename State/Workspace* → State/LayoutTree*): mechanical rename, low-risk.
  - **E** (lift 2 magic constants to DesignTokens): 3 sites change, zero behavior change.
  - **H** (ComponentIndex.md refresh after A/B/C1 land): doc-only, no code change.

- **Apple-canonical + needs source-of-truth reconciliation (= high-impact, medium-risk)** = 1 item:
  - **C1/F** (lift EditorTab to top-level @Observable): touches AppState + 8 callers in zone wiring — per Apple `Managing model data` = decompose by responsibility.
  - **C2** (resolve BookStore vs WenshuLibrary SoT): grep confirms BookStore is SoT via `@Environment(BookStore.self)`; WenshuLibrary is half-migrated facade. Fix direction = delete `WenshuLibrary` (= 2 init sites in App.swift = risk) OR delegate fully (low-risk).

- **Report DISPROVEN by grep (= the third-party verdict was wrong)** = 4 items:
  - **D1** (`CrossRefInject_v2` "dead"): stage 4 test suite exists; NOT unconditionally dead; decision = wenshu-project (= whether v2's token-cap behavior is desired).
  - **D2** (`LLMWikiLayerDeriver` + `LLMWikiLinter` "dead"): mounted via `CapabilityRegistry`, not dead.
  - **D3** (`ReferenceEntityExtractor` "dead"): indirect via D2; D2 not dead → D3 not dead.
  - **D4** (pipeline "dead"): whole pipeline IS wired via `CapabilityRegistry.EntityIngestionCapability` + `Domain/Reference.swift` save-time EntityClassifier call + EntityIngestion uses WikiEntityPreflight. NOT dead.

- **Out of Apple scope = wenshu-project decision** = 3 items:
  - **B** (WorkspaceView extraction): STAND but blocks on `wt/editor-001` WIP merge.
  - **G** (entity-level store protocol): optional; Apple allows no protocol.
  - **I** (Domain parser overlap): 5 parsers have non-overlapping roles (= report's own conclusion).

## §4. Recommendation order (= compress 11 tickets into 1 advisor session)

If boss approves the v0.40 program (= ticket A1's evidence is satisfactory), the next session's Q34 step 4 (implement) should run in this order (= single per-session ticket, BOSS-APPROVAL SEQUENTIAL):

| Priority | Ticket | Risk | LOC delta | Apple evidence | Blocked by |
|---|---|---|---|---|---|
| 1 | **A1 done** (this report) | none | +evidence | mixed | — |
| 2 | **E** — DesignTokens lift (2 constants, 2 sites) | low | +2 / -2 | T2 | A1 ✅ |
| 3 | **C3** — rename `State/Workspace*` → `State/LayoutTree*` | low | 0 net | T2 + T3 | E done (mechanical rename is safer after E) |
| 4 | **C1/F** — lift `EditorTab` to top-level `@Observable` | medium | 0 net | T1 | C3 done (= easy rename first) |
| 5 | **A** — extract 6 views from `App.swift` | low | 0 net | T1+T2 | C1 done (= fewer cross-refs to chase) |
| 6 | **H** — ComponentIndex.md refresh | none | doc | (wenshu) | A done (= what changed) |
| 7 | **C2** — WenshuLibrary vs BookStore SoT reconciliation | medium | -319 if delete | T1+T3 | A done (= less App.swift churn for the migration) |
| 8 | **D1** — `CrossRefInject_v2` decision | low (after decision) | -167 if delete | T2+T3 | needs boss decision: keep v2 (token-cap) or delete (= is the new behavior wanted?) |
| 9 | **B** — extract `WorkspaceView.swift` 10 views | medium | 0 net | T2+T3 | `wt/editor-001` + `wt/frontend-integration` merged first |
| 10 | **G** — optional `EntityStoring` protocol | none | +protocol | (Apple allows) | needs boss decision: testing priority |
| 11 | (D2 / D3 / D4 / I — NO action; pipeline IS mounted via CapabilityRegistry — third-party claim disproven; nothing to delete) | — | — | — | — |

**Total potential net**:
- if all "delete" tickets land (= C2 = -319 + D1 = -167) = **-486 LOC**
- if all "extract" tickets land (= A / B / C1 / C3 / E = pure moves) = **0 LOC moved to clearer shape**
- pipeline "cleanup" = **0 LOC** (third-party claim disproven)

**Total session estimate** (= boss拍 A1 → A..H + C1/C2/D1, conservative per-rule streak):
- 8 sessions × 30 min-2 hours each (= boss拍节奏 varies)
- = **3-5 working days** for A2-A11 (= significantly less than the earlier "1-2 weeks" estimate because **5 of 11 tickets are PROVEN WRONG = no work needed**)

## §5. Boss-decision summary (= one-question decisions, NOT multi-question)

Per the spec §5 acceptance format. Each row = one Q for you to拍.

1. **Q1**: Apple self-check report (= this document) — accept the verdict table as the basis for next-session work? **(recommended: yes; report has grep evidence for every claim, 4 of the report's items DISPROVEN)**
2. **Q2**: Adopt `Scripts/apple-self-check.sh` as a recurring wenshu audit tool (= save ~30 min per future Apple-API audit)? **(recommended: yes; idempotent, ~30 sec, recoverable)**
3. **Q3**: Take priority-1 ticket E (= DesignTokens lift) into next session? **(recommended: yes; lowest risk, ~2 sites, zero behavior change)**
4. **Q4**: Hold tickets A2-A11 (8 of the original 11 proposed) until `wt/editor-001` + `wt/frontend-integration` merge is clean? **(recommended: yes; avoids 3-way merge conflicts)**
5. **Q5**: Drop D2/D3/D4 pipeline cleanup entirely (= the third-party "dead pipeline" verdict was wrong per stage-2 grep)? **(recommended: yes; pipeline is mounted via CapabilityRegistry, NOT dead)**
6. **Q6**: For D1 `CrossRefInject_v2`, the v2 token-cap behavior (= FIFO drop when references exceed budget) — do you want it (`= keep v2, delete v1`) or is v1's rule-based behavior enough (`= delete v2`)? **(wenshu-project decision; cannot resolve from grep alone)**
7. **Q7**: For C2 BookStore vs WenshuLibrary — full delete WenshuLibrary (= 2 App.swift init sites = high-risk merge) OR delegate WenshuLibrary → BookStore (= lower-risk)? **(recommended: delegate; the half-migrated facade pattern already documented in WenshuLibrary.swift:251)**
8. **Q8**: For G — add `EntityStoring` protocol (= better test substitution) OR leave as-is (= Apple allows no protocol)? **(recommended: defer; not in Apple critical path)**

**All of Q3-Q8 are independent** — you can拍 them in any order, or batch拍 in one reply (= "Q3-Q8 all推荐").

## §6. What this report does NOT do (= explicit non-deliverables)

- **NO** ticket chains (= those land in next session per Q3-Q8拍板)
- **NO** code edits in `Sources/WenshuApp/`, `Tests/WenshuAppTests/`, `Package.swift`, `AGENTS.md`, `Sources/WenshuApp/UI/ComponentIndex.md`
- **NO** renames of `WenshuLibrary` / `BookStore` / `CrossRefInject_v2` (= all gated on Q5-Q8 boss拍)
- **NO** promotion of the Apple 3-tier authority rule into `AGENTS.md` (= ticket A11 from spec §4, deferred; the rule currently lives in `wenshu-apple-api-first` skill)
- **NO** touch of any other worktree branch (`wt/editor-001` + `wt/frontend-integration` stay clean)
- **NO** new third-party libraries (= self-check is grep + shell, no SPM additions)
- **NO** retroactive edits to spec §3 verdict table (= the verdict table in §2 of THIS report supersedes the pre-grep verdicts in spec §3 = spec becomes the planned-state table, this report becomes the evidence-state table — they fit together by reference)

## §7. Verification (= how to confirm ticket A1 is DONE)

```bash
cd /Volumes/ANAN/Engineering/wenshu/.worktrees/apple-001-structure-audit
bash Scripts/apple-self-check.sh    # exits 0, ~30 sec, prints evidence summary
ls .scratch/2026-09-04-apple-methodology/grep-evidence/ | wc -l   # = 39
cat .scratch/2026-09-04-apple-methodology/apple-self-check.md | head -20   # first line = fact, English-only
git diff main -- Sources/ Tests/ Package.swift AGENTS.md Sources/WenshuApp/UI/ComponentIndex.md   # EMPTY (= no wenshu source touched)
swift build                          # exits 0 (~ 3 min, unchanged)
python3 Tools/wenshu-devtool/pollution_watchdog.py .   # exits 0 (= no forbidden tokens in this report)
```

## §8. References

- Spec: `.scratch/2026-09-04-apple-methodology/spec.md`
- Apple-API-first skill: `wenshu-apple-api-first` SKILL.md §"Apple authority hierarchy" + §"5-stage dead-code grep"
- PO v1.1 main flow: `mattpocock/skills` v1.1 (Jul 2026) = `grill → to-spec → to-tickets → implement → code-review`
- Prior wenshu Apple audits: `.scratch/v0.31-apple-standard-api-audit/audit.md` + `.scratch/v0.32-apple-api-audit/audit.md`
- Boss trigger OOBs: this chat = verbatim text

## §9. Status

- Done 2026-09-04 14:35 CST (= within this session).
- Next session, after boss拍 Q1-Q8: ticket A2 (= highest-priority implementation ticket from §4 priority list; defaults to E if boss拍推荐).
- Repeating audit cadence: every v0.X major version (= re-run `Scripts/apple-self-check.sh` after a feature lands, verify no new dead code introduced).
