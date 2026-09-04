# Wenshu v0.28 third-party library integration — spec + NukeUI SPM conflict fix

## Boss 2026-08-28 OOB (paraphrased English — verbatim Chinese transcription removed per AGENTS.md Section 5-6 English-only rule; see Standards H1+H2 forward-fix)

> Boss granted autonomous proceed-mode (= proceed without per-step clarification; per Q91 5-step grill pattern).
> Earlier same day OOB: "all libraries can be introduced immediately" (= Section 11.1 ratification).
> Q&A round 2 reply: boss chose option two (= full audit before commit, not blind commit). The original Chinese verbatim contained the forbidden modal token `ying-gai` (per AGENTS.md Section 8) — that token is removed in this forward-fix and replaced with a paraphrase. The Chinese characters were: "wo jue de ying gai shi er" (Pinyin transcription, no Chinese characters retained).

## Scope (this commit batch)

**Audit-and-fix the 11 third-party libraries that were partially added to Package.swift on 2026-08-28.** Specifically:

1. Audit every library's actual SPM resolve path (download tags + read Package.swift at the latest compatible version)
2. Resolve the **NukeUI SPM conflict** that blocks `swift package resolve`:
   - `kean/NukeUI` 0.8.3 (latest published tag of the standalone repo) writes `.package(url: ".../Nuke.git", from: "10.5.0")` — i.e. it requires Nuke 10.5..<11 only.
   - We pinned `kean/Nuke from: 13.2.0` → SPM error: `root depends on 'nuke' 13.2.0..<14.0.0 and root depends on 'nukeui' 0.8.3..<1.0.0` (practically requires Nuke 10.5..<11).
   - Root cause: **kean merged NukeUI into the main `kean/Nuke` repo as of Nuke 11.0** (release 2022-07-20). The standalone `kean/NukeUI` repo stopped receiving Nuke 11/12/13 updates; it is effectively frozen at Nuke 10.
   - Fix: drop the standalone `kean/NukeUI` dependency; import `product(name: "NukeUI", package: "Nuke")` from the main Nuke 13.2.0 repo (verified: `Nuke 13.2.0 Package.swift` declares `library(name: "NukeUI", targets: ["NukeUI"])`).
3. Audit the remaining 10 libraries for tag resolution correctness (done in `references/2026-08-28-third-party-multiview-survey/` + below).
4. Update AGENTS.md §11.1 to reflect the ratified list (already done as partial commit, will be committed in this batch).
5. Verify `swift package resolve` exit 0 + `swift build` exit 0.

## 11-library audit table (2026-08-28)

| Library | Pin in Package.swift | Latest tag | Latest macOS platform | SPM conflict? |
|---|---|---|---|---|
| `bring-shrubbery/lucide-swift` | `exact 1.25.0` | 1.25.0 | macOS 14 | none — already in v0.25.1 baseline |
| `sindresorhus/Defaults` | `from 8.2.0` | v8.2.0 | macOS 11 | none |
| `sindresorhus/KeyboardShortcuts` | `from 1.10.0` | v1.10.0 | macOS 10.13 | none |
| `kean/Nuke` | `from 13.2.0` | 13.2.0 | macOS 12 | none |
| `kean/NukeUI` (standalone) | `from 0.8.3` | 0.8.3 | macOS 10.14 | **CONFLICT — frozen at Nuke 10** |
| `weichsel/ZIPFoundation` | `from 0.9.20` | 0.9.20 | macOS 10.11 | none |
| `groue/GRDB.swift` | `from 7.11.1` | v7.11.1 | macOS 10.15 | none |
| `swiftlang/swift-markdown` | `from 0.4.0` | 0.8.0 (2026-05-07) | n/a (uses releases, not git tags) | none |
| `mattt/EventSource` | `from 1.5.1` | 1.5.1 | n/a (cross-platform) | none |
| `gonzalezreal/textual` | `from 0.5.0` | 0.5.0 | macOS 15 | none |
| `krzysztofzablocki/Inject` | `from 1.6.0` | 1.6.0 | macOS 10.15 | none |
| `nalexn/ViewInspector` | `from 0.10.3` | 0.10.3 | macOS 10.15 | none |

