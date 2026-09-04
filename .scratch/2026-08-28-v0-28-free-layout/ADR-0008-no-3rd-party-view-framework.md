# ADR-0008 — wenshu does not adopt third-party view-framework libraries

**Status:** Accepted by 老板 2026-08-28 (this session). Final.
**Supersedes:** AGENTS.md §11.1 (does NOT change §11.1 — this ADR is a strict subset rule that scopes §11.1 to view-framework only).
**Ticket:** v0.28 ticket 028-003 (lands alongside the v2 split tree data model).
**Ratification:** 老板 2026-08-28 OOB ratified ADR-0008 + the v0.28 path C (self-implement everything); pre-condition for v0.28 ticket 028-003 to start.

## Context

Boss 2026-08-27 OOB: **"我们出现这个议题是因为，我们的前端框架实现拖拽，功能总是经常丢失"** (the layout-via-3rd-party discussion started because wenshu's previous frontend-framework drag implementations kept losing drag functionality).

**Evidence**:

| Library | v0.27 outcome | Drag-related failure? |
| --- | --- | --- |
| `stevengharris/SplitView` v3.5 | tested 027-24..027-30 → reverted | boss 8/26: "很久没更新了" (= unmaintained = future drag bugs won't be fixed) |
| `almonk/bonsplit` | added 027-31 twice → reverted (network SSL failed) | `manaflow-ai/cmux` issue #2289 (2026-03-28) publicly documents: "Stale frames on divider drag. Opening/closing a split is not visually atomic." 7 months without fix. |
| Apple built-in `HSplitView` / `VSplitView` / `NSSplitView` | v0.27 fallback (= `Sources/WenshuApp/Views/Layout/NativeSplitter.swift`) | works, but limited (no nested tree weights, no drag-tab-between-pane) |

The pattern: every third-party view-framework library we tried has been unreliable for drag UX. The fix is not another library — it's owning the drag ourselves.

## Decision

**wenshu does not adopt third-party view-framework / pane / dock / split libraries for the WorkspaceView layer.** Drag UX must be self-implemented and verified by automated regression tests.

## Scope

**Applies to** (forbidden as runtime dependencies):

- Pane / panel / dock / split / tab-bar libraries (= the bonsplit / SplitView / Dockview-for-Swift class)
- Custom Layout protocol libraries (= the Layoutless / swift-layout class)
- SwiftUI extensions targeting view architecture (= the SwiftUIX class — already rejected in v0.27 third-party-depscan)

**Does NOT apply to**:

- Icon libraries (`lucide-swift` is approved, runtime dep)
- Image loading libraries (`kean/Nuke` approved in P0, runtime dep — does not affect drag)
- UserDefaults wrappers (`sindresorhus/Defaults` P0 candidate)
- Settings/shortcut wrappers (`sindresorhus/KeyboardShortcuts` P1 candidate)
- Long-form editor libraries (`CodeEditTextView` P2 candidate — replaces the editor view, not the workspace shell)
- Markdown render libraries (`gonzalezreal/Textual` P2 candidate)
- Test tooling (e.g. `ViewInspector` for drag regression tests in v0.28 ticket 028-011)
- Dev tools (`SwiftLintPlugin`, `Brewfile`)

## Rationale

1. **Drag UX ownership**: every drag regression lands in wenshu's test surface (= test fails = ticket blocks) rather than waiting for an upstream maintainer.
2. **Reference sources exist**: hermes (TypeScript/React) + bonsplit source (read-only Swift reference) + Apple SwiftUI `.draggable`/`.dropDestination` API = enough to self-implement correctly.
3. **Cost is bounded**: 1-2 weeks for the recursive renderer + drag-tab-between-pane (= v0.28 ticket 028-004), 1-2 weeks for ZoneEditor (= 028-008).
4. **Reversible**: if self-implementation becomes a maintenance burden, ADR-0008 can be revisited at a later version boundary.

## Consequences

- v0.28 tickets 028-003..028-010 + 028-011 must use zero new runtime view-framework deps.
- `Package.swift` diff for v0.28 = nothing (= `lucide-swift` is the only existing runtime dep).
- Future drag features (drag-from-finder, drag-pdf-into-editor, etc.) follow this ADR.
- `stevengharris/SplitView` and `almonk/bonsplit` are permanently retired from v0.27's revert log.

## Test enforcement

- v0.28 ticket 028-011 = drag-lost regression suite (7 test cases, automated, pre-commit + CI).
- Pre-commit hook (`Tools/wenshu-devtool/hooks/pre-commit`) runs `swift test --filter DragRegressionTests`.
- CI (`.github/workflows/test.yml`) runs the full test suite including drag regression.

## Prior art

- AGENTS.md §11.1 (third-party library policy)
- `.scratch/2026-08-27-third-party-depscan/spec.md` (22-library scan with explicit verdicts)
- v0.27 027-24..027-30 + 027-31 + `eabb0bd6e` revert log
- Boss 2026-08-27 OOB quoted verbatim above
- `manaflow-ai/cmux` issue #2289 (public evidence of bonsplit drag pain)

## When to revisit this ADR

- If wenshu ever needs a feature the self-implemented stack fundamentally cannot deliver (= e.g. multi-monitor cross-display drag, or system-wide drag overlays).
- If a new SwiftUI release ships a built-in API that obsoletes part of the stack (= the drag would then move into Apple framework code, still no third-party).
- If a third-party library ships with > 1000★ + active maintenance + macOS-first + drag-specific benchmark matching Apple stack, propose the change with evidence.