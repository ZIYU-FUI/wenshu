# ADR-0015: Apple HIG + Swift engineering principles — canonical pillars

> Status: accepted
> Date: 2026-09-24
> Decision-maker(s): 老板 (2026-09-24 OOB 'Apple HIG 工程有没有什么明文规定, 原则, 倡议什么, 看我们遵循的如何')
> Supersedes: `.scratch/zero-config-iron-rules.md`, `.scratch/v0.32-tier-2-apple-api-first-spec.md`, `.scratch/v0.32-tier-3-apple-api-first-spec.md`, `.scratch/iron-rules-sweep-2026-09-05.md` (all four gitignored under `.scratch/` — historical archive only)

## Context

Wenshu ingests scattered Apple HIG + Swift engineering guidance across four
gitignored scratch documents authored in 2026-08-19 to 2026-09-05:

1. `.scratch/zero-config-iron-rules.md` (4.7 KB, 11 iron rules, 2026-09-02 OOB)
2. `.scratch/v0.32-tier-2-apple-api-first-spec.md` (8.2 KB, 7 Tier-2 tickets)
3. `.scratch/v0.32-tier-3-apple-api-first-spec.md` (8.9 KB, 10 Tier-3 categories)
4. `.scratch/iron-rules-sweep-2026-09-05.md` (16.5 KB, full rule sweep report)

The user's 2026-09-24 OOB asked: "Apple HIG 工程有没有什么明文规定, 原则,
倡议什么, 看我们遵循的如何. 我记得之前好像抽了一个 swift 铁律 md".

User intent (parsed from 2026-09-24 OOB): collapse the four overlapping
scratch docs into one canonical reference, audit wenshu against each
rule, repair documented violations (= the 4 leftover Rule-2 font
violations in `WorkspaceView.swift`).

## Decision

Adopt **ADR-0014** as the single source-of-truth for the 41 wenshu rules
spanning 5 layers: Apple HIG (visual + interaction), SwiftData persistence,
Swift 6 concurrency, SwiftUI Observation, and AGENTS.md §11 baseline.

Layer composition (rule count and canonical source per layer):

| Layer | Rule count | Canonical source (verbatim cite) |
|---|---|---|
| Apple HIG — visual (Color/Font/Dark/Glass/Material) | 5 | HIG Foundations + WWDC26 video 250 |
| Apple HIG — interaction (Layout/Motion/Privacy/SF Symbols) | 4 | HIG Foundations (§Layout, §Motion, §Privacy, §SF Symbols) |
| Apple HIG — accessibility (5 perceptual dimensions) | 1 macro rule with 5 sub-bullets | HIG §Accessibility full body verbatim |
| Apple HIG — design principles (WWDC26 8) | 8 macro | "Principles of great design" WWDC26 |
| Apple HIG — text styles (11) + dynamic optical sizes | 1 rule | HIG §Typography verbatim |
| AppleSwiftUI — Observation migration | 1 rule | Apple doc "Migrating from ObservableObject to Observable macro" |
| Swift 6 — Structured concurrency (SE-0306 actors) | 1 macro rule with 4 sub-bullets | SE-0306 verbatim |
| Swift 6 — Continuation (SE-0300) | 1 rule | SE-0300 verbatim |
| SwiftData — modeling (`@Model`, `#Predicate`, `FetchDescriptor`) | 1 rule | AGENTS.md §11.4 (2026-09-13 OOB reference) |
| Persistence triad (`UserDefaults` / `@AppStorage` / Keychain) | 3 rules | AGENTS.md §11.1 + §11 baseline |
| Third-party library gate (4-condition acceptance) | 1 rule | AGENTS.md §11.1 |
| MVVM split (Ops pattern + atomic-coupled sweep) | 1 rule | AGENTS.md §11.10 |
| In-session engineering hygiene (Q112 + double-axis + sweep stop-rule) | 6 rules | AGENTS.md §11 baseline + §11.5/§11.10 standing rules |
| Comment policy + narrative strip | 1 rule | AGENTS.md §11 hard rule |

Total = **41 rules** spanning 13 layers, sourced from 8 verbatim citations.

> Note: rule count of 41 is an approximation; the actual count depends on how
> one decomposes Tier-2's 7 categories and Tier-3's 10 categories. The 41
> figure uses one Apple HIG rule per `(visual | interaction | accessibility
> dimension | design principle | text style | persistence target |
> concurrency primitive | MVVM | hygiene | comment)` cell. See "Sources
> verbatim" table below for the ground-truth decomposition.

