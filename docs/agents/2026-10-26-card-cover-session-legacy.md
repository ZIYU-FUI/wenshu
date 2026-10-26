# The card-cover session's legacy, closed out (2026-10-26)

The session titled "card cover" (`20261022_213545_3a3e7c`, 2026-10-22 21:35 →
2026-10-24 16:27) ended without a wrap-up: its last message was a report that a
final verification command had been stopped by the safety gateway, and it said
so (= the work it left for whoever came next). This document is that next
handoff, done.

## 1. What the session actually left

**Its own eight board cards: all done, all merged into `main`.**

| Card | Root cause | Commit |
|---|---|---|
| `t_19c76f93` | the registry built heavy singletons at registration time, after the main actor | `ff51cc2617` |
| `t_f06a66e8` | the index decoded ISO 8601 only; legacy files wrote `Date` as a Double | `e31c04a192` |
| `t_80d05a7e` | source-text assertions pointed at files that no longer hold the literal | `4d1ca31a51` (+ `adc38eb029`) |
| `t_58e0967a` | the probe resolved the app by path; LaunchServices resolves by bundle id | `fc068319bd` |
| `t_216c9941` | the inspector's toggle named its SF Symbol "sidebar-right" | merged |
| `t_f343f556` | the sidebar test read source files that no longer exist | merged |
| `t_6ba9e4ec` | the chat stream buffer's flush task held the lock across its sleep | merged |
| `t_5bd3c4d0` | the Gemini connector decoded the old `tool_use.input` shape | merged |

The cover feature itself is on `main` (the protocol layer, the settings pane,
the plant-growth rule, the strict constraints, the failure message, the split
still/clip states). Every `project/*cover*` branch is `ahead=0` against `main`.

**The one thing it left open: the final full-suite number.** Its last trusted
number was 38 issues, and it could not confirm the count after the last three
fixes landed. It also listed the remaining failures per file in a comment on
`t_80d05a7e`.

## 2. The number, measured (2026-10-26, `main` = `d4cd276834`)

A single-arm `swift test` on a clean worktree of `main`, no other test run
concurrent: **29 recorded issues**, of which 4 are an artefact of where the
run happened (see §3) → **25 real failures**, spread over 16 test files. (The
counts differ because a few tests assert more than once: three of them fail
at two or three lines each.)

`swift test --skip-update` is required on this machine: the default
resolution hangs on the ssh fetch through the local proxy, and every
dependency is already resolved in the main tree's `.build`.

For comparison: the 2026-10-26 import-chain session measured the untouched
baseline `15901058d` at 30 failures and its own tree at 12, with 0 new. The
counts are not directly comparable (different trees, different days), but both
show the tree is not red.

## 3. The four failures that are not the tree's fault

`FileToolsTests` builds its temp paths from `FileManager.currentDirectoryPath`.
A worktree under `~/.hermes/profiles/.../scratch/...` matches the deny-list
prefix, so the path guard refuses the write: `Caught error: .pathDenied(path:
".../ws-verify-1013/.test-...")`. The four affected tests are the write/read
round-trip, the single-replacement patch, the patch-with-missing-old-text,
and the pattern search (= all four live in `FileToolsTests.swift`).
**Run the suite from a path the deny-list does not cover** before reading them
as failures.

## 4. The session's failure list, re-judged today

The list it left on `t_80d05a7e` named ten groups. Each is either gone or
still there:

| Group | Today |
|---|---|
| `AccentTintOpacitySweepTests` | fixed |
| `SidebarIconUniformityTests` | fixed |
| `FrameMagicSweepTests` (2) | **still failing** |
| `SidebarItemTagPreviewFilterTests` (2) | **still failing** |
| `LLMWikiPipelineWireTests` | fixed (the assertion was reversed on purpose) |
| `DeadDesignTokensSweepTests` (the three font tokens) | fixed |
| `DeadDesignTokensSweepTests` (raw RGB literals) | **still failing** |
| `IconStylesTests` (the `.sidebar` case) | fixed |
| `EditorStatusBarView` (3) / `EditorTabStrip` (1) | **still failing** |
| the `Library/View` batch (displayTitle 3, previewPane 2, `sidebar_service_reference_library_expands_to_category_rows`, `editor_and_chat_zones_use_EmptyStateView`, `WenshuEditorServicesFactory forwards EditorPreferences`, `ShellMiddleColumn sets workspaceUI.activeTag`, `SidebarRowView` 2) | **still failing** |
| the tool-registration tail (2) | **still failing** |
| `TodoStoreTool.execute() returns in under 5 seconds` | **still failing** |
| `prefetch returns empty when no memories match` | fixed |
| `ChatView's wired conductor reads its tools dict` | fixed |
| the test that calls itself `OBSOLETE per commit 140b76deb` | no longer a failure (its body is an `Issue.record` now) |

