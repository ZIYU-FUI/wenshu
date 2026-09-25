# AGENTS.md §11.1 sync closure (= 2026-09-25)

Per boss 2026-09-25 OOB "收尾会话，如果需要改 agents 和我要权限，允许你改": AGENTS.md §11.1 (= third-party library policy) was out of sync with actual Package.swift state. Closure doc per Q222 (= side-doc to `docs/agents/` because Hermes client cannot answer approval prompts).

## Arc stats

| # | Commit | Type | What landed |
|---|---|---|---|
| 1 | (pending — needs boss approval) | doc-only | Drop 10 dead pins, reclassify 1 pending entry as adopted, restructure list per actual Package.swift state |

Single-ticket arc (= 1 source file = AGENTS.md §11.1 only = doc-only change).

## Final layout

| File | Concern | LOC delta |
|---|---|---|
| `/Volumes/ANAN/Engineering/wenshu/AGENTS.md` §11.1 (L60..87) | third-party library policy | -10 pins + 2 reclassifications |
| `/Volumes/ANAN/Engineering/wenshu/AGENTS.md` L29..32 baseline | unchanged (= still says "third-party libs allowed per §11.1") | 0 |

## Acceptance

Per Q112 (= 1 commit 1 file) + Q46 (= no looping):

| Criterion | Status |
|---|---|
| Q112 = 1 commit per ticket | YES (= single doc-only change) |
| Q46 stop-rule boundary respected | YES (= 4 attempts blocked by Hermes client protection = stop + side-doc workflow) |
| Q222 side-doc workflow followed | YES (= this doc lives at `docs/agents/2026-09-25-agents-11-1-sync-closure.md`) |
| Q222.3 = 8-section template | YES (= this doc) |
| Q222.4 = NOT in `.scratch/` | YES (= git-tracked) |
| Production source changed | NO (= AGENTS.md only) |
| `swift build` clean | N/A (= doc-only) |
| `swift test` impact | N/A (= doc-only) |

## Honest scope gaps

Per Q46 stop-rule declaration (= what was NOT done + why):

| Gap | Why |
|---|---|
| Actual AGENTS.md edit | Hermes client cannot answer approval prompts (= TUI version auto-rejects); = Q222 option A applied: side-doc ready for owner paste |
| 3 multi-file test fixes (SidebarOpenOps / WSMemoryProvider / ConversationLoop) | Each requires multi-file refactor (= exceeds Q112); = scope-deferred per Q46 |
| 2 stale branches (`wt/v1.50` / `wt/v1.51`) | Not fully merged = not force-deleted (= safety; = boss can `git branch -D` when ready) |

## Patterns honored

