#
#  2026-11-13 — the render path's full sweep (every surface, measured on the user's own library)
#
#  The boss reported the app's UI as laggy. This sweep does NOT try to
#  reproduce that: the report is the input, and the work is to find the
#  code that spends time on the render path.
#
#  THE SWEEP COVERS EVERY SURFACE. The prior audit (2026-11-10) priced
#  three things: the editor's word count, the materials column's footer
#  scan, and the chat's markdown re-parse. It never measured the
#  SIDEBAR, the CARD GRID, the INSPECTOR, the KANBAN BOARD, or the
#  COVER MOTION. Those five are the unmeasured ground, and they are
#  where this sweep found its largest numbers.
#
#  THE SWEEP'S AXIS IS TWO, NOT ONE. The boss's instruction was that a
#  HIG violation is ALSO a performance loss, so every surface was read
#  on two axes: (1) render-path work the code does, and (2) a HIG
#  compliance defect that costs work (a filesystem stat inside the app
#  root's body, an animation bound to a value the subtree never reads,
#  a forever-repeating symbol effect). Every finding below names the
#  Apple sentence it sits against, with a permalink.
#
#  EVERY NUMBER IS THE USER'S OWN DATA. The corpus is
#  `~/Documents/anbaiqiang.ws` (READ-ONLY). A number from a synthetic
#  corpus is a scenario: the prior audit proved the difference is not
#  academic (a synthetic corpus rescaled one number 6x, reordered the
#  findings, and DROPPED two of them). Every microsecond below was
#  measured with `swiftc -O` probes against that library; every count
#  was read out of the real store; every structural claim was read out
#  of the source and is labelled as such.
#
#  THE LABELS ARE THE POINT. "MEASURED" = a probe produced the number.
#  "READ FROM SOURCE" = the shape and the multiplier are exact, the
#  microseconds are not claimed. A row with no microseconds is still a
#  finding; it is a finding whose SIZE is open.
#

## The corpus (the user's own library, read-only)

| Fact | Value |
| --- | --- |
| Shelves / books / book folders | 2 / 2 / 7 |
| Markdown documents | 32; the largest = 4,731 characters |
| Reference entities / distinct tags | 6 / 12 |
| Kanban tasks | 521 (library-level board); 469 carry a body; 8 statuses |
| Assistant replies in the store | 1,227 characters (with real `[[thinking:]]` markers) |
| Largest library reference | 10,996 characters |
| Cover stills / cover clips | 29 / 4 |
| Settings panes / segmented-control mount sites | 10 / 4 |

Apple's thresholds, carried over from the prior audit and from Apple's
own words: **500 us = a finding, 1,000 us = a red line, 16,700 us = the
60 fps frame budget.**

---

## The path classes (why the ranking is not by microseconds)

A per-launch cost, a per-reload cost, a per-keystroke cost and a
per-frame cost are four different classes, and ranking them against
each other by raw microseconds hides the one the user feels.

| Class | What it means | Total found |
| --- | --- | --- |
| Per keystroke | Runs on every character typed in the editor | about 675 us (two walks of the same document) |
| Per frame while streaming | Runs on every coalesced frame of an AI reply | the trailing row is rebuilt 60x/s |
| Per body pass | Runs whenever the view's body is evaluated | 4,168 predicate evals on the board; 4 stat syscalls at the root |
| Per sidebar reload | Runs on every selection change (NOT per frame) | about 14,860 us |
| Per launch | Runs once per process | every reference-library row's identity changes |

The sidebar's reload cost (about 14.9 ms) is 22x the editor's
per-keystroke cost (about 675 us), and it is also the one the user
feels as "clicking the sidebar is laggy". The per-keystroke one is
smaller and still the one to fix first for the typing surface, because
it repeats on every character while the reload one repeats on every
click.

---

## Findings