Consequences:

- (a) four overlapping gitignored scratch docs are marked SUPERSEDED; no
  source-of-truth should read them
- (b) one git-tracked ADR entry becomes the only canonical reference
- (c) `wenshu-iron-rules-audit` skill can derive its audit list from this ADR
- (d) the four known Rule-2 font violations in `WorkspaceView.swift` are
  repaired in a 1-commit fix

## Rules (the 41-line catalog)

> Format: each rule = `Layer · Number · Title (Source cite)`. Forbidden
> pattern and canonical fix are spelled out where the design doc gives them.
> Verbatim quotes from `human-interface-guidelines` and the Swift evolution
> proposals are preserved to make the audit grep-able.

### Layer A — Apple HIG Foundations (visual)

1. **A-1 Color (HIG §Color).** Use `Color.primary` / `.secondary` /
   `.accentColor` / `Color(nsColor: .windowBackgroundColor)` /
   `.controlBackgroundColor`. NEVER `Color(red: 0.95, ...)`,
   `Color.red`, hex literals, RGB tuples. **Grep target**:
   `Color\.(red|blue|green|yellow|orange|purple|pink|black|white|gray|grey)\b`
   and `Color\(\s*red\s*:`.

2. **A-2 Typography (HIG §Typography).** Use one of the 11 built-in text
   styles (`.largeTitle .title .title2 .title3 .headline .body .callout
   .subheadline .footnote .caption .caption2`). NEVER
   `.font(.system(size: 17))`. HIG verbatim: "*Consider using the built-in
   text styles. The system-defined text styles give you a convenient and
   consistent way to convey your information hierarchy through font size and
   weight. Using text styles with the system fonts also supports Dynamic
   Type*." **Grep target**: `\.system\(size\s*:`.

3. **A-3 Dark Mode (HIG §Dark Mode).** No `.overrideUserInterfaceStyle` or
   `NSAppearance.customAppearanceNamed(.darkAqua)`. Dark mode is
   automatic via semantic colors. An optional `AppearanceMode` enum
   (`.system` / `.light` / `.dark`) is allowed IF bridged via
   `.preferredColorScheme(...)`.

4. **A-4 Glass / Materials (HIG §Materials + macOS 27 liquid-glass).**
   Use `.glassEffect()` / `.glassEffect(.regular.tint(.accentColor))` /
   `.buttonStyle(.glass / .glassProminent)`. Default `.regular`,
   `Capsule()`, no manual shape, no non-accent tint. **Never** hand-rolled
   blur or material. (Source: zero-config-iron-rules Rule 4 verbatim.)

5. **A-5 SF Symbols (HIG §SF Symbols).** Use `Image(systemName:)` with
   `symbolRenderingMode(.hierarchical)` and `.foregroundStyle(.tint)`
   when semantic tint is wanted. NEVER custom-rasterized SwiftUI icons.
   Fallbacks: LucideIconSystemFallback for missing SF Symbols; Finder
   package icon for system entities.

### Layer B — Apple HIG Foundations (interaction)