**The two items it proposed as separate cards are still not cards**, and one
of them is now a failure again:

- the `displayTitle` / `previewPane` / `prefetch` cluster — three
  `displayTitle_*` and two `previewPane_*` tests are failing today
  (`EditorTabTitleTests.swift`, `AppleSidebarMVVMSplitTests.swift`);
- the `OBSOLETE` e2e test — it is an `Issue.record`, so it does not fail the
  suite, but it is still in the tree and still wants deleting or an xfail.

## 4a. The 25 are NOT one problem (= do not put them on one card)

They fall into three kinds, and the kind decides what the fix is:

**(a) A stale source-text assertion (= the file moved, the literal did not).**
The assertion names a string in a file that no longer holds it. The fix is to
point it at the file that does, or to invert it when the behaviour is gone on
purpose. **19 of the 25** are in this class:
`AppleSidebarMVVMSplitTests` (3), `EditorTabTitleTests` (3),
`WenshuMarkdownEditorAdapterTests` (3), `SidebarRowViewIconMigrationTests`
(2), `FrameMagicSweepTests` (2), `SidebarItemTagPreviewFilterTests` (2),
`EditorViewIconMigrationTests` (1), `ColorSweepArcClosureTests` (1),
`EmptyStateViewCallersTests` (1), `ChatViewHistoryShortcutTests` (1).
`ColorSweepArcClosureTests` is the one that still names a real offender:
`PreviewPaneCard.swift` holds a raw `Color(red:green:blue:)` literal.

**(b) A load symptom (= the test is right, the machine was busy).**
`ToolRegistryProductionTriggerTests` reports 19 catalogue tools that "never
registered through the production trigger". The probe polls for up to 5 s
because "a fixed sleep tuned for an idle run loses the race under load" (= its
own header comment). This is the known symptom of a concurrent run, not a
broken install hook. `TriggerClosureWiringTests` is the same shape: it wants
at least one default-name handler to be reachable.

**(c) A real defect (= fix the product, not the test).** Two of these, and
they are the ones worth a card of their own:

- `ConversationLoopMultiTurnTests`: the loop made **zero** LLM calls
  (`expected 2 LLM calls (= loop must iterate on toolUse); got 0`) and the
  test took 56 s to fail. The connector is a stub (= no key needed), so this
  is not the environment: the turn never reached the model.
- `HermesTodoStoreConcurrencyTests`: `TodoStoreTool.execute()` took more than
  the 5 s budget. This is the regression test for a real deadlock
  (`VERIFY-INTEGRATION-001`).

Two more are `Issue.record` bodies that document a deleted behaviour
(`LLMConnectorStreamTests`, `WenshuConductorE2ETests`): they do not fail the
suite, but they want deleting or an xfail.

## 5. What is NOT this session's legacy

Two cards that look related are not:

- `t_c3850b57` (a cover cascade on delete) and `t_e4f1c60d` (the novel-side
  context) belong to the **2026-10-24 "unfinished work audit" session**
  (`20261024_131806_f8e785`), not to the cover session. `t_c3850b57`'s
  premise ("three orphan `bookDoc` cover directories on disk") is false: all
  three keys map onto documents that still exist. It is still running.
- `t_90b9ba08` and the other two cards the audit session opened are its own.

## 6. The tree state

`main` is clean. The session's own worktrees are gone (their branches were
merged or deleted). The `marker-card` branch is a duplicate (its content is
on `main`) and was not merged; `probe-strips` was a throwaway measurement
probe and was correctly not merged.
