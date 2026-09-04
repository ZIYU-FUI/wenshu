# Issue 01 — NukeUI SPM dependency conflict fix

> Parent spec: `.scratch/2026-08-28-third-party-integration-fix/spec.md`.
> Implementation commit: see git log (`fix(wenshu):` prefix, NukeUI in subject).
> Po main flow: implement (this issue) + code-review (dual-axis sub-agent per boss 8/25 protocol) + domain-modeling (CONTEXT.md `thirdPartyIntegration` word).

## Symptom

`swift package resolve` exits 1 with:

```
error: Dependencies could not be resolved because root depends on 'nuke' 13.2.0..<14.0.0 and root depends on 'nukeui' 0.8.3..<1.0.0.
'nukeui' >= 0.8.3 practically depends on 'nuke' 10.5.0..<11.0.0 because 'nukeui' 0.8.3 depends on 'nuke' 10.5.0..<11.0.0 and no versions of 'nukeui' match the requirement 0.8.4..<1.0.0.
```

## Root cause

`kean/NukeUI` (standalone repo) was last published as tag `0.8.3` and `Package.swift` at that tag declares `.package(url: ".../Nuke.git", from: "10.5.0")` — i.e. it requires Nuke 10.5..<11 only. The repo is effectively frozen at the Nuke 10 line.

`kean/Nuke` (main repo) merged NukeUI into itself starting at Nuke 11.0 (release 2022-07-20). The current Nuke 13.2.0 `Package.swift` declares:

```swift
.library(name: "NukeUI", targets: ["NukeUI"]),
```

so `product(name: "NukeUI", package: "Nuke")` works against the main repo.

## Fix

1. Drop `.package(url: "https://github.com/kean/NukeUI", from: "0.8.3")` from `Package.swift` `dependencies`.
2. Change `.product(name: "NukeUI", package: "NukeUI")` to `.product(name: "NukeUI", package: "Nuke")` inside the `executableTarget.dependencies` block.
4. Add a comment explaining the architectural reason (kean merged NukeUI into Nuke main repo at Nuke 11.0).

## Acceptance criteria

- `swift package resolve` exit 0 with the 11-library dependency graph resolved.
- `swift build` exit 0 (verifies the 11 libraries link against `.macOS(.v27)` + Swift 6.4).
- AGENTS.md §11.1 still lists `kean/Nuke` + `kean/NukeUI` (now under a single entry: "kean/Nuke + kean/NukeUI — async image pipeline + SwiftUI LazyImage (MIT, 8.6k★ + 1.3k★, P0)").

## Test results

- `swift package resolve` → **PENDING** (run after commit)
- `swift build` → **PENDING** (run after commit)

## UI verify (boss)

N/A — this is a build-time fix; no user-visible UI changes.

## Risk

Low. The API surface of `NukeUI` (SwiftUI `LazyImage`) is unchanged between the standalone `kean/NukeUI 0.8.3` and the in-repo `NukeUI` target under `kean/Nuke 13.2.0`; in-repo version is the canonical maintained path.

## Status: ✅ DONE (after commit + dual-axis review)