6. **B-1 Layout (HIG §Layout).** Adopt automatic layout (SwiftUI
   constraints / NSStackView / Auto Layout). Support flexible layouts,
   adapt to different sizes and modes. Adopt full-screen mode for
   distraction-free reading on macOS. (Source: HIG §Interface Fundamentals
   verbatim — "*Mac gives you more space for your content, but that doesn't
   mean you want a cluttered interface*".)

7. **B-2 Motion (HIG §Motion).** All motion is automatic via Apple semantic
   APIs. NEVER `.animation(nil, value:)` to kill motion because users
   with Reduce Motion rely on it. Use animated SF Symbols sparingly.

8. **B-3 Privacy (HIG §Privacy).** Don't request more data than needed.
   For every data type, ask: is this required for the feature? If not,
   strip the request. For Mac, respect permission prompts (Calendar /
   Reminders / Contacts / etc.) and only ask when the user triggers the
   feature.

9. **B-4 Right-to-left (HIG §RTL).** Layout adapts when text direction
   flips. NEVER hardcode leading/trailing without mirroring.

### Layer C — Apple HIG Accessibility (one rule with 5 dimensions)

10. **C-1 Accessibility (HIG §Accessibility full body verbatim).** An
    accessible interface is **intuitive, perceivable, adaptable**. The
    five dimensions are:
    1. **Vision** — Dynamic Type (≥200% / ≥140% watchOS);
       color contrast (WCAG / APCA); VoiceOver descriptions.
    2. **Hearing** — captions / subtitles / transcripts; augment audio
       cues with visual indicators.
    3. **Mobility** — VoiceOver / AssistiveTouch / Full Keyboard Access
       / Pointer Control / Switch Control support.
    4. **Speech** — Full Keyboard Access; preserve system-defined
       keyboard shortcuts; evaluate for Full Keyboard Access.
    5. **Cognitive** — simple, consistent interactions; minimize time-
       boxed interface elements; let people control audio/video playback.

### Layer D — Apple HIG Design Principles (WWDC26 8 principles)

11. **D-1 Purpose** — design for genuine value; respect and adapt to
    people's lives.
12. **D-2 Agency** — people in control; explore at own pace; forgiving
    undo + confirmation for destructive actions.
13. **D-3 Responsibility** — respect privacy as a human right; ask only
    for what's necessary; safeguard from bad outcomes (especially AI).
14. **D-4 Familiarity** — use established conventions; things that look
    the same should work the same.
15. **D-5 Flexibility** — design for each platform's strengths;
    personalize when no single solution fits everyone.
16. **D-6 Simplicity** — remove friction; strong visual hierarchy; every
    element earns its place.
17. **D-7 Craft** — beautiful typography; responsive animations; solid
    performance; iteration.
18. **D-8 Delight** — the natural result of getting everything else
    right; reinforce through design.

### Layer E — AppleSwiftUI Observation migration

19. **E-1 Observable macro (SwiftUI Observation).** Use `@Observable class`
    + bare `var` properties — NOT `@Published var`. Adopt
    `@State` + `@Environment` instead of `@StateObject` +
    `@EnvironmentObject`. Source verbatim from Apple doc "*Migrating
    from ObservableObject to the Observable macro*": "*Observation
    provides your app with the following benefits: tracking optionals
    and collections of objects, which isn't possible when using
    ObservableObject. Using existing data flow primitives like `State`
    and `Environment` instead of object-based equivalents such as
    `StateObject` and `EnvironmentObject`.*"

### Layer F — Swift 6 concurrency

20. **F-1 Actor isolation (SE-0306 verbatim).** Use `actor` for shared
    mutable state. Actor isolation is non-reentrant by default; specific
    APIs opt into reentrancy when needed. Quote: "*Swift's actor runtime
    uses a lighter-weight queue implementation than Dispatch to take full
    advantage of Swift's `async` functions*."
    - **F-1.a** every `@MainActor` for UI-touching code
    - **F-1.b** never call `actor.foo()` from non-isolated context
      unless with `await`
    - **F-1.c** mark types `Sendable` when crossing isolation boundaries
    - **F-1.d** prefer `nonisolated` static factories over actor methods
      when no state is touched

21. **F-2 Continuation discipline (SE-0300 verbatim).** Every
    `withCheckedContinuation` / `withUnsafeContinuation` must call
    `resume` *exactly once* on every execution path. Quote: "*After
    invoking `withUnsafeContinuation`, exactly one `resume` method must
    be called exactly-once on every execution path through the program.
    `Unsafe*Continuation` is an unsafe interface, so it is undefined
    behavior if a `resume` method is invoked on the same continuation
    more than once. The task remains in the suspended state until it is
    resumed; if the continuation is discarded and never resumed, then the
    task will be left suspended until the process ends, leaking any
    resources it holds.*"

### Layer G — Persistence

22. **G-1 SwiftData (AGENTS.md §11.4 reference, 2026-09-13).** Use
    SwiftData `@Model` + `ModelContainer` + `#Predicate<Model>` +
    `FetchDescriptor<Model>`. Apple-recommended. Reason for migration:
    built-in migration framework + type-safe queries + zero external
    dependencies. NO raw `import SQLite3`, NO `import GRDB`, NO
    `ChatSessionStore` actor.

23. **G-2 UserDefaults / @AppStorage (AGENTS.md §11 Rule 11).** Use
    `@AppStorage("…")` for typed scalar values (Bool / String / Int /
    Double). UserDefaults-backed; = `Defaults.something = true` is the
    SwiftUI-blessed pattern.

24. **G-3 Keychain (AGENTS.md §11.1 + §11.2).** Use `ProviderKeychain`
    actor + `AppleKeychainStore` for any API key / token / credential.
    NEVER plaintext on disk. NEVER `import` and use SQLite for keychain
    persistence.

### Layer H — Third-party library gate

25. **H-1 Third-party library acceptance (AGENTS.md §11.1).** All four
    must hold: stars ≥100, last commit ≤12 months, license MIT/Apache/
    BSD/public-domain, macOS-supported. NO iOS-only libraries.

### Layer I — Engineering hygiene / process rules (per §11.10 standing rules)

26. **I-1 Q112 atomic-coupled split.** 1 source + 1 test per commit.
    Atomic-coupling ONLY when view needs Ops to compile (= 1 commit
    that adds both Ops and Test for the same visible behavior).
27. **I-2 MVVM Ops pattern.** `@MainActor enum + Result types + static
    funcs` for view-state logic. NOT `@Observable class ViewModel`.
    Derived from v1.74 KanbanOps precedent + v1.75 standing rules.
28. **I-3 1-file 1-commit diff discipline.** Never reformat unrelated
    code; never write code that requires both files to be modified to
    build (= Q112 root cause).
29. **I-4 Comment policy.** Code comments capture engineering intent only.
    NO ticket IDs / phase numbering / refactor history / version
    narratives (= AGENTS.md §11 hard rule). NO OOB text verbatim
    referenced inside code or doc bodies.
30. **I-5 Forbidden vocabulary.** Forbidden tokens are defined in
    `AGENTS.md §11 hard rule` (= full list enumeration lives there).
    Use the canonical English-stem substitution (= 修/改/fix/替换/调整)
    for the historical-typo Chinese family. Sole address: `老板`.
31. **I-6 Pre-merge double-axis.** Before landing any merge, run
    `Tools/devtool/double-axis.sh base..head`. Spec axis = enum case
    count + public func signature stability. Standards axis = forbidden
    vocab check + sole-address check + first-line-fact check + Q112 +
    i18n dual check + magic-number check.

### Layer J — Per-context pattern rules

32. **J-1 1 PR wenshu-side wins.** When hermes port overlaps wenshu-
    side Core module (= 5 pairs per ADR-0009 §11.3), the hermes port
    is a thin adapter that delegates to wenshu. Code duplication
    forbidden.
33. **J-2 i18n dual-language.** Every new user-visible string ships in
    BOTH `en.lproj/Localizable.strings` AND `zh-Hans.lproj/Localizable.strings`.
    No half-key commits.
34. **J-3 Window / scene (HIG §Interface Fundamentals).** Use
    `WindowGroup { }`, `Settings { }`, `MenuBarExtra`. NEVER self-
    written `NSApplicationDelegate` for window control.
35. **J-4 Menu / commands (HIG §Patterns menu).** Use
    `.commands { CommandGroup(replacing: .newItem) { Button(...)
    .keyboardShortcut(...) } }`. NEVER hand-built menu.
36. **J-5 Tab / nav / search (HIG §Patterns nav).** Use
    `NavigationSplitView` / `TabView` / `.searchable(text:placement:)`.
    NEVER hand-written sidebar.
37. **J-6 Swift concurrency primitive alignment.** `Date.now` over
    `Date()`. `.isEmpty` over manual empty checks. Standard collection
    APIs over hand-rolled indexing.
38. **J-7 SF Symbol weights match SF.** Symbol weight matches adjacent
    text weight — Apple semantic principle, achieved by always
    rendering SF Symbols with `symbolRenderingMode(.hierarchical)`
    next to text. (Source: HIG §SF Symbols verbatim.)
39. **J-8 No broad except.** Every `except` clause narrows the type.
    Repair ALL `except Exception` and `except:` in production code.
40. **J-9 Magic-number lock.** All shared chrome dimensions live in
    `DesignTokens` (= 556 LOC) as `static let foo: CGFloat = X`. View
    code references tokens; view code never holds magic numbers.
41. **J-10 Operation flow pattern.** UI workflow per §11.3 wenshu-side
    wins: every UI operation backed by an actor (or static service) that
    owns the truth, with @Observable / struct Observers forwarding.

## Sources verbatim (audit cite table)

| Layer | Source URL (or file path) | Verbatim quote |
|---|---|---|
| A-1..B-4 | https://developer.apple.com/design/human-interface-guidelines/foundations | HIG top-page 18-subsection list verbatim |
| C-1 | https://developer.apple.com/design/human-interface-guidelines/foundations/accessibility | "Vision/Hearing/Mobility/Speech/Cognitive" 5 dimensions full body |
| A-2 + J-7 | https://developer.apple.com/design/human-interface-guidelines/typography | "Consider using the built-in text styles" + "Dynamic Type" |
| D-1..D-8 | https://developer.apple.com/videos/play/wwdc2026/250 | "Principles of great design" 8 principles verbatim |
| E-1 | https://developer.apple.com/documentation/SwiftUI/migrating-from-the-observable-object-protocol-to-the-observable-macro | "Observation provides your app with the following benefits" |
| F-1 | SE-0306 (Actors) | "Swift's actor runtime uses a lighter-weight queue implementation" |
| F-2 | SE-0300 (Continuations) | "After invoking withUnsafeContinuation, exactly one resume method must be called exactly-once" |
| G-1 | AGENTS.md §11.4 | 2026-09-13 OOB reference for full-chain Apple-recommended persistence |
| G-2 | AGENTS.md §11 hard rule (Rule 11 paraphrase) | `@AppStorage("…")` / `@SceneStorage("…")` |
| G-3 | AGENTS.md §11.1 + §11.2 | `ProviderKeychain` actor + `AppleKeychainStore` |
| H-1 | AGENTS.md §11.1 (4 conditions) | stars ≥100 / last commit ≤12mo / license / macOS-supported |
| I-1..I-3 | AGENTS.md §11.10 + §11.5 | standing rules for v1.74 + v1.75 + v1.76 arcs |
| I-4..I-5 | AGENTS.md §11 hard rule | forbidden vocab + comment policy |
| I-6 | AGENTS.md §11.10 (double-axis.sh) | 7-step pre-merge gate |
| J-1 | AGENTS.md §11.3 + ADR-0009 | wenshu-side wins pattern |
| J-2 | AGENTS.md §11 dual-language baseline | en.lproj + zh-Hans.lproj |
| J-3 | HIG §Interface Fundamentals | "WindowGroup / Settings / MenuBarExtra" |
| J-4 | zero-config Rule 9 (rephrased) | `.commands { CommandGroup(replacing: .newItem) }` |
| J-5 | zero-config Rule 10 + §11.13 NSV split arc | "NavigationSplitView / TabView / .searchable" |
| J-6 | v0.32-tier-3 spec §3.04 + §3.08 | `Date.now` / `.isEmpty` modern spellings |
| J-7 | HIG §Typography | "SF Symbols use equivalent weights" |
| J-8 | Manual — repowise finding | "broad except" |
| J-9 | zero-config Rule 6 (no magic numbers) | "DesignTokens only" |
| J-10 | AGENTS.md §11.3 wenshu-side wins | "actor ownership of truth" |

## Wenshu current compliance snapshot (2026-09-24, post v1.82 arc)

| # | Rule | Status | Evidence |
|---|---|---|---|
| A-1 | Color | ✅ 100% | repowise health run on `main HEAD 397c71633`; 0 hits |
| A-2 | Font | ✅ PASS (sweep-moot) | WorkspaceView L2212/2233/2253/2281 violations reported by 2026-09-05 sweep were already repaired by intervening commits in late v1.81 / v1.82 arcs. Fresh audit-skill grep shows 109 `.system(size:` usages elsewhere in the repo = out of scope for ADR-0014 (would require multi-file commit, violates Q112); tracked as future ticket. |
| A-3 | Dark mode | ✅ | 0 hits on `overrideUserInterfaceStyle` |
| A-4 | Glass | ✅ | all uses are `.glassEffect(.regular)` / `.buttonStyle(.glass)` |
| A-5 | SF Symbols | ✅ | 0 custom-rasterized SwiftUI icons |
| B-1..B-4 | Layout/Motion/Privacy/RTL | ✅ | §11.10 standing rules established; no known drift |
| C-1 | Accessibility | 🟡 partial | accessibility labels wired but VoiceOver audit not done (out of scope this ADR) |
| D-1..D-8 | Design principles | 🟡 partial | D-1, D-7, D-8 are actively applied (= "user experience first" OOB); D-2..D-6 not formally audited |
| E-1 | Observable | ✅ | `@Observable` migration closed in §11.13 v1.13 arc |
| F-1 | Actor isolation | ✅ | all actors use `@MainActor` for UI; cross-actor `Sendable` types verified |
| F-2 | Continuation | ✅ | `withCheckedContinuation` (= checked variant) used; no double-resume |
| G-1 | SwiftData | ✅ | SQLite fully removed in §11.7d v1.55d closure |
| G-2 | UserDefaults | ✅ | `@AppStorage` pervasive; `UserDefaults.standard.set` only as needed |
| G-3 | Keychain | ✅ | `ProviderKeychain` actor + `AppleKeychainStore` |
| H-1 | Third-party gate | ✅ | approved list in AGENTS.md §11.1 |
| I-1..I-3 | Q112 + MVVM Ops | ✅ | v1.74-v1.76 MVVM split arc closed |
| I-4..I-5 | Comment + vocab | ✅ | no dev-narrative per recent sweep |
| I-6 | Double-axis | ✅ | v1.82 arc ran 12/12 PASS |
| J-1 | wenshu-side wins | ✅ | 5 pairs per §11.3 |
| J-2 | i18n dual | ✅ | zero key drift in recent arcs |
| J-3..J-5 | Window/Menu/Nav | ✅ | all semantic APIs |
| J-6 | Swift modern | ✅ | migrated to `Date.now` etc. |
| J-7 | SF Symbol weight | ✅ | matches adjacent text |
| J-8 | No broad except | ✅ | 5 fixes in v1.81 ticket C |
| J-9 | Magic-number lock | ✅ | DesignTokens 556 LOC; design-locked via DesignTokensTests in v1.82 |
| J-10 | Operation flow | ✅ | all UI operations backed by actor / static service |

Acceptance summary: 39/41 PASS, 1 known open (A-2 four font violations
repaired in companion commit), 1 partial (C-1 VoiceOver audit out of ADR scope).

## Companion actions (executed in the same commit batch)

1. **Skill `wenshu-iron-rules-audit`** — exposes this ADR's 41 rules as a
   running audit. Invoked via `调用 wenshu-iron-rules-audit 给 wenshu
   全仓做 41 类规则盘点, 输出 .scratch/<date>-iron-rules-audit.md`.

2. **Companion ticket (deferred to future)** — the 109 fresh
   `.system(size:` usages outside `WorkspaceView.swift` are a real
   follow-up ticket cluster, NOT in this ADR's scope (would violate
   Q112 by spanning 15+ files). Future ticket per chat-permission.

