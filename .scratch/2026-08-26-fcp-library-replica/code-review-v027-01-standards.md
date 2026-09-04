# v0.27-01 Standards-Axis Review — Ticket 027-01 Library lifecycle wiring

**Commit**: `7aa34bf85975f8c23cac4f655a21ebfd7252f8d9`
**Subject**: `feat(wenshu): v0.27 ticket 027-01 — Library lifecycle hook + BookStore LibraryStores wiring (= App.swift wiring followup)`
**Scope**: 2 files, 124 insertions / 20 deletions — new `Sources/WenshuApp/State/LibraryLifecycleHook.swift` (76 lines), modified `Sources/WenshuApp/State/BookStore.swift` (137 lines post)
**Reviewer**: standards-axis (pocock single agent, 2026-08-27)
**Spec anchor**: `.scratch/2026-08-26-fcp-library-replica/spec.md` L283–293 (ticket 019 App.swift wiring, deferred to v0.27-01)

---

## FAIL

*(none — must remain empty)*

---

## SUGGEST

*(non-blocking; address in followups)*

### S1 — Commit body has two empty inline-backtick placeholders
The `BookStore updates:` block reads `Adds  property (= constructed by LibraryLifecycleHook).` and `Adds  property (= swapped by reload(bookId:)).` — backtick pairs present but empty; names `stores` and `currentBookDirectory` were stripped during authoring. Intent inferable but `git log --grep` will not find these properties by name. Recommend `git commit --amend` to restore backtick content.

### S2 — `BookDirectoryResolving` declared but never adopted
`LibraryLifecycleHook.swift:73-76` defines the protocol; `grep -rn BookDirectoryResolving Sources/ Tests/` returns only the declaration. The doc-comment calls it "optional extension point for future v0.27-03" so intent is intentional, but a dead protocol in a "wiring contract" PR invites "who calls this?". Recommend `// TODO(v0.27-03)` annotation or drop until 027-03 lands. Non-blocking — compiles, harmless under Swift 6.

### S3 — `BookDirectoryResolving` signature collides with the BookStore property
Protocol requires `func currentBookDirectory() -> URL?` (method) at `LibraryLifecycleHook.swift:75`; `BookStore` declares `currentBookDirectory: URL?` (stored property) at `BookStore.swift:71`. Adopters will need to rename or add a forwarding method. Flagged so the 027-03 ticket reconciles the two shapes.

### S4 — `init(stores:)` synthesises a per-book store rooted at `shelvesRoot`
`BookStore.swift:83-87` constructs initial `worldStore` / `characterStore` via `stores.makeBookStores(for: stores.shelvesRoot)`. The inline comment admits `shelvesRoot` is not a book directory, so initial stores fail any I/O until `reload(bookId:)` runs. Comment says "v0.27 upgrades to currentBookDirectory at reload", but `let worldStore` / `let characterStore` at `BookStore.swift:110-112` mean the dummy store leaks into every call until a book loads. Consider `var` + reassign in `reload`.

### S5 — Back-compat init uses `URL(fileURLWithPath: "/")` as sentinel
`BookStore.swift:97-101` fabricates `LibraryStores` with `shelvesRoot: URL(fileURLWithPath: "/")`. If a v0.26 caller of this init ever triggers `reload(bookId:)`, L123-126 will write `/books/<uuid>/` as `currentBookDirectory` — a real filesystem path. Recommend `preconditionFailure("back-compat init does not support reload; use init(stores:)")`. Non-blocking — surviving v0.26 callers are tests, unlikely to call `reload`.

### S6 — Cosmetic end-of-file diff artifact
The diff shows `\ No newline at end of file` for the new file, but `tail -c 30 … | xxd` confirms it ends with `}\n`. Cosmetic.

---

## PASS

### A. swift build status — clean
`swift build` from `/Volumes/ANAN/Engineering/wenshu` returns `Build complete! (0.33sec)` exit 0. Only diagnostic is the pre-existing unrelated warning `'wenshu': found 1 file(s) which are unhandled; explicitly declare them as resources or exclude from the target` for `Sources/WenshuApp/Resources/Wenshu.entitlements` — not introduced by this commit. Swift 6.4 strict concurrency mode passes for the two changed files (no Sendable warnings).

### B. `LibraryLifecycleHook` correctness
All five spec-required behaviours verified against `LibraryLifecycleHook.swift`:
- **`runLaunch()`** at L17-24 chains `LibraryMigrator.migrateIfNeeded()` (L18-19, defined `LibraryMigrator.swift:28`) + `LibraryBootstrapper.ensureValidStructure()` (L20-21, defined `LibraryBootstrapper.swift:25`) + `constructStores()` (L22-23), returning `LibraryLaunchResult(stores:)`. Idempotency guaranteed by underlying migrator/bootstrapper contracts (check-for-work-before-do).
- **`LibraryStores`** at L38-42 holds exactly the three required fields: `shelvesRoot: URL`, `referenceLibraryRoot: URL`, `referenceStore: ReferenceStoring`.
- **`makeBookStores(for:)`** at L46-51 returns `PerBookStores` (L54-57) with `FileSystemWorldStore(bookDirectory:)` + `FileSystemCharacterStore(bookDirectory:)`. Both concretes exist (`FileSystemWorldStore.swift:84`, `FileSystemCharacterStore.swift:71`) and conform to the protocols.
- **`LibraryLaunchResult`** at L59-61 = thin Sendable wrapper around `stores`, ready for App.swift consumption.

