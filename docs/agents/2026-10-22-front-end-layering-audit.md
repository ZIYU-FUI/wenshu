# Front-end layering audit and flattening plan

Date: 2026-10-22
Base commit: `bdec990f6` (main)
Method: three purpose-built measurement scripts (comments and string literals
stripped before parsing, so a type-name grep does not inflate the numbers),
plus one cited research pass over Apple HIG, Apple Developer Documentation
(DocC endpoints), Apple's sample apps, and the Keynote user guide.

Every number below is measured from the tree at the base commit. Every path
carries a line number.

---

## 1. What "one parameter travels 11 layers" means, measured

The claim is correct, and it is worth being precise about WHICH path.

The deepest chain in the whole app layer is the chat zone, and it has
**11 frames from the window root to one rendered text part**:

| # | Frame | File:line |
| - | ----- | --------- |
| 1 | `AppRootScene` (the `WindowGroup` scene) | `Sources/WenshuApp/App/AppRootScene.swift:48` |
| 2 | `LibraryRootView` (the `NavigationSplitView` detail closure) | `Sources/WenshuApp/Shared/UI/LibraryRootView.swift:145` |
| 3 | `EditorChatSplitHost` (the `NSViewControllerRepresentable`) | `Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift:415` |
| 4 | `EditorChatNSController` (the `NSSplitViewController`) | `Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift:228` |
| 5 | `ChatZoneView` (the SwiftUI re-entry, hosted by `NSHostingController`) | `Sources/WenshuApp/Features/Chat/View/ChatZoneView.swift:113` |
| 6 | `ChatView` (the transcript) | `Sources/WenshuApp/Features/Chat/View/ChatView.swift:147` |
| 7 | `ChatMessageView` (one row) | `Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift:347` |
| 8 | `ChatMessageBodyView` (the bubble body) | `Sources/WenshuApp/Features/Chat/View/ChatPartView.swift:99` |
| 9 | `ChatPartRow` (the per-part dispatcher) | `Sources/WenshuApp/Features/Chat/View/ChatPartView.swift:92` |
| 10 | `ChatTextPartView` (the leaf renderer) | `Sources/WenshuApp/Features/Chat/View/ChatTextPartView.swift:34` |
| 11 | the rendered text itself | — |

**The critical distinction: frames ≠ parameter drilling.** The chat tree
carries **three** values through the chain, and only two of them are drilled:

| Value | Levels crossed | Dead? |
| ----- | -------------- | ----- |
| `message` | 3 (`ChatMessageView` → `ChatMessageBodyView` → `ChatPartRow`) | live |
| `isOutgoing` | 4 (`ChatMessageView` → `ChatMessageBodyView` → `ChatPartRow` → `ChatTextPartView`) | **dead in the leaf** |
| `isStreaming` | 3 (`ChatMessageView` → `ChatMessageBodyView` → `ChatPartRow` → `ChatTextPartView`) | live |
| `onApprovePlan` | 3 (`ChatMessageView` → `ChatMessageBodyView` → `ChatPartRow` → `ChatPlanPartView`) | live |
| `activity` | 2 (`ChatMessageBodyView` → `ChatPartRow` → `ChatReasoningPartView`) | live |

So the deepest **parameter** drill in the app layer is **4 levels**, and the
**frame** count is **11**. The gap between the two is the finding: most of
the 11 frames are *structural* (a split view, a hosting controller, a
transcript), not *dependency* frames.

**The real cost is edit fan-out, not depth.** `isOutgoing` is declared in
**7 view structs across 6 files**:

- `ChatMessageView.swift` (`UserGlassCardModifier`)
- `ChatPartView.swift` (`ChatMessageBodyView`, `ChatPartRow`)
- `ChatTextPartView.swift`
- `ChatToolResultPartView.swift`
- `ChatToolUsePartView.swift`
- `ChatTraceTextView.swift`