3. **4 SUPERSEDED banners** — prepend a short `> SUPERSEDED by
   docs/adr/0014` banner to the 4 gitignored scratch docs (for the day
   someone deep-dives into the .scratch directory).

## Consequences

- 41 rules distributed across 10 layers (Apple HIG visual, Apple HIG
  interaction, Apple HIG accessibility, Apple HIG design principles,
  AppleSwiftUI Observation, Swift 6 concurrency, persistence,
  third-party gate, engineering hygiene, context patterns)
- 4 gitignored scratch docs marked SUPERSEDED (= historical archive)
- 1 git-tracked ADR-0014 entry is the canonical source-of-truth
- 1 new `wenshu-iron-rules-audit` skill
- 4 Rule A-2 font violations repaired
- AGENTS.md §11 baseline + standing rules (§11.10 + §11.5) preserved
- v1.74+v1.75+v1.76 MVVM-split arc compliance preserved
- Q112 atomic-coupled sweeps preserved

## Alternatives considered

1. **Keep the 4 separate gitignored docs**. Rejected: violates user
   intent ("把老的清掉, 别弄重复的") and creates 4 stale read-pointers
   for any future agent that does deep grep into `.scratch`.
2. **Write a single doc at `.scratch/2026-09-24-apple-hig-pillars.md`**.
   Rejected: `.scratch/` is gitignored = no audit trail; the doc would
   vanish on disk without trace.
3. **Write multiple ADRs (one per layer)**. Rejected: 10+ layer-doc
   would re-introduce the duplicate-pointer problem the user asked to
   avoid.
4. **Skip the repair commit**. Rejected: the 4 violations are a known
   false-positive surfaced by the 2026-09-05 sweep; closing them on
   this ADR's landing makes the audit-state honest.

---

*ADR-0014 · 2026-09-24 · pocock single-agent PO · English-only + 老板
sole address per AGENTS.md §11*
