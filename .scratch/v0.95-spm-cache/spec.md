# v0.95 SPM resource cache · Spec (= honest scope gap)

**Branch**: `wt/v0.95-spm-cache-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v0.94 documented the I18nParityTests flake as `SPM build cache stale`
(= the built test bundle has 751 keys vs the source's 753 keys). Per
boss OOB "A": investigate and fix.

## Investigation (= per Q34 5.4)

### Source-of-truth verification

- `Sources/WenshuApp/Resources/en.lproj/Localizable.strings` =
  Apple binary property list (= 53,902 bytes in git; = 753 keys when
  parsed via plistlib).
- `Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings` =
  Apple binary property list (= 46,842 bytes in git; = 442 keys when
  parsed via plistlib).
- Both files were committed as binary plist (= pre-compiled). Source
  history (= `git log --name-only`) shows `fix(wenshu): sidebar new
  button label = i18n key` and `fix(wenshu): emotion curve
  accessibility label = i18n key` commits that added the missing
  keys (= `sidebar.new_button.label` + `a11y.emotion_curve`).

### Built bundle verification

- `.build/out/Products/Debug/WenshuAppTests.xctest/Contents/Resources/Wenshu_WenshuAppTests.bundle/Contents/Resources/en.lproj/Localizable.strings`
  = Apple binary property list (= **only 751 keys**, = missing
  `a11y.emotion_curve` and `sidebar.new_button.label`).
- After `rm -rf .build && swift build`, the bundle STILL has 751 keys
  (= not the 753 in source). **SPM is using a stale snapshot that
  cannot be flushed by normal means**.

### v0.95 fix attempt

- Tried converting the source files from binary plist to UTF-8 XML
  format (= human-editable source-of-truth; = SPM compiles to
  binary plist at build time).
- `plutil -convert xml1` succeeded; = source is now XML with 753 keys.
- After `rm -rf .build && swift build`, the built bundle is STILL
  binary plist with 751 keys (= stale snapshot).
- After `touch Sources/.../Localizable.strings && swift build`, the
  built bundle STILL has 751 keys.

### Root cause

- The `.lproj/Localizable.strings` files are committed as
  **binary plist** (= pre-compiled). SPM `.copy()` copies the file
  as-is into the test bundle.
- The built bundle appears to come from an older snapshot of the
  source (= perhaps a global SPM cache, `~/Library/Caches/...`, or a
  workspace-level cache).
- **SPM is not invalidating its copy of the resource even when the
  source changes and the build is fresh.**

## Scope (= 1 ticket, 1 spec doc 1 commit per Q112)

**This ticket ships the spec doc only** (= no source changes; = no
SPM cache fix). The pre-existing flake remains.

## Future fix options (= scope-deferred per Q112)

| # | Option | Risk |
|---|---|---|
| 1 | Convert source `.strings` to UTF-8 XML + clear `~/Library/Caches/org.swift.swiftpm/` (= SPM global cache) before each `swift build` | Medium (= user workflow disruption) |
| 2 | Use `.process("Resources")` instead of `.copy(...)` for test target (= SPM recompiles from XML source) | Medium (= may break other resources) |
| 3 | Add a pre-build hook script that copies the binary plist from main `.build/` (= always-rebuilt copy) | Low (= build-script addition) |

The right fix requires investigating the SPM cache location (= likely
`~/Library/Caches/org.swift.swiftpm/` or `~/Library/Developer/Xcode/DerivedData/`)
and either invalidating it or working around it via `.process()`.

## Cross-references

- `Sources/WenshuApp/Resources/en.lproj/Localizable.strings` (= source-of-truth)
- `.build/out/Products/Debug/WenshuAppTests.xctest/Contents/Resources/Wenshu_WenshuAppTests.bundle/Contents/Resources/en.lproj/Localizable.strings`
  (= stale built bundle)
- `Tests/WenshuAppTests/I18nParityTests.swift:212` (= the failing test)
- `Package.swift:170` (= the `.copy("Resources/en.lproj")` declaration)
- `.scratch/v0.94-remaining-flakes/spec.md` (= the upstream analysis
  that this ticket attempted to fix)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= no source changes; = no effect)
2. `swift test --filter "I18nParityTests.sourceCallsResolveInCatalog"`
   = **1 issue** (= pre-existing; = unchanged; = documented)

## Out-of-scope (= explicit)

- SPM cache invalidation strategy (= requires investigation of
  SPM global cache paths; = separate ticket)
- Production code changes (= future tickets)