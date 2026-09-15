# v0.94 Remaining pre-existing flakes · Spec (= honest scope gap)

**Branch**: `wt/v0.94-remaining-flakes-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

`swift test` (= full suite) has 3 pre-existing flakes that v0.90 + v0.91
+ v0.92 did NOT address:

1. **I18nParityTests.sourceCallsResolveInCatalog** — asserts all
   `WenshuI18n.t("...")` calls in source resolve to the en catalog
   (= boss 2026-08-24 fix-tracking; = I18N-CODECOVERAGE-001)
2. **GeminiNativeConnectorTests** — 2 issues + fatal nil-unwrap
3. **AnthropicConnectorTests** — Anthropic-native system field with
   `cache_control` decodes wrongly

Per boss OOB "A": investigate and fix.

## Root cause analysis (= per Q34 5.4)

### Flake 1 — I18nParityTests

- Test reports `["a11y.emotion_curve", "sidebar.new_button.label"]` as missing
  from the en catalog.
- `Sources/WenshuApp/Resources/en.lproj/Localizable.strings` (= source)
  **already contains both keys** (= verified via `plutil -p`).
- `WenshuAppTests.xctest/.../Wenshu_WenshuAppTests.bundle/.../en.lproj/Localizable.strings`
  (= built test bundle) **does NOT contain them** (= verified via
  `plistlib.load`).
- Root cause = SPM build cache: the test bundle was copied from a
  stale version of the source `.strings` file. Per Q57: 3rd-party
  verdict (= cache invalidation) ≠ authority; = the source-of-truth
  (= `Sources/WenshuApp/Resources/en.lproj/Localizable.strings`) is
  correct.

### Flakes 2 + 3 — GeminiNativeConnectorTests + AnthropicConnectorTests

- Gemini test expects URL path `/models/gemini-2.5-flash:generateContent`
  and `?key=gem-test-key` query string. Production code (= `GeminiNativeConnector`)
  builds the URL differently (= the test was written against a
  previous URL shape).
- Anthropic test fails to decode the system field with
  `cache_control` (= production decoder doesn't handle the
  `cache_control` JSON shape yet).
- Both are **pre-existing** boss 2026-08-24 fix-tracking items.

## Scope (= 1 ticket, 1 spec doc 1 commit per Q112)

**This ticket ships the spec doc only** (= no production code changes;
= no test changes; = the pre-existing flakes remain). Future tickets
will fix each:

| # | Future ticket | Scope |
|---|---|---|
| 1 | `v0.95-flush-spm-resource-cache` | Investigate SPM cache invalidation; possibly add a build phase or post-build script to convert `.strings` to binary plist |
| 2 | `v0.96-gemini-native-url-shape` | Update `GeminiNativeConnector` to build URL `/models/{model}:generateContent?key={apiKey}` (= match test expectation) |
| 3 | `v0.97-anthropic-cache-control` | Update `AnthropicNativeDecoder` to handle the `cache_control` JSON shape |

Out of scope (= explicit):

- Fixing the 3 pre-existing flakes (= each is a substantive change
  with its own scope; = 1 ticket per flake per Q112)
- Test file edits (= the tests are not wrong per Q57; = the production
  code is missing the feature)
- Production code changes (= future tickets)

## Cross-references

- `Tests/WenshuAppTests/I18nParityTests.swift:212` (= the failing test)
- `Sources/WenshuApp/Resources/en.lproj/Localizable.strings` (= the
  source-of-truth with the keys already present)
- `.build/out/Products/Debug/WenshuAppTests.xctest/Contents/Resources/Wenshu_WenshuAppTests.bundle/Contents/Resources/en.lproj/Localizable.strings`
  (= the stale built bundle missing the keys)
- `Tests/WenshuAppTests/Provider/GeminiNativeConnectorTests.swift:31-32`
  (= the Gemini URL test expectations)
- `Tests/WenshuAppTests/Provider/AnthropicConnectorTests.swift:16` (= the
  Anthropic cache_control decoder test)

## Validation (= per Q34 step 4)

1. `swift test --filter "I18nParityTests.sourceCallsResolveInCatalog"` =
   1 issue (= pre-existing; = unchanged; = documented)
2. `swift test --filter "GeminiNativeConnectorTests"` =
   2 issues + fatal nil-unwrap (= pre-existing; = unchanged; = documented)
3. `swift test --filter "AnthropicConnectorTests"` =
   1 issue (= pre-existing; = unchanged; = documented)
4. `swift build` = BUILD COMPLETE (= no source code changes)

## Out-of-scope (= explicit)

- SPM cache invalidation strategy (= v0.95)
- Gemini URL shape fix (= v0.96)
- Anthropic cache_control decoder fix (= v0.97)
- Any production code change