### A. Per keystroke (the editor, the typing surface)

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| A1 | `Features/Editor/View/EditorEditContent.swift:80-81` | `.onChange(of: draft) { _, newValue in`<br>`    onWordCountChange(WordCounter.charactersNoSpaces(newValue))` | **MEASURED 337.487 us** per keystroke on the 4,731-character document, in the production loop shape (a grapheme-cluster walk filtering three whitespace classes). Below Apple's 500 us line on its own; the largest single per-keystroke number in the tree. | *"A common cause of long view body updates is performing expensive calculations in the view's body property. Instead, perform the calculation asynchronously, and cache the result to avoid repeating the work every time the view needs to use the result of the calculation."* — https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance |
| A2 | `Features/Editor/View/EditorStatusBarView.swift:125-132` | `var wordCountLabel: String {`<br>`    let count = Self.characterCount(in: textProvider())` | **MEASURED another 337.487 us**: the status bar re-walks the whole draft to show a number the editor's counter ALREADY computed and published via `EditorCounters.wordCount`. **A1 + A2 = about 675 us per keystroke, above Apple's 500 us finding threshold, from the same walk twice.** | same sentence as A1 |

**THE SCALAR FORM IS NOT A DROP-IN FIX.** The same count in scalar form
measures 26.370 us (12.8x cheaper), but it reads a DIFFERENT unit (the
repo's own audit measured 10 vs 17 on an emoji family, 5 vs 7 on a
combining sequence, 7 vs 9 on a flag). The fix is to CACHE the count
the editor already computes (A2 reads it from the store instead of
re-walking), not to change the unit (A1's number is correct and the
user sees it).

