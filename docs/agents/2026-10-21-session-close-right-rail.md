# Session close — 2026-10-21 — right-rail removal, then the rail shell restored

> Boss directives 2026-10-21 (rendered in English per rule 1.1): "the right rail's UI was not
> deleted" and "the persisted key is gone" (= the first screenshot, with the right rail boxed in
> red), then "did you merge your code, I still see those tabs", then "the right rail stays, but
> the features already deleted from it do not come back", then "close out your session".
> Session: `20261020_112058_62887e` (this one, TUI). Parallel sessions on the same repo:
> `20261021_092934_6c914f`, `20261021_125040_6f973f`, `20261021_125242_b4261f`.
> Closure type: 3 code tickets (3 commits) + this closure doc (1 commit).

## 1. What this session did

| # | Ticket | Commit | Repo impact |
|---|--------|--------|-------------|
| 1 | Remove the right rail: the container, its 5 pages, its 15 tool surfaces, their agent tools, their persistence, and their tests | `e4ffec568` | 154 files, 24,940 lines removed |
| 2 | Stop two tests from leaking shared state | `37fa613e7` | 2 files |
| 3 | Restore the right rail as an empty shell (= the boss's reversal) | `2fc01753f` | 5 files, 277 insertions |
| 4 | Keep the app bundle's compiled catalog in sync with the module bundle | `106d1c100` | 1 file |

## 2. Ticket 1 (= the right-rail removal)

Business: the right rail carried 15 planning surfaces (foreshadowing, placeholders, plot
threads, long-form guardrails, reader experience, genre fit, character relationships,
character lifecycle, emotion curve, idea library, tag manager, book-setting constraints,
bookmarks, background review, and the editor document tools) whose agents, persistence, and
tests were all still in the tree. The boss chose to remove the whole closure, UI + agent
tools + persistence together, including `BookProjectConfigStore` and `WSBookmarkRepository`.

Removed: the rail container + 4 editor document-tool sub-views, the 15 tool views + their
ops + their view-state mirrors, the 12 matching agent-tool files, the SwiftData bookmark
model + its repository + its schema entries, the archivist's bookmark commands, and the
dedicated tests. The command palette moved from the rail to the window's top toolbar
(= the top toolbar is the single source of truth for the window's toolbar buttons).

Verified: `swift build --build-tests` clean; 3 consecutive full-suite runs with **0 new
failing tests** against a same-environment baseline of 67 issues; the authoritative
dead-type scan reports 0 production types with no reference.

## 3. Ticket 2 (= two shared-state leaks)

Neither leak was caused by ticket 1, but both turned the suite red and both were real
defects:

- `UnsignedKeychainPromptTests` wrote `wenshu.debugNoKeychain` into the **persistent**
  `swiftpm-testing-helper` UserDefaults domain and restored it with `set(false)`, so the
  key stayed present forever. The flag stuck ON and every later run of the signed-build
  assertion failed. The test now captures whether the key existed at all and restores that
  exactly, and the signed-build assertion clears the flag for its own duration.
- `WenshuReplicatedKanbanEndToEndTests` asserted that the kanban list contains no `[done]`
  row anywhere, but the in-memory store is process-wide (= sibling suites write into the
  same warehouse container). The assertion is now scoped to the row the test created.

## 4. Ticket 3 (= the rail shell restored)

Business: the boss's call is that the right rail stays and the features deleted from it do
not come back. So the column is back as a shell: the 4 page icons + the visibility toggle
in the window toolbar, the active page's title in the column body, and the shared
`EmptyStateView` in a page that owns no tool yet. The Format page (= the editor document
tools) stays gone with its feature. The command palette button stays in the top toolbar.

Ran as board card `t_c4d571c2` on the `wenshu-par` board per rule 1.12. The worker burned
its 30-minute runtime on reasoning and wrote no file, so the card was reclaimed and the
change was finished in the card's own worktree and fast-forwarded to main (= one commit
per ticket, no merge commit).

## 5. Ticket 4 (= the app bundle's stale catalog)

The app bundle carries the compiled catalog twice: at `Contents/Resources/<locale>.lproj/`
and inside the SPM module bundle. `Bundle.main` wins the lookup, so the app-level copy
shadowed the module bundle's copy, and every string added to the catalog after that copy
was made rendered as its raw key. The bundle step now refreshes the app-level copy. The
compiled `.strings` is UTF-16, so a byte-level grep for a key always misses.

## 6. Verification

| Measure | Baseline (pre-ticket) | Delivered tree (`106d1c100`) |
|---------|------------------------|-------------------------------|
| Full-suite issues | 67 | 57 |
| Failing tests | 47 | 39 |
| New failing tests vs baseline | — | **0** |
| Production types with no reference | 0 | 0 |

The persisted provider key was proven live with the app's own code in a normal process
(`ProviderKeychain.listProvidersWithKeys()` returns both configured providers; the backend
resolves to the file store; the key is present). The earlier "no agent configured" line in
the chat was a restored transcript entry from a session launched with
`WENSHU_DEBUG_INMEMORY_KEYCHAIN=1`, which forces the in-memory keychain.

## 7. The environment fact that cost this session its work three times

**The shared checkout is not a safe place to hold uncommitted work while other Hermes
sessions are live.** A sibling session's `git checkout HEAD -- <paths>` and its `git add -A`
reverted 115 deleted files and 8 edited files, three separate times, and each time the
revert landed as a *modified* file rather than a deletion (= `git status` showed `M`, not
`D`), so it was invisible until a build reported types it could not find. The sibling's
`git add -A` also swept the pre-ticket catalog into its own commit, which is why the
295-key localization cleanup designed for ticket 1 never landed.

Recorded in `wenshu-pocock-workflow` (pitfalls 9, 21, 22, 23) and in memory. The rule
that fixes it is AGENTS.md 1.12: every code-changing ticket runs in its own worktree, via
a board card.

## 8. Open gaps (= boss decision, not acted on)

1. **A sibling session held a staged verbatim revert of ticket 1** in
   `.worktrees/rightrail-restore` (115 paths, +24,940 / −133 = the exact inverse of
   `e4ffec568`, uncommitted). It was never committed, and the worktree and its branch
   were deleted before this closure was written (= the revert never reached main; = the
   15 features stay deleted). Worth knowing because the same session produced it: a
   revert of another session's commit is easy to stage by accident.
2. **69 catalog keys are orphaned** (= no source or test file references them), 23 of them
   the removed right-rail features' own labels (`tab.title.*`, `inspector.documentTools.*`).
   The cleanup was designed and scripted, then lost to the revert described in section 7.
   Not redone here: a parallel session is working in the localization area right now, so
   the catalog has one owner at a time (= the next session should take it, not both).
3. **Several sessions build and launch the app from scratch worktrees**, which fight for
   the foreground and kill each other's processes. During this session they were at the
   pre-ticket commit (`scratch/ab-a`, `ab-c`, `ab-d`, `ab-f`, `ab-narrow`); by the time
   this closure was written they had moved to board cards branching from the delivered
   commit. A window without the 4 page icons and the inspector toggle is a stale build,
   not the delivered one.
4. **Two risks reported earlier are still open**: the prompt-injection wrapper for
   untrusted tool input is never wired into the live dispatch path, and
   `RetryUtils.withClassifierRetry` has a classification branch that can no longer be
   reached.

## 9. What the next session must know

- `main` = `origin` = `old-origin` = `106d1c100`. The tree is clean.
- The right rail is a shell: 4 pages, no tools, empty state. Adding a tool to a page is a
  new ticket.
- The removal of the 15 features is complete in code, agent tools, persistence, and
  tests. Their catalog labels are still in the catalog (= gap 2 above).
- Do not run `git add -A` or `git stash` in the shared checkout while a sibling is live
  (= section 7). Use a board card with `--workspace worktree --project project`.