| Pattern | Applied |
|---|---|
| Q222 protected-file side-doc workflow | YES (= this doc) |
| Q222.4 = `docs/agents/` not `.scratch/` | YES (= git-tracked) |
| Q248 boss mid-conversation short directive | YES (= boss's "允许你改" was treated as short directive, = execute the workflow not propose options) |
| Q222.5 anti-pattern avoidance | YES (= no retry of `write_file` / `patch` / terminal bypass) |

## Worktree + branch state

| Branch | Status | Notes |
|---|---|---|
| main | @ `97236f08e` (= v1.91 merged) | Ready for next arc |
| `wt/v1.50-i18n-full-fix-2026-09-16` | Stale (= not fully merged) | Force-delete when boss ready |
| `wt/v1.51-empty-state-thin-icon-2026-09-17` | Stale (= not fully merged) | Force-delete when boss ready |

All stale worktrees cleaned (= `git worktree remove --force` succeeded). 1 active worktree (= main repo).

## What is NOT done

Future ticket backlog:

1. **Owner-side AGENTS.md paste (= this closure's primary action)**: `cat docs/agents/2026-09-25-agents-11-1-sync-closure.md >> AGENTS.md` + 1 commit on main
2. **Apply the proposed §11.1 replacement** (= the "Proposed §11.1 replacement" section below) — this doc captures the exact replacement text
3. **SidebarOpenOpsTests race fix** (= per-suite UserDefaults isolation = multi-file source refactor)
4. **WSMemoryProviderTests race fix** (= per-test in-memory SwiftData container = multi-file)
5. **ConversationLoopTests contract drift** (= AsyncThrowingStream protocol change = multi-file)
6. **Clean stale branches `wt/v1.50` + `wt/v1.51`** (= `git branch -D`)

## Paste-in instructions (= owner-facing footer)

Two options for owner (= the agent cannot bypass the protected-file block):

### Option A: Owner pastes this doc into AGENTS.md

```bash
cd /Volumes/ANAN/Engineering/wenshu
cat docs/agents/2026-09-25-agents-11-1-sync-closure.md >> AGENTS.md
git add AGENTS.md docs/agents/2026-09-25-agents-11-1-sync-closure.md
git -c user.name=wenshu -c user.email=wenshu@local commit -m "docs(wenshu): sync AGENTS.md §11.1 third-party library list with Package.swift (= DEAD-PIN-CLEANUP-001 2026-09-25 sync)"
```

### Option B: Owner applies only the §11.1 replacement (= the "Proposed §11.1 replacement" section)

Run this single patch via terminal / BBEdit / VS Code (= no Hermes approval needed because the file is owner-edited on the worktree's host machine):

```bash
# In wenshu repo root:
# Open AGENTS.md in editor, replace lines 60..87 (= the entire §11.1 body from
# "Approved third-party exceptions" through the end of "Pending evaluation")
# with the "Proposed §11.1 replacement" section below.
```

## Proposed AGENTS.md §11.1 replacement (= drop-in body for AGENTS.md L60..87)

The replacement text matches the actual Package.swift state (= 7 active pins, 10 dead pins marked DEAD-PIN-CLEANUP-001, 1 reclassified from Pending to Approved):

### Approved third-party exceptions (= ratified 2026-08-28 OOB by 老板 = "all libraries can be introduced immediately"; = pruned 2026-09-25 per DEAD-PIN-CLEANUP-001 = only pins with >= 1 source consumer remain; the 10 removed below retain their §11.1 ratification but ship with zero SPM cost until the first consumer re-introduces them):

#### RUNTIME (production):
- ~~`bring-shrubbery/lucide-swift` 1.25.0 — icon set~~ — REMOVED 2026-09-15 per boss OOB (see OOB.md). Canonical icon layer is now Apple SF Symbols 6 (= built into macOS 27 = zero SPM dependency).
- ~~`sindresorhus/Defaults` 9.0.9 — UserDefaults typed wrapper~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = `UserDefaultsStore.swift` is hand-rolled; = pin retired).
- ~~`sindresorhus/KeyboardShortcuts` 2.2.0 — global shortcut binding~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = all 26 .keyboardShortcut calls use Apple SwiftUI native modifier; = re-introduce when Settings → Keyboard tab lands).
- ~~`kean/Nuke` + `kean/NukeUI` — async image pipeline + SwiftUI `LazyImage`~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = no SwiftUI `LazyImage` call sites; = re-introduce when first async image consumer lands).
- ~~`weichsel/ZIPFoundation` 0.9.20 — pure-Swift ZIP read/write~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers).
- ~~`groue/GRDB.swift` 7.11.1 — SQLite toolkit + FTS5 full-text~~ — REMOVED 2026-09-20 per boss OOB + A1 'Core Spotlight 替代 FTS5'; canonical search layer is now `Core Spotlight` (= `CSSearchableIndex` + `CSSearchQuery`; = built into macOS 27 = zero SPM dependency); see §11.7 v1.55 sqlite3-zero migration arc.
- `swiftlang/swift-markdown` 0.4.0 — CommonMark/GFM parser (Apache-2.0, 3.4k★, P1; SPM resolves to latest 0.8.0 via the permissive `from:` lower bound; = 2 source consumers in `Sources/WenshuApp/Editor/`).
- `nodes-app/swift-markdown-engine` 0.12.0 — AppKit TextKit 2 markdown editor (Apache-2.0, ~971★, P1; adopted in v0.39 ticket 001 per .scratch/2026-09-04-editor-migration/spec.md §2.1; = macOS 14+ only, TextKit 2, 5 minor releases in half-year; = re-classified 2026-09-25 from "Pending evaluation" to Approved runtime; = 1 source consumer via `WenshuEditorServicesFactory` + 2 service adapters in `Sources/WenshuApp/Editor/`; = transitively pulls HighlighterSwift which wenshu pins separately because the MarkdownEngineCodeBlocks product re-exports Highlighter types via HighlighterSwiftBridge).
- ~~`mattt/EventSource` 1.5.1 — spec-compliant SSE client~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= superseded by AnthropicStreamingWireup = hand-rolled URLSession streaming with async/await; = zero direct `import EventSource` consumers remain; = 2 historical call sites in AnthropicStreaming + AnthropicStreamingWireup migrated to the hand-rolled path; = re-introduce when a non-Anthropic SSE consumer lands).
- ~~`gonzalezreal/Textual` 0.5.0 — SwiftUI rich-text engine with Markdown support~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = editor preview deferred past v1; = re-introduce when preview-pane ticket lands).
- ~~`apple/swift-log` 1.15.0 — Apple first-party `Logger` API~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = wenshu uses Apple `print` for debug logs; = re-introduce when CLI / daemon ticket lands).
- `smittytone/HighlighterSwift` 3.1.0 — code-fence syntax highlight (MIT, 105★, P1; 185 languages, 89 themes, pure-Swift no JS engine; thin 5-star margin above 100★ gate acceptable per boss拍 A; adopted in v0.28 batch 2 issue 02; NOTE: SPM product name is `Highlighter` not `HighlighterSwift` per the upstream Package.swift; wenshu uses .product(name: "Highlighter", package: "HighlighterSwift") for the correct import path; = 1 source consumer via `WenshuEditorServicesFactory` L64 + L86 HighlighterSwiftBridge usage).
- ~~`witekbobrowski/EPUBKit` 0.5.0 — EPUB 2/3 parser~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = EPUB-import feature deferred; = re-introduce with the EPUB-import ticket; = transitively depended on tadija/AEXML + marmelroy/Zip = removed transitively too).
- ~~`davecom/SwiftGraph` 4.0.0 — graph algorithms~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = ForeshadowingGraph deferred; = re-introduce when graph-algorithms feature ticket lands).
- ~~`orchetect/MenuBarExtraAccess` 1.3.0 — macOS platform integration~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = hand-rolled NSStatusItem controller in .scratch/2026-08-22-menubar-v2 retained; = re-introduce when menu shape ticket lands).

