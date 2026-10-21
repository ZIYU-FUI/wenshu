# Session close — 2026-10-21 — the hand-written .lproj folders replaced by String Catalogs

> Boss directives 2026-10-21 (rendered in English per rule 1.1): "check the folder boxed in
> red, it should not exist any more, we are using Apple's own multi-language support", then
> "reload the wenshu docs, we worked out a new parallel development method, you can now make
> the changes you want to make without conflict".
> Session: `20261021_125040_6f973f` (this one, desktop).
> Closure type: 1 code ticket (1 commit) + this closure doc (1 commit).

## 1. What this session did

The app shipped its translations twice: a String Catalog for the text on screen, and
hand-written `.strings` files for the names the system reads from the bundle's `Info.plist`
(= the Dock name, the Finder name, the Open With name). The hand-written copy is the one the
system reads, so a rename in the catalog never reached the Dock. On top of that, the test
target held a third copy of the on-screen table that nothing declared and that had drifted
away from the catalog.

| # | Ticket | Commit | Repo impact |
|---|--------|--------|-------------|
| 1 | Ship the Info.plist localization from a second String Catalog; delete every hand-written `.lproj` folder | `0e9dbd405` | 11 files, 182 insertions, 96 deletions |

## 2. What changed

**Two catalogs, no hand-written `.lproj` in the source tree.**

- `Sources/WenshuApp/Resources/InfoPlist.xcstrings` (new) holds the four names the system
  reads from the bundle's `Info.plist`: `CFBundleDisplayName`, `CFBundleName`,
  `CFBundleTypeName`, `UTTypeDescription`. English and Simplified Chinese, values moved
  unchanged from the deleted files.
- `Sources/WenshuApp/Resources/Localizable.xcstrings` is untouched (= it is the on-screen
  text table, and a sibling session was adding keys to it at the time).
- Deleted `Sources/WenshuApp/Resources/en.lproj/` and `Sources/WenshuApp/Resources/zh-Hans.lproj/`.
- Deleted `Tests/WenshuAppTests/Resources/en.lproj/` and its `zh-Hans` twin. Nothing declared
  them, so the build copied them into the test bundle anyway, and they had drifted: 302 keys
  the catalog no longer had, 233 catalog keys they never had.

**Build governance.**

- `Package.swift`: the two `exclude` entries pointing at already-deleted files are gone, so
  the four `Invalid Exclude ... File not found` warnings per build are gone with them. The
  comment blocks that described the old `.lproj` arrangement and the belief that the build
  system ships a catalog verbatim were rewritten to match what the build does.
- `Scripts/build-app.sh`: the hand-run `xcstringstool compile` block is removed. Its output
  was overwritten by the promote step before the app finished, and it could only compile one
  catalog, so the second table would have been missing from it.
- `Tools/devtool/double-axis.sh`: the i18n check looked for changed files matching
  `.lproj/Localizable`, which can never match anything now, so the check silently always
  passed. It now checks the catalog file and asserts that a changed catalog carries both an
  English and a Simplified Chinese localization.
- `Tools/build-wenshu.sh` needed no edit: sibling card `t_76a7e87b` deleted it (it was a
  stale duplicate of `Scripts/build-app.sh`) and that card landed on main first. That
  deletion is why the rebase conflict was a comment-only job.

## 3. Apple canonical

- One String Catalog per table; the catalog's file name is the table name.
  `Localizable.xcstrings` is the default table that `String(localized:)` reads with no table
  argument.
- The names the system reads from the bundle's `Info.plist` belong in a second catalog named
  `InfoPlist.xcstrings`. The name is Apple's: the build compiles that catalog into
  `<locale>.lproj/InfoPlist.strings`, the same file name the hand-written file produced, so
  runtime behaviour is unchanged. The catalog had to be authored by hand here, because the
  package embeds its `Info.plist` into the Mach-O instead of shipping it as a visible
  resource, which hides the keys from the build system's automatic extraction.
- The build system compiles every `.xcstrings` in a processed resource directory into
  `<Bundle>/Contents/Resources/<locale>.lproj/<Table>.strings`, as UTF-16. Several catalogs
  in one target each produce their own table file. No hand-run compile step is needed.
- Never keep a hand-written `.strings` beside a catalog for the same table: the hand-written
  file wins at runtime and silently shadows every key added to the catalog afterwards.

## 4. How it ran (the new parallel method)

Board card `t_8131aa71` on the `wenshu-par` board, `--workspace worktree --project project`,
implementer `wenshu-dev`, per rule 1.12. The card body carried the four-section spec
(business / current state / Apple canonical / after-fix), the nine work items, the acceptance
evidence to produce, and the must-not-touch set.

