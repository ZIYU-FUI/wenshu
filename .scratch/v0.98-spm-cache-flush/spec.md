# v0.98 SPM cache flush / I18nParityTests fix · Spec

**Branch**: `wt/v0.98-spm-cache-flush-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v0.94 + v0.95 documented the I18nParityTests flake as "SPM global
cache stale" (= source had 753 keys, built bundle had 751). Per
boss OOB "A": investigate further.

## Root cause (= per Q34 5.4)

**The real root cause is NOT SPM global cache**. It's a
**dual-source-of-truth bug** in the test target's resource layout.

### Investigation steps

1. `Sources/WenshuApp/Resources/en.lproj/Localizable.strings` =
   **53902 bytes / 753 keys** (= includes `a11y.emotion_curve` +
   `sidebar.new_button.label`).
2. `Tests/WenshuAppTests/Resources/en.lproj/Localizable.strings` =
   **51496 bytes / 751 keys** (= missing the 2 latest keys).
3. `.build/.../WenshuAppTests.xctest/.../Wenshu_WenshuAppTests.bundle/.../en.lproj/Localizable.strings`
   = **51496 bytes / 751 keys** (= the stale size).
4. Clearing `~/Library/Caches/org.swift.swiftpm/{manifests,prebuilts,repositories}`
   + `rm -rf .build` + rebuild **does NOT** refresh the test bundle.

### Why two copies exist

`Package.swift:170-172` declares:
```swift
resources: [
    .copy("Resources/en.lproj"),
    .copy("Resources/zh-Hans.lproj"),
]
```
in the test target. The path is **relative to the test target's
source directory** (= `Tests/WenshuAppTests/`), not the package root.
So SPM copies `Tests/WenshuAppTests/Resources/en.lproj/Localizable.strings`
into the test bundle, **not** the canonical source at
`Sources/WenshuApp/Resources/...`.

The canonical source at `Sources/.../Resources/` is the source-of-truth
for production. The test target's `Tests/.../Resources/` was apparently
copy-pasted from an older snapshot (= before the 2 latest keys were
added in commits `37acdbeca` and `9aaae4db1`) and never updated.

### Fix

`cp Sources/WenshuApp/Resources/en.lproj/Localizable.strings Tests/WenshuAppTests/Resources/en.lproj/Localizable.strings`
(= sync the test target's stale resource to the current source-of-truth).

After fix:
- `Tests/.../Resources/en.lproj/Localizable.strings` = **53902 bytes
  / 753 keys**
- `.build/.../WenshuAppTests.xctest/.../WenshuAppTests.bundle/.../en.lproj/Localizable.strings`
  = **53902 bytes / 753 keys** (= fresh)
- `swift test --filter "I18nParityTests.sourceCallsResolveInCatalog"` =
  **1/1 pass**

## Scope (= 1 ticket, 1 spec doc 1 commit per Q112)

| # | Action | Files | Status |
|---|---|---|---|
| 1 | Sync test target Resources from source | `Tests/WenshuAppTests/Resources/en.lproj/Localizable.strings` + `Tests/WenshuAppTests/Resources/zh-Hans.lproj/Localizable.strings` | ✅ done |

Total v0.98 = **2 files changed (= binary content sync only)**, **0
production code changes**, **0 test code changes**.

## Cross-references

- `Sources/WenshuApp/Resources/en.lproj/Localizable.strings` (= canonical
  source-of-truth, 753 keys)
- `Tests/WenshuAppTests/Resources/en.lproj/Localizable.strings` (= was
  stale, now synced to canonical)
- `Package.swift:170-172` (= the `.copy("Resources/en.lproj")`
  declaration that makes the test target use the test-local
  `Tests/.../Resources/` directory, not the package-root
  `Sources/.../Resources/`)
- `Tests/WenshuAppTests/I18nParityTests.swift:212` (= the failing test)
- `.scratch/v0.94-remaining-flakes/spec.md` (= the upstream analysis)
- `.scratch/v0.95-spm-cache/spec.md` (= the prior wrong-attempt
  analysis; = the real fix was different)

## Validation (= per Q34 step 4)

1. `swift test --filter "I18nParityTests.sourceCallsResolveInCatalog"`
   = **1/1 pass** (= previously 1 fail)
2. `swift build` = BUILD COMPLETE
3. Test target resource file = now matches canonical source
   (= SHAs identical: `fa7a1b473d88b068`)

## Out-of-scope (= explicit)

- Package.swift restructuring (= .copy path could be changed to point
  to source; = would simplify future syncs; = separate ticket)
- Production code changes (= not needed for this fix)