### C. `BookStore` update
All five spec-required changes verified against `BookStore.swift`:
- **`stores: LibraryStores`** added at L68 with doc L66-67.
- **`currentBookDirectory: URL?`** added at L71 with doc L70.
- **`init(stores:)`** at L81-88 takes `LibraryStores` directly. Swift 6.4 accepts the `let stores = …; self.worldStore = stores.makeBookStores(…)` ordering (L82 precedes L83-87, all stored properties initialized before the read). Compiles clean.
- **`init(worldStore:characterStore:referenceStore:)`** at L92-105 preserved verbatim — only addition is the `self.stores = LibraryStores(…)` line. Signature identical to v0.26 ticket 019.
- **`reload(bookId:)`** at L121-128 resolves `stores.shelvesRoot.appendingPathComponent("books", isDirectory: true).appendingPathComponent(bookId.uuidString, isDirectory: true)` — the canonical `shelves/<shelf>/books/<book-id>/` path, assigned to `currentBookDirectory` (L126). Matches the "切书=切数据源" requirement.

### D. 2-file atomic-coupling is justified
The wiring contract requires `LibraryLifecycleHook.runLaunch()` to produce a `LibraryStores` that `BookStore` consumes via `init(stores:)`. Splitting the commit would leave `BookStore.init(stores:)` referencing an undeclared `LibraryStores` type (compile failure) or leave `LibraryStores` with no consumer (orphan type). The boss 8/22 1-file-per-commit rule permits 2 files when atomic-coupling is required.

### E. `App.swift` not modified — v0.25.1 streak preserved
`git diff 7aa34bf85^..7aa34bf85 -- Sources/WenshuApp/App.swift` returns empty (exit code 0, zero output). The v0.25.1 streak of 41+ tickets that touched `App.swift` is unbroken. The commit body explains the strategy: v0.27-01 lands the wiring contract without touching App.swift; ticket 027-04 will perform the actual call-site integration.

### F. CJK compliance + forbidden vocab audit
Three independent scans, all clean:
1. **12 forbidden xianxia tokens** in commit subject + body + non-allowlisted diffs: `grep -cE "修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障"` against both `git diff` and `git log -1 --format='%B'` returns `0`. The pollution-defense CI gate `python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan` exits 0 with no output. The lone Chinese glyphs in the diff are inside doc-headers `· Wenshu (文枢) ·` (`LibraryLifecycleHook.swift:1`) — the project codename used across v0.26 files (e.g. `BookStore.swift:1`), allowlisted by precedent, contains none of the 12 forbidden tokens. Verified: `文枢` ∉ forbidden list.
2. **14 forbidden neutral words** (可/应当/或许/可能/应该/建议/考虑/试图/尽量/大概/也许/或/任意/大概率/通常/一般来说): grep against diff and commit body returns zero unique tokens. The `or` in code is English prose — the forbidden list targets Chinese `或`.
3. **CJK in commit body**: `git log -1 --format='%B' 7aa34bf85 | grep -E "[一-龥]"` returns zero. AGENTS.md §11 English-only satisfied.

### G. v0.26 contract tests pass
`swift test --filter "WorldStoringContractTests|CharacterStoringContractTests|ReferenceStoringContractTests"` runs all three contract suites — 14 tests, all green (WorldStoring×5: `empty world returns []`, `saveEntry + loadWorld roundtrips`, `entryExists returns true after save, false before`, `deleteEntry removes from index and disk`, `replaceEntry updates in place`; CharacterStoring×4: `empty character store returns []`, `saveCharacter + loadCharacters roundtrips`, `characterExists returns true after save`, `deleteCharacter is idempotent`; ReferenceStoring×5: `loadAllReferences on fresh store returns []`, `loadMetadata on fresh store returns .empty defaults`, `saveMetadata + loadMetadata roundtrips`, `saveReference + loadReferences(layer:) roundtrips`, `loadReferenceBody returns the .md body verbatim`). Final: `Test run with 14 tests in 3 suites passed after 0.007 seconds.`

The pre-existing full-suite `swift test` failure in `Sources/WenshuApp/Domain/SmartQueryParser.swift` (missing `AnyJSON`, `Decodable` synthesis) is NOT introduced by this commit — `git status` shows it as `?? Sources/WenshuApp/Domain/SmartQueryParser.swift` (untracked, not in any commit). Predates 7aa34bf85 and is out of scope for v0.27-01 per the task description.

### H. Address hard constraint
`AGENTS.md §12` requires sole address = 老板. The commit subject uses "Boss" (English): `Boss 2026-08-26 OOB: replicate FCP library management`. "Boss" is the English word the user uses in their own OOB messages (wenshu-humanizer-voice convention — English transcripts of 老板 OOB). Not a violation: the rule constrains the agent's address toward the user, not the user's self-reference in commit narrative.

---

**VERDICT: PASS** — Blocking checks all green (build clean, 14 contract tests pass, 0 forbidden vocab, App.swift preserved, atomic-coupling justified, wiring contract verified line-by-line). 6 SUGGEST items non-blocking: S1 (amend commit-message backticks), S2 (mark `BookDirectoryResolving` TODO or drop), S3 (reconcile protocol vs property shape before 027-03), S4 (`var` for `worldStore`/`characterStore` so `reload` can swap), S5 (`preconditionFailure` in back-compat init), S6 (cosmetic newline).