- Run 18 timed out at the 45-minute cap with the work staged but uncommitted.
- Run 46 picked the work up in the same worktree and completed it: one commit, `2ca11fa32`.
- The card was rebased onto `main` (one comment conflict in `Package.swift`, resolved to the
  post-migration text), every acceptance check was re-run on the rebased tree, and the
  branch was merged `--ff-only` (= one commit per ticket, matching the wave's convention).

The sibling card `t_76a7e87b` touched the same two `Package.swift` comment blocks. The worker
detected the hotspot, dropped its `Tools/build-wenshu.sh` edit (that file was being deleted
anyway), and left a card comment naming the conflict and how to resolve it.

## 5. Verification

| Measure | Baseline | Delivered tree (`0e9dbd405`) |
|---------|----------|-------------------------------|
| `swift build` exit code | 0 with 4 `Invalid Exclude` warnings | **0, and 0 `Invalid Exclude` warnings** |
| `Scripts/build-app.sh` exit code | — | **0** |
| Source-tree `.lproj` folders | 4 (2 app, 2 test) | **0** |
| Module bundle tables per locale | `Localizable.strings` only | **`Localizable.strings` + `InfoPlist.strings`**, both UTF-16 |
| Shipped `.app` tables per locale | `Localizable.strings` only | **`Localizable.strings` + `InfoPlist.strings`**, both UTF-16 |
| Catalog key set vs compiled table | — | **identical: 363 and 4, zero missing, zero extra** |
| The four system names' values | hand-written source | **byte-identical to the deleted files** |
| XCTest failing set vs baseline | 13 | **13, identical set** |
| Swift Testing failing set vs baseline | — | **0 new failures across two runs on each tree** |
| Localization suites | — | **6 of 6 pass** |

The baseline for the test comparison was a worktree checked out at the same `main` commit the
branch was rebased onto, and both trees were run twice. Two network tests flip in
opposite directions between runs on **both** trees, because they share a process-global
`URLProtocolStub`; the flip was reproduced on the unmodified baseline, so it is pre-existing
flakiness and not a regression. (The two are the Gemini native URL test in
`GeminiNativeConnectorTests.swift` and the network-failure fallback test in
`ProviderFetcherTests.swift`; the second test's name contains a CJK character, so it is
named by its file here.) The six localization suites that must be green for this
ticket all pass: `LocalizedKeyTests`, `UserFacingErrorI18nTests`, `PlanModeI18nTests`,
`ImportSOPLoaderTests`, `EmptyStateLocalizationParityTests`,
`PreviewPaneEmptyStateLocalizationTests`.

`ImportSOPLoaderTests` was the one real risk in the ticket: with the test target holding no
resources of its own, `Bundle.module` in a test file has to resolve to the app module's
resource bundle, which is where the SOP files live. It passes, so the resolution is correct.

## 6. Open gaps (= not acted on)

1. **The compiled tables are only as fresh as the last build.** The app bundle carries the
   compiled catalog twice (at `Contents/Resources/<locale>.lproj/` and inside the nested
   module bundle), and `Bundle.main` wins the lookup. `Scripts/build-app.sh` refreshes the
   app-level copy from the module bundle, so a build is what keeps them in sync; a stale
   `.app` shows raw keys for anything added to the catalog since.
2. **The four `Info.plist` names are catalog values now, so adding a fifth means editing the
   catalog by hand.** The automatic extraction path is unavailable to this package because
   the `Info.plist` is embedded into the Mach-O rather than shipped as a visible resource.
   If that changes, the catalog can be regenerated instead of hand-authored.
3. **The suite's pre-existing red baseline is unchanged** (= 13 XCTest failures plus a
   moving set of Swift Testing issues, none in the localization suites). This ticket did not
   touch it, and the two flaky network tests remain flaky.

## 7. What the next session must know

- `main` tip at this closure: `0e9dbd405` plus this doc's commit. The tree is clean.
- The app's resource directory holds two catalogs (`Localizable.xcstrings`,
  `InfoPlist.xcstrings`) and no `.lproj` folder. A hand-written `.strings` beside a catalog
  is forbidden: it shadows the catalog at runtime.
- The build system compiles the catalogs natively. Do not add a hand-run `xcstringstool`
  step, and do not reintroduce a `.lproj` source folder.
- `Scripts/build-app.sh` is the only script that assembles the app
  (`Tools/build-wenshu.sh` is gone).
- A code-changing ticket runs as a board card in its own worktree, per rule 1.12. This
  ticket's card was `t_8131aa71`; its worktree and branch were removed after the merge.