### B. Per frame while an AI reply streams (the chat column)

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| B1 | `Features/Chat/Store/StreamingAccumulator.swift:43` and `:109` | `if case let .text(last)? = _parts.last?.kind {`<br>`    _parts[_parts.count - 1] = .text(last + chunk)` | **THE HEADLINE.** The `.text(_:)` factory (`ChatMessagePart.swift:114`) mints `id: UUID()`, so replacing the trailing part with a factory call **re-mints the part's identity every chunk**. `ForEach(message.parts)` (`ChatPartView.swift:100`) identifies rows by that id, so **SwiftUI discards the trailing row and builds a new one, 60 times a second** (the `StreamBuffer`'s 16 ms frame window). The `UUID()` is one allocation; **the rebuild of the whole `ChatPartRow` subtree is the cost.** `ChatMessage.trailingTextPartID` (`ChatMessage.swift:49-54`) returns `parts.last{...}?.id`, so the cursor's anchor id changes with it. | *"Identity helps SwiftUI manage view lifetime, which is crucial for incremental updates to your hierarchy. **A change to the identity means the view changed.** This is important for animations and performance."* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ (transcript read directly, not from a paraphrase) |
| B2 | `Features/Chat/View/ChatReasoningPartView.swift:110-113` (also `ChatTraceTextView.swift:55-58`) | `private var segments: [ReasoningSegment] {`<br>`    let parsed = ReasoningMarkupParser.parse(text)` | The whole reasoning text is re-parsed per body pass, and the parse is **quadratic**: `ReasoningMarkup.swift:87-115` `splitFenceAware` does `current += text + "\n"` inside the line loop. `hasMarkup(text)` runs a SECOND full split on the same text (`ChatPartView.swift:225`). The input grows every frame, so the quadratic term grows too. | same sentence as A1 |
| B3 | `Features/Chat/View/ChatPartView.swift:156-158`, consumed at `:177` | `private var activity: [ToolActivity] {`<br>`    ToolActivity.activity(from: message.parts)` | A whole-message aggregate rebuilt in a body-read computed property. Inside it: `ToolActivity.swift:66-68` calls `toolName(forToolUseID:in:)`, which **linearly rescans all parts** (`:81-88`), so **O(parts^2)**; `primaryArgument` (`:161-163`) runs a **full `JSONSerialization.jsonObject` parse per tool-use**; `summarize` (`:173-178`) copies the **entire tool output** per tool-result. On the real library the largest tool output is 10,996 characters, so the copy is O(output bytes) per frame per result. | *"Move business logic and other non-UI work out of views to model types because SwiftUI recreates views, and recalculates view bodies, frequently."* — https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance |
| B4 | `Features/Chat/View/ChatView.swift:148`, called from `turnHeader(for:)` | `isLatestUser: vm.messages.last(where: { $0.source == .user })?.id == userMsg.id` | A **full backward scan of `vm.messages` per turn**, so **O(turns x messages) = O(n^2)** per body pass of the transcript. Today's corpus is 4 messages, so today's cost is about 0: **this is the finding that bites as the transcript grows**, and it is the only cost here that scales with conversation length. | same sentence as A1 |
| B5 | `Features/Chat/View/ChatView.swift:125-139` | `private var turns: [ChatTurn] {`<br>`    var result: [ChatTurn] = []` | The **entire turn array** (one `ChatTurn` struct per turn) re-allocated on every body pass: O(messages) struct allocations plus appends per frame. | same sentence as A1 |
| B6 | `Features/Chat/View/ChatMessageFooter.swift:80` and `:114`, with `:202-204` and `:226-233` | `.help(Self.fullTimestampTooltip(for: timestamp))`<br>`...`<br>`.help(Self.comboFooterTooltip(timestamp: timestamp, tokens: tokens))` | **`.help(_:)` takes a `String`, so both tooltips are built EAGERLY during body evaluation**, whether or not anyone ever hovers. `comboFooterTooltip` calls `fullTimestampTooltip` again, so **the timestamp is `DateFormatter.string(from:)`-formatted TWICE per footer per frame**. The formatter's CONSTRUCTION is already hoisted (`static let`, `:208-213`); only the per-call format remains. | same sentence as A1 |
| B7 | `Features/Chat/View/ChatToolResultPartView.swift:131-134` and `:189-211` | `private var needsExpandToggle: Bool {`<br>`    toolResult.content.components(separatedBy: "\n").count > 8`<br>`        \|\| toolResult.content.count > 480` | `components(separatedBy:)` **materialises an array of every line** just to count them; `Data(content.utf8)` **copies the whole output**; then `JSONSerialization` parses it. The `content.first == "{"` fast path at `:190` only skips rows whose output does NOT start with `{`, and **JSON tool outputs and diff envelopes DO start with `{`**, so the expensive path is the common one for them. | same sentence as A1 |
| B8 | `Features/Chat/View/ChatView.swift:249-253` | `.onChange(of: vm.messages.last?.content ?? "") { _, _ in`<br>`    if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }` | The change key is the **whole last-message content string**, which changes every frame, so the handler fires every frame and **one `proxy.scrollTo` runs per frame**: one layout pass of the transcript scroll viewport per frame. | *"Layout readers, for example, GeometryReader and ScrollViewReader, observe layout changes in their parent views to recalculate their layouts."* — https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance |

### C. Per body pass (the board, the root, the settings)

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| C1 | `Features/Kanban/View/KanbanView.swift:140` and `:141`, `:250` | `ScrollView(.vertical, showsIndicators: false) { GlassEffectContainer(spacing: ...) {`<br>`    VStack(alignment: .leading, spacing: ...) {`<br>`        ForEach(KanbanStatus.boardOrder, id: \.self) { status in`<br>`            KanbanGroup(status: status, tasks: visibleTasks(in: status), ...)` | **THE BOARD'S SCROLL CONTENT IS A PLAIN `VStack`, NOT A `LazyVStack`**, so **every task card is BUILT on every body pass of the board, not only the visible ones**. The library-level board holds **521 tasks**, of which **469 carry a body**: **521 card bodies constructed plus 469 markdown parses per board body pass**, not the ~15 a lazy stack would build. The app's own comment at `CardCoverView.swift:12-15` already states the rule: "a synchronous disk read per card in the view body makes scrolling stutter". | *LazyVStack* Overview: *"The stack is 'lazy,' in that the stack view doesn't create items until it needs to render them onscreen."* — https://developer.apple.com/documentation/swiftui/lazyvstack |
| C2 | `Features/Kanban/View/KanbanView.swift:333` (also `:43`) | `Text(ChatTextPartView.parseMarkdown(body))` | A **full markdown-to-`AttributedString` parse inside the card's `body`**, so it re-runs on every board body pass instead of once at the model boundary: **469 parses per board body pass**. The per-parse unit is ESTIMATED from the chat's measured 5.08-61.44 us (the board's own bodies average 23.1 characters, so the board's 469 parses are about 2.4 ms per body pass); the board's bodies were not parsed in a probe. | *"SwiftUI performance starts with one rule: only work that is required for the current state should happen for the current frame."* and *"The winning pattern is precomputation at the model boundary, not clever work in `body`."* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ |
| C3 | `Shared/UI/LibraryRootView.swift:34-50` (read at `:88` and `:111`) | `let exists = FileManager.default.fileExists(atPath: activeLibraryPath ?? "", isDirectory: &isDir)` ...<br>`if !FileManager.default.isReadableFile(atPath: infoPlistURL.path) { return true }` | **A FILESYSTEM `stat()` INSIDE THE APP ROOT VIEW'S `body`**. `shouldShowOnboarding` is evaluated TWICE per body pass (once as the toolbar modifier's argument, once in `content`): **up to 4 stat-class syscalls plus 2 `URL` allocations per root body pass**. The root reads two `@Observable` environments, so any change to either re-runs the root body. | same sentence as A1 |
| C4 | `Features/Settings/View/SettingView+Providers.swift:420-437` and `:443-457` (mounted at `SettingView.swift:216`) | `func updateNSView(_ nsView: NSView, context _: Context) {`<br>`    if let hostWindow = nsView.window {`<br>`        hostWindow.styleMask.insert(.resizable)`<br>`        ensureResizableAcrossHostingTree(of: hostWindow)` | The file's own comment at `:421-423` says `updateNSView` "fires every time the SwiftUI hosting tree is reconciled", so **every reconcile walks EVERY `NSApp` window in the app and writes `styleMask` on each**: 2 full traversals plus 1 write per app window per reconcile. A whole-app mutation to fix one window's resizability. | *"When you need to update a view, calculate the smallest region that needs updating ... so the system only updates the changed region."* — https://developer.apple.com/documentation/xcode/improving-your-app-s-rendering-efficiency |
| C5 | `Features/Settings/View/SettingView.swift:210-211` | `paneBody(for: selectedTab)`<br>`    .frame(minWidth: 520)`<br>`    .animation(.default, value: selectedTab)`<br>`    .animation(.default, value: globalSearchQuery)` | **AN IMPLICIT ANIMATION BOUND TO `globalSearchQuery` ON THE WHOLE DETAIL COLUMN**. The query lives in the **sidebar's** `.searchable` field (`:202-206`), so **one full-detail-column animation runs per keystroke, for the 9 of 10 panes that never read the query.** | *"Limit the frame rate and duration of animations - Use animations to communicate changes and updates in your app, and pause or stop them when the update completes."* — https://developer.apple.com/documentation/xcode/improving-your-app-s-rendering-efficiency |
| C6 | `Features/Settings/View/SettingView.swift:162-168`, `:178`, `:261-274` | `private var visiblePanes: [SettingsPane] {`<br>`    ... SettingsPane.allCases.filter { pane in localizedPaneTitle(pane).localizedCaseInsensitiveContains(query) }` | **A BUNDLE-BACKED `String(localized:)` LOOKUP PER PANE PER BODY PASS**: 10 panes means 10 or more lookups per body pass, 20 or more per keystroke (the query is in the sidebar's search field). | *"looking up values from bundles can be expensive"* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ |
| C7 | `Shared/UI/LabelSegmentedControl.swift:258-260` into `:272-435` (unguarded writes at `:286`, `:287-299`, `:302`) | `control.setLabel(display, forSegment: index)`<br>`control.setImage(image.withSymbolConfiguration(NSImage.SymbolConfiguration(...)), forSegment: index)`<br>`control.setToolTip(display, forSegment: index)` | **THE FILE'S OWN RULE AT `:415-417`** ("THE WRITE IS GUARDED (= only write when the value differs) because writing a segment index into a control during a layout pass re-arms the window's update-constraints pass") **IS VIOLATED BY ITS OWN UNGUARDED WRITES**, plus a **freshly allocated `NSImage` per segment** (`withSymbolConfiguration` allocates a new image each time). 4 mount sites (`ChatZoneTabBar.swift:63`, `AppleSidebarView.swift:200`, `InspectorView.swift:62`, `EditorTabStrip.swift:109`; the tab strip carries one segment per open document). | *"any heap allocation, such as for a class-bound type, can add up"* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ |
| C8 | `Shared/UI/IconStyles.swift:547-551` | `styledImage.symbolEffect(.variableColor.iterative, options: .repeating)` | **A FOREVER-REPEATING SYMBOL ANIMATION**: the factory's own comment (`:538-539`) says it "loops forever while the view is mounted". 2 production call sites (`ImportSheetViewPieces.swift:186` and `:201`); the same pattern also appears at `InspectorTodoPageView.swift:181` (`.symbolEffect(.rotate, options: .repeating)`), outside this sweep's surfaces. | same sentence as C5 |
| C9 | `Features/Cover/Model/CoverImageCache.swift:35-42` and `:54-57`, called from `Features/Cover/View/CardCoverView.swift:95` and `:103` | `private func key(for url: URL) -> String { let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]); return "\(url.path)\|\(values?.fileSize ?? 0)\|\(...)" }` | **THE CACHE KEY IS COMPUTED ON THE DISK** (`resourceValues` hits the filesystem) and it is computed **twice per card load** (once for the lookup at `:95`, once for the store at `:103`). Up to **58 filesystem metadata reads per full grid scroll-through** (29 covers x 2), on the **main actor** (the `.task` closure inherits it; only the PNG decode at `:99-101` is off-main). A card re-loads every time it scrolls back into view (`.task(id: imageURL)` at `CardCoverView.swift:76`). | same sentence as A1 (the sentence names body work; this cost is in the `.task` path, one hop out, and the same rule applies) |
| C10 | `Features/Cover/View/LoopingCoverView.swift:169-180` (called from `:139`), `:207-212`, `:135-137` | `let item = AVPlayerItem(url: videoURL); let queue = AVQueuePlayer(); queue.isMuted = true; queue.actionAtItemEnd = .advance; player = queue; looper = AVPlayerLooper(player: queue, templateItem: item)` | **An `AVPlayerItem` plus `AVQueuePlayer` plus `AVPlayerLooper` are constructed on `.onAppear` for every video card, whether or not the pointer ever arrives.** The looper's spare copy of the clip is released only in `tearDown` (`:208`, on disappear), never when the clip is merely stopped (`:196-204` pauses and rewinds but leaves the loop armed). Per video card: 1 decoder plus 1 spare copy of the clip held for the card's whole visible life. The user has 4 `cover.mp4` today, and the count grows with every generated cover. | *"only work that is required for the current state should happen for the current frame"* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ (Apple's rendering page praises `AVPlayer`, so the API choice is compliant; the defect is the EAGERNESS and the loop staying armed while stopped) |
| C11 | `Shared/UI/LibraryRootView.swift:213-231` and `:283` | `private func loadWenshuLogo(named assetName: String) -> NSImage? { ... NSImage(contentsOf: url) ... }` | **A PNG DECODE PLUS A DISK READ INSIDE A VIEW BODY**, and the function searches 3 candidate paths (bundle subdirectory, bundle root, an absolute source-tree path). Up to 3 path probes plus 1 PNG decode per body pass. Onboarding-only, so the blast radius is the first-launch screen. | same sentence as A1; plus *"looking up values from bundles can be expensive"* — WWDC23 |
| C12 | `Features/LibraryMigration/View/LibraryMigrationPanel.swift:137-139` | `ProgressView(value: state.progress, total: 1.0).progressViewStyle(.linear).animation(.default, value: state.progress)` | An animation bound to a **continuously changing progress value**: 1 default-duration animation per progress update, on every tick of a library migration. | same sentence as C5 |

### D. Per sidebar reload (per selection change, NOT per frame)

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| D1 | `Features/Library/View/AppleSidebarView.swift:270-298` | `loadFolderDocCount: { [bookStore] bookId, folderName in`<br>`    ... FileManager.default.contentsOfDirectory(at: shelvesRoot, ...)`<br>`    for shelfDir in shelfDirs { ... FileManager.default.contentsOfDirectory(at: folderDir, ...)` | Per folder row the code **re-lists every shelf directory** and then re-lists the target folder to count its `.md` files. Called from `SidebarService.folderChildren(for:)` (`SidebarService.swift:311`) once per (book x user-facing folder). **MEASURED 1,344.528 us per single `loadFolderDocCount` call**; the real reload's books x 5 user-facing folders = 2 x 5 = 10 calls = **10,447.855 us per sidebar reload**. The walk is O(shelves) per call, so O(shelves x books x folders). | *"Move business logic and other non-UI work out of views to model types because SwiftUI recreates views, and recalculates view bodies, frequently."* — https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance (no Apple sentence covers "don't re-list a directory you just listed"; the nearest is the model-boundary pattern Apple names) |
| D2 | `Features/Library/View/SidebarService+ReferenceLibrary.swift:269-285` and `:244-260` (same shape at `SidebarService.swift:327-347`) | `var hasher = Hasher(); hasher.combine(raw); let hash = hasher.finalize()`<br>`let u = uuidBytes.map { String(format: "%02x", $0) }.joined()` | Each tag row and each category row builds a UUID from a **`Hasher()` seeded per process**, and formats it with **16 separate `String(format:)` calls**. **MEASURED 169.237 us per UUID**, of which **112.572 us is the 16 x `String(format: "%02x")`** and the `Hasher` itself is **0.196 us**. The real library's 12 distinct tags plus 6 categories = 18 ids = **1,517.841 us per reload**. | *"any heap allocation, such as for a class-bound type, can add up"* and *"string interpolation can often be expensive, so make sure to cache any strings you might need to frequently use"* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ (`String(format:)` is the class-bound form; `FormatStyle` is the cheap form) |
| D3 | `Features/Library/View/SidebarService.swift:106-235` (`reload()`) | `CoverReconciler.live().sweep(liveReferenceIds: ..., shelvesRoot: ...)` at `:120` | `reload()` walks the whole shelves tree (every book x every folder x every file) to reconcile covers. **MEASURED 2,894.455 us per full shelves walk** on the real library (2 books, 20 `.md` files). On this corpus the sweep early-exits on `guard !coverKeys.isEmpty` when no covers are stored, so the number is the upper bound, paid only when covers exist. | same sentence as D1 |

### E. Per launch

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| E1 | `Features/Library/View/SidebarService+ReferenceLibrary.swift:269-285` — identity churn | `private static func stableReferenceTagId(_ tag: String) -> UUID {`<br>`    let raw = "wenshu.sidebar.reftag.\(tag)"`<br>`    var hasher = Hasher()` | The doc comment promises *"same tag string yields the same UUID across launches, so the persisted sidebarSelection survives reload"*. **`Hasher()` is seeded per process, so the promise is false.** **MEASURED, cross-process**: three consecutive runs of the identical replica produced `F5EB52CE-...`, `F0267C71-...`, `F0B97B25-...` for the same CJK tag — **three different UUIDs in three launches** — while **within** one process the same call is stable. So **across launches every reference-library row's identity changes**: SwiftUI discards and rebuilds every visible row, and a persisted selection keyed by that UUID cannot resolve to the row it named. Within a session there is no churn, so this is not a per-frame defect; the cost is one full row rebuild per launch. | *"Identity helps SwiftUI manage view lifetime, which is crucial for incremental updates to your hierarchy. A change to the identity means the view changed."* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ (`Hasher`'s per-process seeding is a Swift language fact, not an Apple-sentence claim) |

---

## What was checked and is clean

- **The prior audit's settled findings are not repeated here.** The chat's markdown re-parse and the pinyin search key were DROPPED on the real data; the editor's word count was fixed upstream by commit `f0bfcedb42`; the materials-column footer scan (2,174 us) and the pinyin sort (4,039.57 us) are priced already.
- **`LibraryContentFingerprint.swift`** (the whole file) — the disk-touching cache keys are ALREADY cached in `Cache.shared` and invalidated by the `.wenshuLibraryDidChange` announcement (`:183-190`), so the disk read happens **once per library change, not once per keystroke**. `ReferenceLibraryWikiLinkResolver.fingerprint()` and `ReferenceLibraryImageProvider.fingerprint()` both route through the cache. Clean, and the shape C9 should copy.
- **`WordCounter.count(_:)`** (the six-field full count) — dead on the render path. No reader of `.words` / `.sentences` / `.paragraphs` / `.characters` / `.chineseChars` remains on a `WordCount`.
- **`NativeTextViewWrapper.updateNSView`** (vendored) — the per-update fingerprint comparisons hit the cached fingerprint above, and the comparison is a pointer/value compare, not a disk read.
- **`LibraryFullTextSearchView.swift:207-258`** — the full-text search is correctly off the main actor (`Task.detached(priority: .userInitiated)`), keyed on the query so a keystroke cancels the prior search, with a generation counter discarding stale results. **This is the shape the editor's word count should copy.**
- **`AppleSidebarView.swift:86-177`** — the `List` is a lazy container, and the row identity for shelves and books is the real store UUID. Only the reference-library rows use synthesized ids (E1).
- **`SidebarRowView.swift:288-336`** — O(1) reads of the node. No formatter, no aggregation.
- **`EditorView.swift:436-438`** (`editorIdentity`), **`EngineStyleSheetBridge.fingerprint(for:)`** — both built from real values, stable across launches and body passes. **The sheet key is the shape E1 should have used.**
- **`EditorView.swift:537-547` and `:556-567`** — `id: UUID()` on NEW tabs. A fresh identity for a genuinely new object is correct, not churn.
- **Zero `@Query` in view code**; all 28 `modelContext.fetch` calls live in the Service layer.
- **Environment injection is fine-grained**: `AppState` 31 properties, `WorkspaceUIState` 17, `BookStore` 5.
- **Zero `GeometryReader`** across the eight non-editor surfaces.
- **Zero `DateFormatter(` and `NumberFormatter(`** across the eight non-editor surfaces.
- **Zero valueless `.animation(`** — all five hits carry a `value:`.
- **`Features/Backup/` and `Features/Companion/`** carry no View file, so they have no render path at all.
- **`Features/Chrome/`** — system material, `ToolbarItem(placement:)`, `Image(systemName:)`, no I/O in any body.
- **The axis "a custom control where Apple ships one" produced NO finding.** `LabelSegmentedControl` wraps the native `NSSegmentedControl` and its file-level rationale (`:16-29`) documents why SwiftUI's `Picker(.segmented)` cannot express `NSSegmentedControl.Role.tabs`. `LoopingCoverView` uses `AVPlayerLayer`, and Apple's rendering-efficiency page explicitly endorses `AVPlayer`. `WindowResizableEnabler` exists because of a macOS 27 SwiftUI `Settings` bug, not a preference. **No HIG citation is offered for that axis because none was read.**

---

## What was NOT measured (the open questions)

- **`WenshuEditorServicesFactory.make` per body pass vs once per mount** (`EditorView.swift:400-415` into `WenshuEditorServicesFactory.swift:14-195`). It builds a whole `MarkdownEditorConfiguration`: `MarkdownEditorBus.buildWenshu()` allocates **25 `Notification.Name`s**, a `BookAwareWikiLinkResolver` (which constructs a `BookDocumentIndex`, i.e. **7 directory listings**), a `ReferenceLibraryImageProvider`, `HighlighterSwiftBridge()`, `SwiftMathBridge()`. The `BookDocumentIndex` inside it measures **729.160 us** standalone for one book's 7-folder scan. **This is the highest-value open question in the sweep**: if `EditorView.editorSurface` really rebuilds the configuration per body pass, it dwarfs every row above and re-ranks the report. It needs one more probe or an Instruments run.
- **`DocumentLinkIndex.linkedNames` / `bodyWithoutLinkSections` per body pass** (`DocumentLinkIndex.swift:20-27` and `:57-90`, called from `EditorView.swift:355`). The shape is confirmed; the number is not produced. O(document) per body pass on a 4,731-character document, and `linkedNames` runs **twice** per pass (once for `loadKey`, once inside `load()`).
- **`EditorView.editorEmptyDocumentPlaceholder`** (`EditorView.swift:62-75`) — an `NSAttributedString` plus `NSFont.preferredFont(forTextStyle:)` plus `NSMutableParagraphStyle` allocated per body pass. AppKit caches the preferred font, so the hypothesis is tens of us, not thousands. Unmeasured.
- **`WenshuMarkdownEditor.styleSheet`'s repeated `books.first(where:)`** (`WenshuMarkdownEditor.swift:24-29`, `:46-57`, `:160`) — O(books) x ~10 per body pass; sub-microsecond on a 2-book corpus. Its real blast radius is the `.id()` remount when a sheet changes.
- **`GlassEffectContainer` at `KanbanView.swift:139`** wraps the entire scrolling board, so any change in the middle of the board updates the whole glass group. Apple's rendering-efficiency page warns about grouping spatially distant views. Not measured.
- **`InspectorTodoPageView.swift:181`** — the same forever-repeating symbolEffect as C8, but outside this sweep's surfaces. Flagged, not audited.
- **C4's `styleMask` write cost and the runtime window count** are unmeasured; whether AppKit coalesces an idempotent `.resizable` insert was not tested.
- **C7's NSImage allocation cost** is unmeasured; the segment counts at runtime are unmeasured.
- **C10's eager-player cost** is unmeasured; the multiplier today is only 4 clips, and the finding is a growth-direction one.

---

## The rules this sweep paid for

1. **Classify the path before ranking.** A per-launch cost, a per-reload
   cost, a per-keystroke cost and a per-frame cost are four different
   classes. Ranking them by raw microseconds lets a 14 ms one-shot hide
   behind a 675 us per-frame number, and hides the one the user feels
   from the one they feel most often.
2. **Identity is a cost, not just a correctness property.** A row whose
   id is re-minted per frame costs a full subtree rebuild per frame; the
   `UUID()` is one allocation, the rebuild is the cost.
3. **Measure on the user's real corpus.** A synthetic corpus rescaled a
   number 6x, reordered the findings, and dropped two of them.
4. **A `.help(String)` is eager.** Any tooltip built in the body is
   built on every body pass, whether or not anyone hovers.
5. **A cache key that touches the disk makes the lookup an I/O.** The
   key must be derived from data already in hand (D2's `String(format:)`,
   C9's `resourceValues`).