Adding one field to the chat bubble means editing 7 files. That is the
number that matters, and it is what Apple names in its own guidance.

---

## 2. Apple canonical: what the reference projects actually do

### 2.1 Keynote's presenter notes

Apple's HIG states the architecture directly:

> "Keynote in macOS uses split view panes to present the slide navigator, the
> presenter notes, and the inspector pane in areas that surround the main slide
> canvas."
> — https://developer.apple.com/design/human-interface-guidelines/split-views

> "in Keynote, people can hide the navigator and presenter notes panes when they
> want to edit slide content."
> — same page

**The transferable rule: the notes pane is a SIBLING of the canvas, not a
child of it.** Keynote's notes pane never receives the slide through the
canvas. Both panes resolve against one shared selection.

The editing gesture is an edit-and-commit, not a live binding: "double-click in
the Notes field, then start typing. Click Done when you've finished."
(https://support.apple.com/guide/keynote/tan1cb6ca7a3/mac)

**Wenshu already implements Keynote's shape.** `EditorChatNSController` is an
`NSSplitViewController` with a collapsible chat pane and an autosaving divider
(`Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift:14-58`).
The structural half of the problem is already Apple-canonical.

### 2.2 Apple's explicit rule against drilling

> "If you have a data model object, like `Library`, that you want to share
> throughout your app, you can either: **pass the data model object to each
> view in the view hierarchy; or add the data model object to the view's
> environment.** Passing model data to each view is convenient when you have a
> shallow view hierarchy... **However, you usually don't know if a view needs
> to pass the object to subviews, and you may not know if a subview deep
> inside the layers of the hierarchy needs the model data.**"
> — https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app

That is the failure mode named, in Apple's own words, for a 4-to-11 level drill.

### 2.3 The four reference implementations

| Project | Selection payload | Model delivery | Custom values |
| ------- | ----------------- | -------------- | ------------- |
| **Backyard Birds** (WWDC23) | `AppScreen` enum | `@Query` in the leaves | `EnvironmentKey` + `EnvironmentValues` |
| **Food Truck** (WWDC22) | `Panel` enum | drilled **1** level (legacy) | `.environmentObject` |
| **Fruta** | — | `.environmentObject` at the root | — |
| **IceCubesApp** (~7.1k stars) | `RouterDestination` enum | `.environment(obj)` at the root | the `@Entry` macro |

In **all four**, the selection is a small `Hashable` value and the model is
delivered by the environment, never as a chain of initializer parameters.

**Backyard Birds** is the cleanest reference and the one to copy:
`BackyardGrid` reads `@Environment(\.passStatus)` with **zero parameters**,
and `BackyardNavigationStack` uses `@Query` and resolves by ID inside
`navigationDestination(for:)` — the array is never passed down.
(https://github.com/apple/sample-backyard-birds)

**IceCubesApp** is the scaled-up version: one `withAppDependencyGraph(...)`
modifier at the `WindowGroup` root injects a dozen `@Observable` singletons;
`StatusDetailView` opens with five `@Environment` reads and **no parameters**.

**Fruta** shows the shape in its smallest form: `ContentView()` takes **zero
arguments**; the model is injected at the root and consumed by the leaves.

**Food Truck is the honest counter-example**: it still drills the app model
exactly one level (`DetailColumn(selection: $selection, model: model)`). It
flattens the *navigation*, not the model. That one level is the thing to beat.

### 2.4 The Apple API surface

- `@Observable` + `.environment(_:)` + `@Environment(Type.self)` —
  https://developer.apple.com/documentation/swiftui/view/environment(_:)
- `EnvironmentKey` / `EnvironmentValues` / the `@Entry` macro —
  https://developer.apple.com/documentation/swiftui/entry()
- `NavigationSplitView` with one selection binding —
  https://developer.apple.com/documentation/swiftui/navigationsplitview
- `inspector(isPresented:content:)` — the trailing panel that reads the
  selection itself. (There is **no** `inspector(_:)` overload; that slug 404s
  on Apple's docs server.)
- `NSSplitViewController` + `NSSplitViewItem.canCollapse` + `NSHostingController`
  — the AppKit-native split, already in use in this repo.

---

## 3. Measured violations in this repo

### 3.1 Eight init parameters were checked; six are threaded but never read

Verified by parsing every stored property in every view struct, then reading
the whole type INCLUDING its extensions in the same file, then checking each
candidate by hand with `grep`.

| Dead parameter | Declared | Read count | Note |
| -------------- | -------- | ---------- | ---- |
| `ChatTextPartView.isOutgoing` | `Features/Chat/View/ChatTextPartView.swift:36` | 0 | the value reaches the leaf and is dropped |
| `AssetsPane.appState` | `Features/Editor/View/AssetsPane.swift:15` | 0 | the view already has `@Bindable envAppState`; the call site passes the SAME object twice (`Shared/UI/LibraryRootView.swift:132-134`) |
| `EditorEditContent.onSave` | `Features/Editor/View/EditorEditContent.swift:42` | 0 | the comment claims it surfaces dirty status, but nothing calls it; the editor's real save path is the auto-save `onDirtyChange` |
| `EditorFormatToolbar.onClose` | `Features/Editor/View/EditorFormatToolbar.swift:164` | 1 | **live** — read at `:257` inside an extension. Not a violation. |
| `NewBookSheet.targetShelfName` | `Features/Library/View/SidebarSheets.swift:270` | 0 | |
| `RenameItemSheet.kind` | `Features/Library/View/SidebarSheets.swift:431` | 0 | |
| `KanbanWindow.library` | `Features/Kanban/View/KanbanWindow.swift:54` | 0 | the view needs the library PATH, and reads it from the `wenshu.libraryPath` UserDefaults key via `resolveLibraryPath()`; the handle itself is unused |
| `PreviewPane.onDoubleClick` | `Features/Editor/View/PreviewPane.swift:45` | 0 in-file | **live** — read from `PreviewPaneGrids.swift`, an extension in another file. Not a violation. |

**Net: 6 genuinely dead parameters**, plus 2 false positives the detector
produced and hand-verification killed.

A seventh was found LATER, by the tool this wave added
(`Tools/wenshu-devtool/measure-drill.py`), and the first detector MISSED
it: `WizardStepNavBar.currentStep`
(`Features/Agent/View/ImportSheetViewPieces.swift:414`). It is a
`@Binding var`, and a property wrapper's storage is not a plain stored
property, so the first parser did not classify it as a parameter at all.
The tool reads the whole type INCLUDING its extensions, and reports it
with 0 reads. The struct spans lines 413 to 449 and the identifier
appears exactly once in it: the declaration. The nav bar draws a Back
button, a Next button and the primary action; none depends on which step
is current.

**That is the lesson this section earns.** A detector that only knows
about plain stored properties finds the easy cases and misses the ones
that need a wrapper. The measurement had to become a command, with its
own test suite, before it could be trusted on the cases it had never
been shown.

### 3.2 The view layer has zero custom environment values

`grep -rn "EnvironmentKey" Sources/` returns **0 hits**. There is no
`EnvironmentValues` extension anywhere in the app.

This is not a missing feature so much as a missing decision. The repo has
two established mechanisms already:

- **`.environment(object)` + `@Environment(Type.self)`** — used at the root
  (`AppRootScene.swift:49-53`) and re-injected across the AppKit boundary
  (`EditorChatNSController.swift:473-475`).
- **`@Environment(\.openWindow)` / `@Environment(\.openSettings)`** — SwiftUI
  built-in key-path values.

`v1.45-deeper-architecture` (`.scratch/v1.45-deeper-architecture/spec.md`,
2026-10-15) proposed an `EnvironmentKeys.swift` skeleton. It was built
(`7baf6cb8a`) and then deleted (`c6900270f`, "drop the three unreferenced
wenshu surfaces") because a key with zero readers is dead code by rule 7.6.
**That is the trap this plan must avoid: a key that no view reads is not a
refactor, it is dead code.**

### 3.3 The AppKit boundary is where the drilling is forced

`EditorChatNSController` hosts two `NSHostingController`s, and the SwiftUI
`@Environment` chain does not cross into them. The repo handles this by
threading `appState`, `bookStore` and `library` by hand through
`EditorChatSplitHost` → `EditorChatNSController` → `NSHostingController`,
then re-injecting with `.environment(...)`.

That is 3 objects × 3 levels = 9 hand-carried values, for a boundary that
exists only because `NSSplitViewItem.canCollapse` has no SwiftUI equivalent.
The re-injection is correct; the hand-carriage above it is the waste.

### 3.4 The heaviest initializers in the app layer

Measured at the construction site (the number of arguments a caller must
supply), not at the declaration:

| View | Args | Site |
| ---- | ---- | ---- |
| `ExportFileExporters` | 13 | `Features/Library/View/ExportSheet.swift:302` |
| `EditorEditContent` | 12 | `Features/Editor/View/EditorEditContent.swift:39` |
| `WenshuMarkdownEditor` | 8 | `Features/Editor/Model/WenshuMarkdownEditor.swift:9` |
| `ChatInputBarView` | 6 | `Features/Chat/View/ChatInputBarView.swift:66` |
| `WizardStepNavBar` | 6 | `Features/Agent/View/ImportSheetViewPieces.swift:413` |

`SettingView` and `EditorView` looked like the worst offenders (37 and 23
properties) and are **not** — they hold their state in `@Environment` /
`@AppStorage` already and expose 1 and 0 initializer parameters.

---

## 4. The plan

Six cards, ordered by the ratio of measured harm to blast radius. Each is
one commit, one worktree, one mergeable change. **None of them changes what
the app looks like** — that constraint is in every card body.

| # | Card | What it does | Files |
| - | ---- | ------------ | ----- |
| 1 | Remove the 5 dead initializer parameters | Deletes parameters that are declared and threaded but never read. Pure deletion; zero visual change. | 5 files across 4 features |
| 2 | Collapse the chat bubble's parameter chain | Removes the `isOutgoing` drill (4 levels → 0) and the `activity` relay, by deriving what is derivable and passing what is not, one level less. | Chat zone, 6 files |
| 3 | Introduce one environment value for the chat bubble context | The Apple `EnvironmentKey` pattern, WITH readers in the same commit. | Chat zone |
| 4 | Stop hand-carrying state across the AppKit boundary | Bundle the 3 re-injected objects so the boundary carries 1 value instead of 3. | Editor chat host, 2 files |
| 5 | Add the measurement script to the repo | Makes the next audit a command, not a project. | 1 new script + 1 registry row |
| 6 | Remove the 2 dead parameters the tool then found | `KanbanWindow.library` and `WizardStepNavBar.currentStep`, the second of which the first detector had missed because it is a `@Binding`. | 4 files |

**Card 3 was executed as two cards, not one, and it introduced no key.**
The plan assumed the chat bubble would need ONE environment value to
carry what survives the collapse. It does not: `isOutgoing` and the
`activity` list are both DERIVABLE from the message, so deriving them at
the point of use removed the need for a key entirely. An
`EnvironmentKey` with no reader is dead code by rule 7.6 — which is
exactly how `7baf6cb8a` died, the key this repo built and then deleted
because nothing read it. So the chat zone took TWO commits (one per
derivation) and no key.

The environment pattern landed where it was actually needed: at the
AppKit boundary, where the SwiftUI environment genuinely does not reach.
That boundary now carries one bundled value instead of three objects
threaded through three levels.

### Why card 2 comes before card 3

Card 2 is a **pure refactor with no new machinery**: `isOutgoing` is already
derivable from `message.source == .user` (that is literally how
`ChatMessageView` computes it at `ChatMessageView.swift:429`), and `activity`
is already derived from `message.parts` at `ChatPartView.swift:120`. Card 3
then introduces the environment value for whatever genuinely still needs
crossing. Doing 3 first would create a key whose only reader is a parameter
that card 2 was about to delete — which is exactly how `7baf6cb8a` died.

### What card 2 must NOT do

- It must not change the rendered output. `ChatTextPartView` and
  `ChatToolUsePartView` / `ChatToolResultPartView` use `isOutgoing` for the
  bubble fill, so any replacement must produce the identical colour.
- It must not delete `ChatPartRow` as a type. It is `private`
  (`ChatPartView.swift:127`) and the four fade-in tests count its
  transitions by slicing its source text
  (`Tests/WenshuAppTests/Chat/View/ChatPartViewToolUseFadeInTests.swift:70-80`).
- The `onApprovePlan` chain must keep working: the plan card's Approve
  button calls it, and
  `Tests/WenshuAppTests/Chat/View/ChatMessageViewPlanApproveTests.swift`
  asserts the literal strings `onApprovePlan: onApprovePlan` and
  `onApprovePlan: { plan in`.

---

## 5. Sources

**Apple HIG**

- Split views — https://developer.apple.com/design/human-interface-guidelines/split-views
- Layout — https://developer.apple.com/design/human-interface-guidelines/layout
- Designing for macOS — https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- Panels — https://developer.apple.com/design/human-interface-guidelines/panels

**Apple Developer Documentation**

- Managing model data in your app — https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- `environment(_:)` — https://developer.apple.com/documentation/swiftui/view/environment(_:)
- `EnvironmentValues` — https://developer.apple.com/documentation/swiftui/environmentvalues
- `EnvironmentKey` — https://developer.apple.com/documentation/swiftui/environmentkey
- `@Entry` — https://developer.apple.com/documentation/swiftui/entry()
- `NavigationSplitView` — https://developer.apple.com/documentation/swiftui/navigationsplitview
- `inspector(isPresented:content:)` — https://developer.apple.com/documentation/swiftui/view/inspector(ispresented:content:)
- `NSSplitViewController` — https://developer.apple.com/documentation/appkit/nssplitviewcontroller
- `NSSplitViewItem.canCollapse` — https://developer.apple.com/documentation/appkit/nssplitviewitem/cancollapse
- `Table` — https://developer.apple.com/documentation/swiftui/table
- `@Query` — https://developer.apple.com/documentation/swiftdata/query
- `NSViewControllerRepresentable` — https://developer.apple.com/documentation/swiftui/nsviewcontrollerrepresentable

**Apple Support (Keynote)**

- Add and view presenter notes — https://support.apple.com/guide/keynote/add-and-view-presenter-notes-tand1a4ee7c/mac
- Play a presentation on a separate display — https://support.apple.com/guide/keynote/present-on-a-separate-display-tana4da2681/mac
- Rehearse a presentation — https://support.apple.com/guide/keynote/tan1cb6ca7a3/mac
- Use the presenter display — https://support.apple.com/guide/keynote-icloud/use-the-presenter-display-gil4b2d2623a/icloud

**Reference implementations**

- Backyard Birds — https://github.com/apple/sample-backyard-birds
- Food Truck — https://github.com/apple/sample-food-truck
- Fruta — https://developer.apple.com/documentation/appclip/fruta-building-a-feature-rich-app-with-swiftui
- IceCubesApp — https://github.com/Dimillian/IceCubesApp

**Not verified, stated plainly**

- Keynote's internal presenter-notes binding mechanism. Keynote is closed
  source and is not installed on this machine, so no claim is made about
  whether it uses a SwiftUI `Binding`, an `NSTextViewDelegate`, or an
  Observation-driven read.
- The class and selector names inside Keynote's presenter display.
- `inspector(_:)` as a distinct overload does not exist; Apple's symbol is
  `inspector(isPresented:content:)`.

---

## 6. Method note

The three measurement scripts live outside the repository, in the session's
scratch directory, because a script that measures a moving tree belongs with
the thing it measures (card 5 moves it into the repo). They strip comments
and string literals before parsing, so a docblock that mentions a type name
does not count as a dependency. Every finding in section 3 was then
re-verified by hand with `grep` before it was written down; two of the
script's own findings were killed by that check.

---

## 7. Outcome

All six cards landed on `main`. Each is one commit, each in its own
worktree, none of them changing what the app looks like.

| # | Commit | Change | Size |
| - | ------ | ------ | ---- |
| 1 | `1a96646a0` | The five dead initializer parameters deleted | 32 deletions, 8 insertions |
| 2 | `c23a70ea6` | The bubble body derives `isOutgoing` from the message | 10 deletions, 9 insertions |
| 3 | `d2a9a48e8` | The AppKit boundary carries one bundled value | 35 deletions, 50 insertions |
| 4 | `e89362efe` | The part row derives the tool activity from the message | 19 deletions, 13 insertions |
| 5 | `0f468c7e8` | The measurement is a command in the repository | 1004 insertions, 3 files |
| 6 | `cae87caf3` | The two dead parameters the tool then found deleted | 8 deletions, 3 insertions |

**The measurement now reports zero dead parameters** across
`Sources/WenshuApp/`. That is the tool's own output, not a claim:

    $ python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp
    DEAD PARAMETERS
    (none)

Seven dead parameters were removed in total. Six were found by the first
detector; the seventh (`WizardStepNavBar.currentStep`) was found by the
tool this wave added, because the first detector did not classify a
`@Binding var` as a parameter.

**What did not change.** No colour, spacing, font, icon, transition or
animation line appears in any of the five refactor commits. The two tool
part views, whose `isOutgoing` picks the bubble fill, are byte-identical to
their base. The `applyOptionalEnvironment` helper, which is the actual
re-injection mechanism, is byte-identical. The `NSSplitViewController`
container keeps its divider style, its top-to-bottom orientation, its
autosave name, its collapse animation and its `sizeThatFits` override, so
the chat pane is still the Keynote speaker-notes pattern.

**The gate.** `swift build` exits 0. The chat, editor, split-view and
shell suites pass: 164 tests in 28 suites. After the second wave, the
editor, chat and export suites run 312 tests in 49 suites with 7
issues, and all 7 are the same failures that fail on `main` (= the
status bar's height, the tab-close icon style, the preferences
forwarding and the 3 `displayTitle` cases; = none of them is an
editor-surface assertion).

The full suite on `main` runs 2761 tests in 447 suites with 54 issues
across 26 failing suites, against a red baseline of 24 failing suites
measured at `b8060a084643e2d5dd72c759750e4c5bf5672575`. The failing
SET is the comparison, never the count, and two of the 26 need their
own explanation because the set alone does not show it:

- `ProviderFetcher` is a LIVE network test. It asserts that a failed
  fetch returns the curated fallback, so it fails whenever the network
  works. It passes on a re-run. It is flaky by construction, and it is
  not a source-content test, so no refactor can have moved it.
- `ToolRegistry production trigger` is a suite that did not exist when
  the baseline was measured. Another session added it at 15:58
  (`21e66a50b7`), so it cannot be in a baseline taken before it
  existed. It is a timing-sensitive test that polls for asynchronous
  registrations, and it races under load.

Neither touches a file this work changed, and the failing suites
remain a subset of the baseline apart from those two. The repository has a red
baseline of 24 failing suites, measured at the base commit
`b8060a084643e2d5dd72c759750e4c5bf5672575`; a source-text failure
inside a worktree is a path failure until proven otherwise, so the
failing SET was compared against that baseline rather than a count.

**One thing this wave did NOT do**, and it is the honest limit of the
measurement: the tool reports the parameters that no view reads, and
the arguments a call site costs. It does NOT report whether a value
that IS read is read in the right place, whether a callback closure
outlives its owner, or whether a parameter would be better as an
environment value. Those are judgement calls, and this audit's method
does not make them.

### 7.1 The second wave

The second wave ran two more cards, on the same rules: one commit each,
its own worktree, and no change to what the app looks like.

| # | Commit | Change | Size |
| - | ------ | ------ | ---- |
| 7 | `43aed9321` | The export modifier split by export kind | 135 insertions, 74 deletions |
| 8 | `5834123d4` | The editor surface built once and shared | 186 insertions, 183 deletions |

The measurement is the gate, and it is the tool's own output:

    $ python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp --top 6
    DEAD PARAMETERS
    (none)

    HEAVIEST INITIALIZERS
    ChatInputBarView  6 args  Features/Chat/View/ChatView.swift:222
    BookFileExporter  6 args  Features/Library/View/ExportSheet.swift:148

The heaviest call site in the app was 13 arguments. It is 6 now.

**One gate the second wave broke, and why.** The chapter-focus-lock
gate asserted that `EditorEditContent.swift` contains the string
`focusedChapterPath`. In the base code that string appeared only in a
COMMENT, so the gate was satisfied by a comment and by nothing else.
The wave moved the comment, and the gate failed. The behaviour had not
changed: the predicate is the same expression, negated the same way.
The new gate is stronger than the old one, and it was proved to be a
gate rather than a rubber stamp: the OLD gate fails against the new
structure and the NEW gate passes.

**The two dead parameters the tool found after the first five were
removed** were `WizardStepNavBar.currentStep`
(`Features/Agent/View/ImportSheetViewPieces.swift:414`) and
`KanbanWindow.library` (`Features/Kanban/View/KanbanWindow.swift:54`).
Card 6 removed both. Each was pinned by a test assertion on the exact
call-site text, and each assertion was updated to the new literal
rather than deleted: the kanban test still proves the scene hands the
window the shared workspace state, and the `WizardStepNavBar` binding
stays live in `ImportSheet`, where the state itself is read and written.

**One real bug the measurement tool's own test suite found.** A Swift
string interpolation is an expression, not literal text, so stripping the
whole literal hid the read inside it, and a live parameter came out dead.
The tool now keeps the interpolation's contents. The naive version of
this detector is what produced the two false positives in section 3.1, and
it is the same class of mistake.

---

## 8. The second wave: responsibility, not dead parameters

The first wave deleted parameters that no view read. The two heaviest
call sites that REMAIN are a different problem, and the tool reports
them at the top of the list:

    EditorEditContent  11 args  Features/Editor/View/EditorView.swift:296
    WenshuMarkdownEditor  8 args  Features/Editor/View/EditorEditContent.swift:109
    WenshuMarkdownEditor  7 args  Features/Editor/View/EditorView.swift:269
    ExportFileExporters  13 args  Features/Library/View/ExportSheet.swift:302

Every one of those parameters IS read. Nothing here can be deleted, and
nothing here should go into the environment either: these are private
types in one or two files, and the environment would reach further than
the data does. The defect is that one value is expressed many times.

**The measurement had a blind spot, and it hid the worst case.** The
tool recognized `struct X: View` and nothing else, so every SwiftUI
`ViewModifier` was invisible to it. The app's single heaviest call site
was exactly that, and the tool never listed it. A measurement that
reports the code as flatter than it is, is wrong in the one direction
that matters. The recognition now covers both, and the test suite gained
the case that would have caught it: a `ViewModifier` with 13 parameters
is measured like a `View`.

**`ExportFileExporters` (13 parameters) is nine parameters pretending to
be thirteen.** It holds, for each of the three export kinds, one engine,
one format, one selected id and one remembered-URL binding. The three
sets are never used together: the library exporter reads the library
engine, the library format and the library binding, and nothing else.
Split into three modifiers, one per kind, each parameter has exactly one
owner, and the `kind` switch disappears (= each modifier knows its kind).

**The editor pane builds the same surface twice.** The preview branch and
the edit branch each spell out eight arguments, six of them the same
expression, and `WenshuEditorServicesFactory.make(bookStore:bus:)` is
called in both branches for two surfaces that differ by two flags
(`isEditable` and whether the caret rect is reported). The fix is the
one Apple uses when the same set of values reaches several consumers:
build the set ONCE, as a value, and hand the value over. `EditorSurface`
is that value, and the two modes read it.

**The rule this wave follows**, which is different from the first wave's:

- A parameter that no view reads is **deleted**.
- A value that many views need is **built once, as a value, and passed**.
- A value that a whole hierarchy needs is **put in the environment**.

Choosing wrongly is worse than not choosing: an `EnvironmentKey` with
no reader is dead code by rule 7.6 (= how `7baf6cb8a` died), and a
value type that groups nothing is a wrapper with a name. Both of the
cards in this wave are the second kind, and neither introduces a key.

### 8.1 What the second wave actually changed

**The export modifier was nine parameters pretending to be thirteen.**
`ExportFileExporters` carried three parallel sets, one per export kind:
each set held an engine, a format, a selected id and a remembered-URL
binding. The three sets were never used together, and the `kind`
parameter existed only to pick one of them. The kind is now the type:
`LibraryFileExporter` (5), `BookFileExporter` (6) and
`ChapterFileExporter` (5) each own one set, and the switch disappears
because each modifier knows what it is. The heaviest call site in the
app went from 13 arguments to 6.

**The editor surface was built twice.** The preview branch and the
edit branch each spelled out eight arguments, six of them the same
expression, and `WenshuEditorServicesFactory.make(bookStore:bus:)` was
called in both branches for two surfaces that differ by two flags.
`EditorSurface` is that set of values, as a value: the host builds it
once and both modes read it. `EditorEditContent` went from 11
parameters to 5, `WenshuMarkdownEditor` from 8 to 2.

**A parameter that would have become dead moved into the surface.**
`isChapterLockedByLLM` had exactly one reader: the `isEditable`
computation in the editor's body. Once that computation moved to the
host, the parameter had no reader left (= a parameter nobody reads, the
exact defect the first wave removed). It moved into the surface, and
the chapter-focus-lock predicate lives in one place, in the host's
editable surface. The measurement tool confirmed this: the dead
parameter section was empty before the move and empty after.

**The preview surface carries no caret-rect callback**, because the old
preview call passed none either. Adding one would have been a
behaviour change, and the status bar's line number is not driven by the
read-only surface.

**The source-content gates were updated, not weakened.** Six assertions
named the old declarations. They now name the surface's declarations
and the forwarding lines that read them out of it, so the chrome slots
and the caret-rect callback are still asserted, on the structure that
now carries them.

### 8.2 The two wave results side by side

| | before | after |
|---|---|---|
| heaviest call site in the app | 13 arguments | 6 arguments |
| `EditorEditContent` | 11 parameters | 5 |
| `WenshuMarkdownEditor` | 8 parameters | 2 |
| `ExportFileExporters` | 13 parameters | gone (= 3 modifiers of 5, 6, 5) |
| dead parameters | 5 | 0 |

The gate is the measurement tool, and it is now in the repository: a
view that nobody reads a parameter of shows up in its dead-parameter
section, and a view with more than a handful of arguments shows up in
its heaviest-initializers table. The tool found the app's heaviest call
site only after it was taught to recognize `ViewModifier`, so the
number it reports now is the real one.
