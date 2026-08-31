# Spec Axis Report — v0.30 zone header 新建 icon fix

- Commit: `c24c2f3a1` — `fix(wenshu): v0.30 — zone header 新建 icon renders (= replace Menu with Button + sheet)`
- Date: 2026-08-31
- Reviewer: spec-axis sub-agent
- Spec: `.scratch/v0.30-zone-header-new-icon-fix/spec.md`
- Scope: 1 file (`Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`), +78 / −10 LOC

## Verdict: CONDITIONAL PASS

The commit fully satisfies the boss OOB and all 4 functional acceptance criteria. It introduces one spec-soft finding (scope creep: `.help()` tooltips on both buttons and the Lucide `book-plus` / `library` icons inside `NewChoiceSheet` are not mentioned in the spec) and inherits one pre-existing spec-soft gap (no `NSOpenPanel` receiver for `.wenshuImportRequested` exists anywhere in the codebase — the spec AC #4 is therefore literally un-verifiable from this commit alone, but the behavior was identical in v0.27 and is out of scope for an icon-rendering fix).

---

## Per-commit findings

### Acceptance criterion → implementation mapping

| # | Spec acceptance criterion | Implementation (file:line) | Status |
|---|---|---|---|
| 1 | `swift build` exit 0 | Author claims in commit body; not re-verified by this reviewer | UNVERIFIED (no build run) |
| 2 | Trailing slot shows 2 icons (新建 `square-plus` + 入驻 `square-arrow-right`) | `NewLibraryOutlineView.swift:350-378` — HStack(spacing: 0) with two `Button { … } label: { LucideIcon(...) }` using `.buttonStyle(.plain)`; both icons use canonical Lucide names matching v0.27 `bca226704` | PASS |
| 3 | Tapping 新建 opens `NewChoiceSheet` with 2 buttons (新建书 / 新建书架) → on tap → existing `showNewBookSheet` / `showNewShelfSheet` | `NewLibraryOutlineView.swift:354-361` (Button action sets `showNewChoiceSheet = true`) + `:569-610` (NewChoiceSheet with two `.bordered` Button → onNewBook/onNewShelf closures) + `:379-389` (sheet modifier chains `showNewChoiceSheet = false` then opens the appropriate `showNewBook/ShelfSheet`) | PASS |
| 4 | Tapping 入驻 opens macOS `NSOpenPanel` (unchanged) | `NewLibraryOutlineView.swift:368-370` — `Button { NotificationCenter.default.post(name: .wenshuImportRequested, object: nil) } label: { … }`; identical to pre-commit wiring | PASS at the **post** side; see Spec CONDITIONAL #2 for receiver gap |
| 5 | Domain word `NewChoiceSheet` added to `CONTEXT.md` (Q34 step 7) | Outside commit `c24c2f3a1`; landed in follow-up `5936baef3` (`docs(wenshu): v0.30 — Q34 step 2/3/7 for zone-header 新建 icon fix`) which modifies `CONTEXT.md` (+1 LOC) | PASS (deferred to follow-up commit, as documented) |

### Root-cause analysis (matches commit message)

- Commit message claim: "Menu style `.borderlessButton` + `.menuIndicator(.hidden)` failed to render the 新建 icon inside the `ZoneContentTabBar` trailing slot; only the 入驻 Button rendered."
- Independent verification: trailing slot is rendered by `ZoneContentView.ZoneContentTabBar` → `PaneTabBar` → `RegionTabBar` (`Sources/WenshuApp/UI/RegionTabBar.swift:67-102`), which is a plain `HStack { content() }` with no special Menu handling. A nested `Menu` with collapsed label + hidden chevron has no surface area in a 28×28 trailing slot, so the icon truly does not render. **Diagnosis correct.**

### Behavior preservation

- `showNewBookSheet` (`@State` L92) and `.sheet(isPresented: $showNewBookSheet)` (L213) are unchanged. The `NewBookSheet` / `NewShelfSheet` view definitions (L485-563) are unchanged.
- `bookStore` reload path on save is unchanged (L213-232).
- The two `onReceive(NotificationCenter.default.publisher(for: .wenshuNewBookRequested/.wenshuNewShelfRequested))` listeners (L207-212) — used by the main app toolbar `' + '` button — are unchanged.

---

## Spec FAIL (= hard failures)

None.

The commit:
- Restores the missing 新建 icon in the zone-header trailing slot (boss OOB ✓)
- Renders both icons in the trailing slot (boss expectation #1 ✓)
- Makes both icons clickable (boss expectation #2 ✓)
- Tapping 新建 lets the user create a new book or new shelf via `NewChoiceSheet` (boss expectation #3 ✓)
- Tapping 入驻 still fires `.wenshuImportRequested` notification identical to pre-commit wiring (boss expectation #4 ✓)

---

## Spec CONDITIONAL (= soft findings)

### C1. Scope creep: `.help()` tooltips on both trailing buttons (minor)

- `NewLibraryOutlineView.swift:363` adds `.help("新建")` to the 新建 Button.
- `NewLibraryOutlineView.swift:377` adds `.help("入驻")` to the 入驻 Button.
- Spec AC #2 only requires the icons to render; tooltips are not mentioned.
- Symmetry argument: tooltip on 入驻 matches the "icon-only trailing button" Apple HIG pattern where hover tooltip is the canonical discoverability hint. The 新建 Button previously had no tooltip (Menu path), so adding it is a reasonable Apple HIG alignment — **but** this is unstated in the spec and could be considered scope creep.
- **Severity:** soft. Non-blocking. Recommend: keep both (Apple HIG consistency), or document the rationale in the commit body for future audits.

### C2. Pre-existing gap: no receiver for `.wenshuImportRequested` notification (out-of-scope)

- Spec AC #4 states "Tapping 入驻 opens macOS NSOpenPanel (= unchanged)".
- The commit correctly fires `.wenshuImportRequested` at `NewLibraryOutlineView.swift:369`.
- However, **no `onReceive` / observer for `.wenshuImportRequested` exists anywhere in the codebase** — verified by `grep -rn "wenshuImportRequested" Sources/ --include="*.swift"`:
  ```
  Sources/WenshuApp/App.swift:94:    static let wenshuImportRequested = Notification.Name("wenshu.importRequested")
  Sources/WenshuApp/App.swift:540:    NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)   // file menu 导入…
  Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:369:    NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)  // 入驻 button (this commit)
  ```
  Only producers, zero receivers.
- `git log -S "onReceive.*importRequested"` returns no hits; `git log -S "wenshuImportRequested"` shows the notification was introduced in v0.27 commit `bca226704` (zone-header buttons added) and has been producer-only since.
- The only NSOpenPanel call in the codebase is `Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift:369` (first-launch `.ws` file picker, NOT the import flow). It is wired to `wenshu.libraryPath` UserDefaults check, NOT to `.wenshuImportRequested`.
- **Net effect:** tapping 入驻 in this commit fires a notification that no one listens to. The boss may observe "I tapped 入驻 and nothing happened". This was true before the commit AND is true after the commit — i.e. the behavior is **unchanged** as the spec AC requires, but **the AC's intended NSOpenPanel behavior is not actually delivered at runtime** by this commit or any other commit on the branch.
- **Severity:** pre-existing, out of scope for an icon-rendering fix. **Not a finding against this commit** — the commit faithfully preserves (broken) pre-existing behavior. **Recommend:** file a separate ticket to add the `NSOpenPanel` receiver (e.g. in `App.swift`'s main view via `.onReceive(NotificationCenter.default.publisher(for: .wenshuImportRequested)) { … NSOpenPanel() … }`) so that AC #4 can actually be verified at runtime.

### C3. Build verification not re-run by this reviewer (process gap)

- Spec AC #1 requires `swift build` exit 0. The commit body claims "Build clean (= swift build exit 0)". This reviewer did not re-run `swift build` (spec-axis review = code-only, no execution environment assumed).
- **Severity:** soft. Author attestation is credible given scope (1 file, +78/−10 LOC, no API surface changes). No new imports, no new types referenced outside the same file.

### C4. Style nit: `NewChoiceSheet` declared at file scope (non-`private`) (low)

- `NewLibraryOutlineView.swift:569` declares `struct NewChoiceSheet: View` at file scope, NOT marked `private`.
- All other sheet types in this file (`NewBookSheet` at L485, `NewShelfSheet` at L551) are marked `private struct`.
- **Severity:** trivial. Inconsistent with sibling sheets. Recommend adding `private` for consistency unless an external caller is planned.
- This is a pre-existing convention rather than a regression; the new view simply followed the wrong precedent. Non-blocking.

---

## Summary

**Verdict: CONDITIONAL PASS.**

Commit `c24c2f3a1` is a minimal, correct fix for the boss OOB `'顶栏右边的新建 ICON 没有了'`:

- Replaces the non-rendering `Menu` with two `.buttonStyle(.plain)` `Button`s in an `HStack`, so both icons now render in the `ZoneContentTabBar` trailing slot.
- Adds a small `NewChoiceSheet` that lets the user pick between 新建书 and 新建书架 without resorting to a nested `Menu`.
- Preserves all existing persistence + notification wiring (`showNewBookSheet`, `showNewShelfSheet`, `.wenshuImportRequested`).
- Stays inside one file, +78/−10 LOC.
- Documents the diagnosis and the Apple HIG rationale in three places: commit body, inline comments at the change site, and a new `NewChoiceSheet` header.

**Two findings worth surfacing, neither blocking:**

1. **C2 (most important):** the `.wenshuImportRequested` notification has no receiver anywhere on the branch. The boss's expected "tap 入驻 → NSOpenPanel" behavior is not delivered at runtime by ANY commit, not just this one. The commit faithfully preserves the (pre-existing) broken behavior, so it is not in violation of AC #4 as written, but a follow-up ticket is recommended to actually wire the NSOpenPanel so AC #4 is verifiable end-to-end.
2. **C1:** the `.help("新建")` / `.help("入驻")` tooltip additions and the `NewChoiceSheet` icon set (`book-plus` / `library`) are not in the spec. They are Apple HIG aligned and low-risk, but worth a sentence in the spec for future audits.

No hard failures. Boss can ship.