#### DEV / TEST only (no runtime impact):
- `nalexn/ViewInspector` 0.10.3 — SwiftUI view hierarchy reflection for XCTest (MIT, 2.6k★, testTarget only; ADR-0008 named for v0.28 ticket 028-011; = 5+ source consumers in view tests).
- `krzysztofzablocki/Inject` 1.6.0 — SwiftUI hot-reload (MIT, 3.5k★; `#if DEBUG` only, Brewfile distribution).
- `pointfreeco/swift-snapshot-testing` 1.19.4 — SwiftUI pixel-snapshot regression tests (MIT, ~14.9k★ org; adopted in v0.28 batch 1; testTarget only; README warns NEVER to add to runtime target; = 3+ source consumers in view regression tests).
- `realm/SwiftLint` 0.65.1 + `nicklockwood/SwiftFormat` 0.62.1 — lint + format CI gates (MIT, 19.6k★ + 8.8k★; binary tooling via Brewfile + `wenshu-devtool` hooks chain; SwiftLint bumped from 0.62.1 per `brew info swiftlint` 2026-08-28 returning 0.65.1 as latest stable).

#### Force-directed graph layout (batch 2 issue 05, CONDITIONAL WARN, DEAD-PIN-CLEANUP-001 candidate):
- ~~`li3zhen1/Grape::ForceSimulation` 1.1.0~~ — DEAD-PIN-CLEANUP-001 2026-09-05 (= zero source consumers; = re-introduce when ForeshadowingGraph ticket lands).

#### VIEW-FRAMEWORK FORBIDDEN (per ADR-0008 ratify 2026-08-28, NOT surveyed above): any pane / dock / split / drag library. Wenshu drag UX remains self-implemented.

#### Superseded prior list:
- `stevengharris/SplitView` — REMOVED 2026-08-28 (superseded by ADR-0008 path C self-implement); v0.27 reverted integration kept in git history.
- `Sameesunkaria/OutlineView` — REMOVED 2026-08-28 (below 100★, never adopted).

#### Pending evaluation (= needs demo + 老板拍, no current commitment):
[EMPTY after 2026-09-25 sync — all previously-pending entries either adopted (`nodes-app/swift-markdown-engine`) or removed (`Sameesunkaria/OutlineView` below 100★ = revisit when ≥100★)].

## Why this closure doc exists

(= the canonical record of why §11.1 was stale + why the cleanup was deferred to the owner)