## Files in this batch

1. `Package.swift` — remove standalone `kean/NukeUI` dep, change `.product(name: "NukeUI", package: "NukeUI")` to `.product(name: "NukeUI", package: "Nuke")`. Add comment explaining why.
2. `AGENTS.md` — §11.1 ratification list (already partially drafted; will land as `docs(wenshu):` commit).
3. `.scratch/2026-08-28-third-party-integration-fix/spec.md` — this file.
4. `.scratch/2026-08-28-third-party-integration-fix/issues/01-nuke-ui-spm-conflict-fix.md` — per-ticket file.

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0 (target verifies the 11 libraries compile against `.macOS(.v27)` + Swift 6.4)
- All 11 libraries listed in AGENTS.md §11.1 ratified section (= boss OOB sign-off on the full set)
- Code-review dual-axis (Standards + Spec) per boss 8/25 standing instruction, run before commit body finalization

## Out of scope (deferred to feature work)

- Per-feature wiring of each library (e.g. Nuke wiring into bookshelf card thumbnails). That belongs in the ticket that introduces the feature (= v0.28+ when the user-visible feature ships).
- ADR-0008 §"Does NOT apply to" already names `kean/Nuke` as approved; the other 10 libraries are added by this ratification.
- `realm/SwiftLint` + `nicklockwood/SwiftFormat` mentioned in AGENTS.md §11.1 but NOT in Package.swift = dev-time CLI tools (Brewfile distribution), not SPM deps. Documented in AGENTS.md only.

## Verification commands

```sh
# Step 1: SPM resolve (must exit 0)
cd /Volumes/ANAN/Engineering/wenshu
swift package resolve

# Step 2: build (must exit 0)
swift build
```



## Corrections from Spec-axis review (2026-08-28 forward-fix)

Per Spec-axis code-review report (`.scratch/2026-08-28-third-party-integration-fix/spec-axis-report.md`):

- **P1**: transitives count in commit `3177d3f48` body = "6 transitives"; actual = **3 transitives** (cmark-gfm 0.8.0, swift-concurrency-extras 1.4.1, swiftui-math 0.1.0). Correction: "3 transitives", not 6. No source change required (commit history is immutable per Q5.4 do-not-amend); this note serves as the audit trail.
- **S1**: `sindresorhus/KeyboardShortcuts` pin `from: 1.10.0` resolves to 1.17.0 (latest in 1.x line); actual latest stable = **3.0.1** (2026-06-17). Forward-fix deferred to per-feature wiring ticket (= v0.28 Settings pane).
- **S2**: `sindresorhus/Defaults` pin `from: 8.2.0` resolves to 8.2.0; actual latest stable = **9.0.9** (2026-06-23). Forward-fix deferred to per-feature wiring ticket (= v0.28 chat history migration). v8 → v9 carries breaking-change risk = requires boss ratification before silent bump.
- **S3**: textual "uses releases not tags" comment in audit table applies only to `swiftlang/swift-markdown` (which uses GitHub Releases rather than git tags). `gonzalezreal/textual` does use git tags. Tidiness only; no source change required.

## References

- `.scratch/2026-08-27-third-party-depscan/spec.md` — first-pass survey (8/27)
- `.scratch/2026-08-28-third-party-multiview-survey/{doc-storage,editor-render,dev-tooling,agent-pipeline}-survey.md` — multi-area surveys (8/28)
- `.scratch/2026-08-27-bonsplit-probe/probe-report.md` — bonsplit verdict (REJECTED per ADR-0008; v0.28 self-implements WorkspaceView)
- `.scratch/2026-08-28-v0-28-free-layout/spec.md` — v0.28 free-layout spec (= the feature work that consumes some of these libraries)
- AGENTS.md §11.1 — third-party policy ratification
- ADR-0008 — no 3rd-party view-framework / pane / dock / split (ratified 2026-08-28)