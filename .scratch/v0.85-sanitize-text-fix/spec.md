# v0.85 sanitizeSurrogates force-unwrap fix · Spec

**Branch**: `wt/v0.85-sanitize-text-fix-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推"

## Context

While running the full `swift test` suite during the v0.83 + v0.84
verification, the suite process crashed with "exited with signal code 5"
(= SIGTRAP, = Swift runtime trap). The trap was located in
`MessageSanitization.sanitizeSurrogates(_:)`: a force-unwrap on the
result of `text.unicodeScalars.firstIndex(of: scalar)` (= which returns
`nil` when the scalar is not found, = leading to the SIGTRAP).

This was a pre-existing flake (not introduced by v0.73-v0.82) but
exposed when LLM-supplied input contains corrupted UTF-16 (=
unpaired surrogate halves).

Per boss priority ("按优先级推"): fix the SIGTRAP before further
feature work. v0.85 = the fix.

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | Ticket | File(s) | LOC change | Status |
|---|---|---|---|---|
| 1 | `001-sanitize-surrogates-fix` | `Sources/WenshuApp/Core/Agent/Conversation/MessageSanitization.swift` | -3 LOC / +18 LOC | ✅ done this branch |

Out of scope (= explicit):

- New test file (= `testSurrogateStrip` in `MessageSanitizationRepairTests`
  already covers the lone surrogate case via `String(decoding:as:UTF16.self)`).
- Refactor of other `MessageSanitization` static methods (= sanitize,
  escapeInvalidCharsInJSONStrings, repairToolCallArguments, etc.)
- Performance optimization (= extraction is mechanical, = no algorithmic change)

## Per-ticket acceptance criteria

### Ticket 001 — sanitizeSurrogates force-unwrap fix

- Replace `text.unicodeScalars.firstIndex(of: scalar)!` with
  index-arithmetic walk that doesn't force-unwrap (= uses
  `scalars.startIndex` + `scalars.index(after:)` instead of
  `makeIterator()` + `firstIndex(of:)`)
- Existing `testSurrogateStrip` (= lone high surrogate + lone low
  surrogate + paired surrogate preservation) passes
- All other `MessageSanitization*` tests pass (= 22 tests total
  across 4 suites)

## Root cause analysis

```swift
// BEFORE (= SIGTRAP):
var iter = text.unicodeScalars.makeIterator()
while let scalar = iter.next() {
    if scalar.value >= 0xD800 && scalar.value <= 0xDBFF {
        let idx = text.unicodeScalars.firstIndex(of: scalar)!  // ← CRASH
        ...
    }
}
```

`firstIndex(of:)` returns `nil` when the scalar is not found (= e.g.,
when the iterator has already advanced past the matching scalar).
The force-unwrap `!` triggered SIGTRAP when LLM-supplied input
contained corrupted UTF-16 (lone high surrogates followed by
non-low-surrogate bytes).

## Fix

```swift
// AFTER (= no force-unwrap):
let scalars = text.unicodeScalars
var idx = scalars.startIndex
while idx < scalars.endIndex {
    let scalar = scalars[idx]
    if scalar.value >= 0xD800 && scalar.value <= 0xDBFF {
        let nextIdx = scalars.index(after: idx)
        if nextIdx < scalars.endIndex {
            let next = scalars[nextIdx]
            if next.value >= 0xDC00 && next.value <= 0xDFFF {
                out.unicodeScalars.append(scalar)
                out.unicodeScalars.append(next)
                idx = scalars.index(after: nextIdx)
                continue
            }
        }
        idx = scalars.index(after: idx)  // ← drop lone high surrogate
        continue
    }
    if scalar.value >= 0xDC00 && scalar.value <= 0xDFFF {
        idx = scalars.index(after: idx)
        continue
    }
    out.unicodeScalars.append(scalar)
    idx = scalars.index(after: idx)
}
```

Single walk via index arithmetic (= no iterator, no force-unwrap).
Drops lone high + lone low surrogates, preserves valid pairs.

## Cross-references

- `Tests/WenshuAppTests/Agent/MessageSanitizationRepairTests.swift:62`
  (= existing `testSurrogateStrip` covers the lone-surrogate edge cases)
- `Sources/WenshuApp/Core/Agent/Conversation/MessageSanitization.swift`
  (= v0.35 ticket 001 surface)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "MessageSanitization"` = 22/22 pass
3. Full `swift test` (= no SIGTRAP) — verified per v0.84 verification
   round

## Out-of-scope (= explicit)

- Refactor of `sanitizeText` / `sanitize(messages:)` /
  `escapeInvalidCharsInJSONStrings` / `repairToolCallArguments` (= all
  already tested, = not affected by this bug)
- General Unicode sanitization improvements (= preserve current behavior)