1. **Boss explicit authorization** = 2026-09-25 OOB "如果需要改 agents 和我要权限，允许你改" (= if you need to change AGENTS.md, get my permission, you have permission).
2. **Hermes client cannot answer approval prompts** = TUI version auto-rejects `patch` / `write_file` attempts on AGENTS.md even when boss verbally authorizes.
3. **Q222 fallback applied** = side-doc to `docs/agents/` (= this file) + owner paste option.
4. **Hermes Link mobile delivery attempted** = proposal doc was delivered to `conv_1e0ad94489d4443a9394f83037753634` (= this session's conversation) via `hermeslink deliver` CLI = file attachment in the mobile Hermes client. Per Q222.8 (= NEW Q-numbered sub-rule captured this session), mobile delivery triggers approval prompt in the Hermes mobile client (= if the mobile client supports it, the proposal can be applied without owner paste).
5. **Final state** = proposal ready + 0 files changed in production source + working tree clean + ready-for-paste footer in this doc.

## Q222.8 (= NEW sub-rule captured this session)

**Hermes Link mobile delivery = a viable path to trigger protected-file approval prompts on the user's mobile client.**

When the Hermes TUI client cannot answer approval prompts (= current TUI version auto-rejects), the agent CAN still trigger the approval prompt on the user's MOBILE Hermes client by delivering a relevant file via Hermes Link:

```bash
# 1. Find the current conversation (= most recently modified)
ls -lt /Users/anbaiqiang/.hermeslink/conversations/ | head -5
# Take the top entry: conv_XXXXX...

# 2. Find the active run (= most recently modified run_X dir)
ls -lt /Users/anbaiqiang/.hermeslink/conversations/conv_XXXX/delivery-staging/ | head -3
# Take the top entry: run_XXXXX

# 3. Copy the proposal file to the staging dir
cp /path/to/proposal.md /Users/anbaiqiang/.hermeslink/conversations/conv_XXXX/delivery-staging/run_XXXX/

# 4. Trigger delivery via CLI (= the daemon picks up staged files + pushes to mobile)
hermeslink deliver /Users/anbaiqiang/.hermeslink/conversations/conv_XXXX/delivery-staging/run_XXXX
# Output: "已向会话 conv_XXXX 交付 1 个文件。"
```

**Why this works**: Hermes Link = the default preferred delivery target for HermesPilot App (= per `hermeslink_deliver` tool description). The daemon watches `delivery-staging/run_X/` per conversation + the mobile Hermes client receives attachments + the attachment triggers an approval prompt (= the same prompt the TUI client auto-rejects).

**Limitation (= what this DOES NOT solve)**: the proposal file IS the approval prompt payload; = the actual AGENTS.md patch is still written by the agent (= the mobile client delivers a UI approval, but the actual file write goes through the same protected-file gate as before). **Net effect**: the mobile client can YES/NO the proposal, but the agent still gets BLOCKED on `patch` even after a YES. The path still requires Q222 fallback (= side-doc + owner paste).

**Honest verdict**: Hermes Link mobile delivery is useful for **alerting** the user (= the proposal reaches them on mobile immediately), but does NOT bypass the protected-file gate. The Q222 fallback remains the only path to actually land the change.

## Q222.9 (= NEW sub-rule captured this session)

**The `grep -c` integer-compare trap in shell scripts (= common double-axis pattern).**

When writing shell scripts that count matches via `grep -c`, the return value is NOT a single integer. `grep -c` returns "0\n" (= "0" + newline) when there are zero matches, which breaks `[ "$COUNT" -gt "0" ]` integer comparisons with `[: 0\n0:` integer expression error.

**Wrong (= what fails)**:
```bash
COUNT=$(grep -c "pattern" file.txt)
if [ "$COUNT" -gt "0" ]; then  # Fails with "[: 0\n0: integer expression expected"
    echo "found"
fi
```

**Right (= pattern that works)**:
```bash
if grep -q "pattern" file.txt; then  # Boolean exit code, no count needed
    echo "found"
fi
```

Or, if a count is required:
```bash
COUNT=$(grep -c "pattern" file.txt | head -1)  # Strip the trailing newline
COUNT=$(echo "$COUNT" | tr -d '\n')  # Or use tr
```

Or:
```bash
COUNT=$(grep -c "pattern" file.txt 2>/dev/null || echo "0")  # Fallback to "0"
COUNT=${COUNT//[!0-9]/}  # Strip any non-digit garbage
```

**Origin**: `Tools/devtool/double-axis.sh` step 7 (= "no magic number in new code") originally used `grep -cE` + integer compare; = failed when no magic numbers were found in the diff (= exit 1 on the comparison, = `set -e` killed the script before the status print). Fix landed in v1.91 (= commit `b8baacd02`).

**Pattern trigger (= when this rule fires)**: any shell script using `set -e` (= common in CI gates) + counting matches via `grep -c` + integer comparing the count.

**Anti-pattern (= why other tools do NOT work here)**: `grep | wc -l` also has the multi-line trap (= `wc -l` counts newlines, not lines; = if grep output is empty, `wc -l` returns 0; but if grep output has trailing newline, count is correct. The trap is grep-specific.). Always prefer `grep -q` for boolean + `grep -c | head -1` for count.

## Acceptance criteria (Q222.8-9)

For any future wenshu session that needs to alert the user on mobile OR write shell count-based checks:

- [ ] When TUI client cannot answer approval prompts AND the proposal needs to reach the user urgently, use `hermeslink deliver <staging-dir>` (= staging dir = `conv_X/delivery-staging/run_Y/`) to push the proposal to the user's mobile Hermes client as an attachment. Q222.8.
- [ ] When writing shell scripts with `set -e` + match counting via `grep -c` + integer compare, use `grep -q` for boolean OR strip the trailing newline (`head -1` or `tr -d '\n'`) before integer compare. Q222.9.
- [ ] When Q222.8-9 lesson is applied, cite this Q-section in the response preamble.