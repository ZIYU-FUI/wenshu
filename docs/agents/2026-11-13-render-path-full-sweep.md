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
#  compliance defect that costs work. Every finding below names the
#  Apple sentence it sits against, with a permalink.
#
#  EVERY NUMBER IS THE USER'S OWN DATA. The corpus is
#  `~/Documents/anbaiqiang.ws` (READ-ONLY). Every microsecond below was
#  measured with `swiftc -O` probes against that library; every count
#  was read out of the real store; every structural claim was read out
#  of the source and is labelled as such.
#
#  THE LABELS ARE THE POINT. "MEASURED" = a probe produced the number.
#  "READ FROM SOURCE" = the shape and the multiplier are exact, the
#  microseconds are not claimed. A row with no microseconds is still a
#  finding; it is a finding whose SIZE is open.
#
#  REVISION 2 (2026-11-13, after the first review). The first version
#  of this document was returned CHANGES REQUESTED, and the verdict was
#  right on both counts that mattered. = = The numbers were measured
#  while three subagents were running `swiftc -O` compiles at the same
#  time, and the harness AVERAGED, which is the one statistic that
#  background load inflates. = = Two Apple sentences were attributed to
#  a page that does not carry them. = = So revision 2 re-measures every
#  number with a contention-robust method (= the MINIMUM over many
#  reps, = = which is the load-independent floor, = = because contention
#  can only ADD time), re-sources the two sentences to text that is
#  actually on the cited page, and adds the HIG axis the first version
#  left unread. = = The corrections are listed in the last section, so
#  a reader can see exactly what moved and why.
#

## The corpus (the user's own library, read-only)

Measured 2026-11-13, 14:07-14:10 CST. Every count below was read out
of the live library or the live store, not estimated.

| Fact | Value |
| --- | --- |
| Shelves / books / book folders | 2 / 2 / 7 (`BookFolderCatalog.allBookFolders`) |
| Largest markdown document | 4,731 characters (`references/2D44E511-….md`) |
| Reference entities / distinct tags | 6 / 12 (`reference-library/entities/entities.json`) |
| Kanban tasks (library-level board) | 542 total; 490 carry a body; **7** statuses in the store (`running`, `done`, `new`, `triage`, `ready`, `blocked`, `failed`) |
| Kanban board COLUMNS rendered | 8 (`KanbanStatus.boardOrder`) — a different number from the store's 7 statuses |
| Longest assistant reply in the store | 532 characters (`ZWSCHATMESSAGE.ZCONTENT`) |
| Cover stills / cover clips | **26** `.heic` / 4 `.mp4` under `assets/covers` |
| Settings panes / segmented-control mount sites | 10 / 4 |
| Library-level `ZWSREFERENCE` rows | 0 (= the reference library lives on disk, not in the store) |

Apple's thresholds, carried over from the prior audit: **500 us = a
finding, 1,000 us = a red line, 16,700 us = the 60 fps frame budget.**

---

## How the numbers are measured (= the first version's method was wrong)

The first version's harness ran N reps and divided the TOTAL by N. A
mean is exactly the statistic that background CPU load inflates: one
400 us scheduling hiccup inside 400 reps adds 1 us to the mean. The
recorded run sat inside three concurrent `swiftc -O` compiles.

Revision 2's harness reports **min / median / p95** of the per-call
cost over many reps. The **minimum is the number to quote**: contention
can only ADD time, never remove it, so the minimum is the
load-independent floor (= the fastest the code path actually ran). The
median is printed beside it so a reader can see the spread; a small
min-to-median gap means the machine was quiet.

Two runs, four minutes apart, on a machine with no compile running:

| quantity | revision 1 (mean, contended) | revision 2 (min / median) |
| --- | --- | --- |
| A1/A2 one walk of the 4,731-char document | 337.487 us | **140.333 / 153.833 us** |
| A1+A2 the same walk twice | about 675 us | **276.042 / 291.083 us** |
| D1 one `loadFolderDocCount` call | 1,344.528 us | **66.209 / 69.375 us** |
| D1 the whole sidebar reload (books x 5 folders) | 10,447.855 us | **759.958 / 788.208 us** |
| D2 one id (Hasher + 16 `String(format:)`) | 169.237 us | **9.333 / 9.666 us** |
| D2 the 16 `String(format:)` alone | 112.572 us | **8.042 / 8.375 us** |
| D2 the `Hasher` alone | 0.196 us | **0.041 / 0.083 us** |
| D2 the real 12-tag set's id cost | 1,517.841 us | **116.292 / 119.000 us** |
| D3 the full shelves walk | 2,894.455 us | **755.000 / 781.334 us** |
| D4 one WHOLE sidebar reload (= = D1's ten counts + D3's shelves walk, = = measured together) | not measured | **1,589.667 / 1,642.375 us** |
| F1 `BookDocumentIndex.scan` (one book) | 729.160 us | **188.833 / 193.792 us** |

The probe file is `probe4-contention-robust.swift` (= every row above
is the SAME production shape as the first version's replica; only the
harness changed).

**⇒ ⇒  TWO OF THE REPORT'S CONCLUSIONS FLIP.** = = A1+A2 no longer
crosses Apple's 500 us line (= 276 us, not 675), so the per-keystroke
class drops OUT of the "above threshold" set. = = And the sidebar's
per-reload total is **1,590 us**, not 14.9 ms (= it was a sum of three
inflated numbers), so the sidebar is no longer 22x the editor's
per-keystroke cost (= it is about 5.8x). = = The sidebar is still the
largest single number in the tree, but it is 1,590 us, not 14.9 ms.

---

## The path classes (why the ranking is not by microseconds)

A per-launch cost, a per-reload cost, a per-keystroke cost and a
per-frame cost are four different classes, and ranking them against
each other by raw microseconds hides the one the user feels.

| Class | What it means | Total found (revision 2) |
| --- | --- | --- |
| Per keystroke | Runs on every character typed in the editor | **276.042 us** (two walks of the same document) — BELOW Apple's 500 us line |
| Per frame while streaming | Runs on every coalesced frame of an AI reply | the trailing row is rebuilt 60x/s (a COUNT, not a microsecond figure) |
| Per body pass | Runs whenever the view's body is evaluated | 542 card bodies + 490 markdown parses per board pass; 4 stat syscalls at the root |
| Per sidebar reload | Runs on every selection change (NOT per frame) | **1,589.667 us** (= = D1's ten folder counts + D3's shelves walk, = = MEASURED together; = = the earlier 759.958 us was D1 alone) |
| Per launch | Runs once per process | every reference-library row's identity changes |

The sidebar's reload cost (1,590 us) is about 5.8x the editor's
per-keystroke cost (276 us), and it is the one the user feels as
"clicking the sidebar is laggy". The per-keystroke one is smaller and
still the one to fix first for the typing surface, because it repeats
on every character while the reload one repeats on every click.

**⇒ ⇒  THE HEADLINE IS UNCHANGED, AND IT IS NOT A MICROSECOND
FIGURE.** = = The per-frame class has no microsecond number at all,
because the cost is a SUBTREE REBUILD (= SwiftUI discards the trailing
row and builds a new one), and a subtree rebuild's cost is the work
inside that subtree, not a timer on the row's construction. = = So the
largest cost in the tree is also the one no stopwatch can price, and it
is the one the user feels WHILE AN AI REPLY STREAMS.

---

## Findings

### A. Per keystroke (the editor, the typing surface)

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| A1 | `Features/Editor/View/EditorEditContent.swift:80-81` | `.onChange(of: draft) { _, newValue in`<br>`    onWordCountChange(WordCounter.charactersNoSpaces(newValue))` | **MEASURED 140.333 us min / 153.833 us median** per keystroke on the 4,731-character document, in the production loop shape (a grapheme-cluster walk filtering three whitespace classes). **BELOW Apple's 500 us finding line on its own.** | *"A common cause of long view body updates is performing expensive calculations in the view’s body property. Instead, perform the calculation asynchronously, and cache the result to avoid repeating the work every time the view needs to use the result of the calculation."* — https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance |
| A2 | `Features/Editor/View/EditorStatusBarView.swift:125-132` | `var wordCountLabel: String {`<br>`    let count = Self.characterCount(in: textProvider())` | **MEASURED another 140.333 us**: the status bar re-walks the whole draft to show a number the editor's counter ALREADY computed and published via `EditorCounters.wordCount`. **A1 + A2 = 276.042 us min / 291.083 us median per keystroke — still below Apple's 500 us line, but the SAME walk runs twice.** | same sentence as A1 |

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
| B2 | `Features/Chat/View/ChatReasoningPartView.swift:110-113` (also `ChatTraceTextView.swift:55-58`) | `private var segments: [ReasoningSegment] {`<br>`    let parsed = ReasoningMarkupParser.parse(text)` | The whole reasoning text is re-parsed per body pass, and the parse is **quadratic**: `ReasoningMarkup.swift:87-115` `splitFenceAware` does `current += text + "\n"` inside the line loop. `hasMarkup(text)` runs a SECOND full split on the same text (`ChatPartView.swift:225`). The input grows every frame, so the quadratic term grows too. | *"Another source is work done in body. Make sure to check for expensive string interpolation or operations like data filtering and other work inside of body. It's important that body itself is as cheap as possible."* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ |
| B3 | `Features/Chat/View/ChatPartView.swift:156-158`, consumed at `:177` | `private var activity: [ToolActivity] {`<br>`    ToolActivity.activity(from: message.parts)` | A whole-message aggregate rebuilt in a body-read computed property. Inside it: `ToolActivity.swift:66-68` calls `toolName(forToolUseID:in:)`, which **linearly rescans all parts** (`:81-88`), so **O(parts^2)**; `primaryArgument` (`:161-163`) runs a **full `JSONSerialization.jsonObject` parse per tool-use**; `summarize` (`:173-178`) copies the **entire tool output** per tool-result. | *"Move business logic and other non-UI work out of views to model types because SwiftUI recreates views, and recalculates view bodies, frequently."* — https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance |
| B4 | `Features/Chat/View/ChatView.swift:148`, called from `turnHeader(for:)` | `isLatestUser: vm.messages.last(where: { $0.source == .user })?.id == userMsg.id` | A **full backward scan of `vm.messages` per turn**, so **O(turns x messages) = O(n^2)** per body pass of the transcript. Today's corpus is 4 messages, so today's cost is about 0: **this is the finding that bites as the transcript grows**, and it is the only cost here that scales with conversation length. | same sentence as B2 |
| B5 | `Features/Chat/View/ChatView.swift:125-139` | `private var turns: [ChatTurn] {`<br>`    var result: [ChatTurn] = []` | The **entire turn array** (one `ChatTurn` struct per turn) re-allocated on every body pass: O(messages) struct allocations plus appends per frame. | same sentence as B2 |
| B6 | `Features/Chat/View/ChatMessageFooter.swift:80` and `:114`, with `:202-204` and `:226-233` | `.help(Self.fullTimestampTooltip(for: timestamp))`<br>`...`<br>`.help(Self.comboFooterTooltip(timestamp: timestamp, tokens: tokens))` | **`.help(_:)` takes a `String`, so both tooltips are built EAGERLY during body evaluation**, whether or not anyone ever hovers. `comboFooterTooltip` calls `fullTimestampTooltip` again, so **the timestamp is `DateFormatter.string(from:)`-formatted TWICE per footer per frame**. The formatter's CONSTRUCTION is already hoisted (`static let`, `:208-213`); only the per-call format remains. | same sentence as B2 |
| B7 | `Features/Chat/View/ChatToolResultPartView.swift:131-134` and `:189-211` | `private var needsExpandToggle: Bool {`<br>`    toolResult.content.components(separatedBy: "\n").count > 8`<br>`        \|\| toolResult.content.count > 480` | `components(separatedBy:)` **materialises an array of every line** just to count them; `Data(content.utf8)` **copies the whole output**; then `JSONSerialization` parses it. The `content.first == "{"` fast path at `:190` only skips rows whose output does NOT start with `{`, and **JSON tool outputs and diff envelopes DO start with `{`**, so the expensive path is the common one for them. | same sentence as B2 |
| B8 | `Features/Chat/View/ChatView.swift:249-253` | `.onChange(of: vm.messages.last?.content ?? "") { _, _ in`<br>`    if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }` | The change key is the **whole last-message content string**, which changes every frame, so the handler fires every frame and **one `proxy.scrollTo` runs per frame**: one layout pass of the transcript scroll viewport per frame. | *"Layout readers, for example, GeometryReader and ScrollViewReader, observe layout changes in their parent views to recalculate their layouts."* — https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance (= the page renders it "GeometryReader and ScrollViewReader", = = unspaced: = = the HTML's `<wbr>` is a zero-width break opportunity inside `<code>`, = = never a rendered space) |

### C. Per body pass (the board, the root, the settings)

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| C1 | `Features/Kanban/View/KanbanView.swift:140` and `:141`, `:250` | `ScrollView(.vertical, showsIndicators: false) { GlassEffectContainer(spacing: ...) {`<br>`    VStack(alignment: .leading, spacing: ...) {`<br>`        ForEach(KanbanStatus.boardOrder, id: \.self) { status in`<br>`            KanbanGroup(status: status, tasks: visibleTasks(in: status), ...)` | **THE BOARD'S SCROLL CONTENT IS A PLAIN `VStack`, NOT A `LazyVStack`**, so **every task card is BUILT on every body pass of the board, not only the visible ones**. The library-level board holds **542 tasks**, of which **490 carry a body**: **542 card bodies constructed plus 490 markdown parses per board body pass**, not the ~15 a lazy stack would build. The app's own comment at `CardCoverView.swift:12-15` already states the rule: "a synchronous disk read per card in the view body makes scrolling stutter". | *LazyVStack* Overview: *"The stack is “lazy,” in that the stack view doesn’t create items until it needs to render them onscreen."* — https://developer.apple.com/documentation/swiftui/lazyvstack (= and WWDC23 says the same about a list: *"only those that are needed have their row contents constructed"* — https://developer.apple.com/videos/play/wwdc2023/10160/) |
| C2 | `Features/Kanban/View/KanbanView.swift:333` (also `:43`) | `Text(ChatTextPartView.parseMarkdown(body))` | A **full markdown-to-`AttributedString` parse inside the card's `body`**, so it re-runs on every board body pass instead of once at the model boundary: **490 parses per board body pass**. The per-parse unit is ESTIMATED from the chat's measured 5.08-61.44 us (the board's own bodies average 23.1 characters, so the board's 490 parses are about 2.4 ms per body pass); the board's bodies were not parsed in a probe. | *"Another source is work done in body. Make sure to check for expensive string interpolation or operations like data filtering and other work inside of body. It's important that body itself is as cheap as possible."* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ (= the sentence the first version mis-attributed is replaced by the one the transcript actually carries) |
| C3 | `Shared/UI/LibraryRootView.swift:34-50` (read at `:88` and `:111`) | `let exists = FileManager.default.fileExists(atPath: activeLibraryPath ?? "", isDirectory: &isDir)` ...<br>`if !FileManager.default.isReadableFile(atPath: infoPlistURL.path) { return true }` | **A FILESYSTEM `stat()` INSIDE THE APP ROOT VIEW'S `body`**. `shouldShowOnboarding` is evaluated TWICE per body pass (once as the toolbar modifier's argument, once in `content`): **up to 4 stat-class syscalls plus 2 `URL` allocations per root body pass**. The root reads two `@Observable` environments, so any change to either re-runs the root body. | same sentence as C2 |
| C4 | `Features/Settings/View/SettingView+Providers.swift:420-437` and `:443-457` (mounted at `SettingView.swift:216`) | `func updateNSView(_ nsView: NSView, context _: Context) {`<br>`    if let hostWindow = nsView.window {`<br>`        hostWindow.styleMask.insert(.resizable)`<br>`        ensureResizableAcrossHostingTree(of: hostWindow)` | The file's own comment at `:421-423` says `updateNSView` "fires every time the SwiftUI hosting tree is reconciled", so **every reconcile walks EVERY `NSApp` window in the app and writes `styleMask` on each**: 2 full traversals plus 1 write per app window per reconcile. A whole-app mutation to fix one window's resizability. | *"When you need to update a view, calculate the smallest region that needs updating ... so the system only updates the changed region."* — https://developer.apple.com/documentation/xcode/improving-your-app-s-rendering-efficiency |
| C5 | `Features/Settings/View/SettingView.swift:210-211` | `paneBody(for: selectedTab)`<br>`    .frame(minWidth: 520)`<br>`    .animation(.default, value: selectedTab)`<br>`    .animation(.default, value: globalSearchQuery)` | **AN IMPLICIT ANIMATION BOUND TO `globalSearchQuery` ON THE WHOLE DETAIL COLUMN**. The query lives in the **sidebar's** `.searchable` field (`:202-206`), so **one full-detail-column animation runs per keystroke, for the 9 of 10 panes that never read the query.** | *"In apps, generally avoid adding motion to UI interactions that occur frequently."* — HIG *Motion*, https://developer.apple.com/design/human-interface-guidelines/motion (= HIG's own sentence on this exact shape; the first version cited only a developer page) |
| C6 | `Features/Settings/View/SettingView.swift:162-168`, `:178`, `:261-274` | `private var visiblePanes: [SettingsPane] {`<br>`    ... SettingsPane.allCases.filter { pane in localizedPaneTitle(pane).localizedCaseInsensitiveContains(query) }` | **A BUNDLE-BACKED `String(localized:)` LOOKUP PER PANE PER BODY PASS**: 10 panes means 10 or more lookups per body pass, 20 or more per keystroke (the query is in the sidebar's search field). | *"looking up values from bundles can be expensive"* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ |
| C7 | `Shared/UI/LabelSegmentedControl.swift:258-260` into `:272-435` (unguarded writes at `:286`, `:287-299`, `:302`) | `control.setLabel(display, forSegment: index)`<br>`control.setImage(image.withSymbolConfiguration(NSImage.SymbolConfiguration(...)), forSegment: index)`<br>`control.setToolTip(display, forSegment: index)` | **THE FILE'S OWN RULE AT `:415-417`** ("THE WRITE IS GUARDED (= only write when the value differs) because writing a segment index into a control during a layout pass re-arms the window's update-constraints pass") **IS VIOLATED BY ITS OWN UNGUARDED WRITES**, plus a **freshly allocated `NSImage` per segment** (`withSymbolConfiguration` allocates a new image each time). 4 mount sites (`ChatZoneTabBar.swift:63`, `AppleSidebarView.swift:200`, `InspectorView.swift:62`, `EditorTabStrip.swift:109`; the tab strip carries one segment per open document). | *"any heap allocation, such as for a class-bound type, can add up"* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ |
| C8 | `Shared/UI/IconStyles.swift:547-551` | `styledImage.symbolEffect(.variableColor.iterative, options: .repeating)` | **A FOREVER-REPEATING SYMBOL ANIMATION**: the factory's own comment (`:538-539`) says it "loops forever while the view is mounted". 2 production call sites (`ImportSheetViewPieces.swift:186` and `:201`); the same pattern also appears at `InspectorTodoPageView.swift:181` (`.symbolEffect(.rotate, options: .repeating)`), outside this sweep's surfaces. | *"Avoid showing objects that oscillate in a sustained way. In particular, you want to avoid showing an oscillation that has a frequency of around 0.2 Hz because people can be very sensitive to this frequency."* — HIG *Motion*, https://developer.apple.com/design/human-interface-guidelines/motion |
| C9 | `Features/Cover/Model/CoverImageCache.swift:35-42` and `:54-57`, called from `Features/Cover/View/CardCoverView.swift:95` and `:103` | `private func key(for url: URL) -> String { let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]); return "\(url.path)\|\(values?.fileSize ?? 0)\|\(…)" }` | **THE CACHE KEY IS COMPUTED ON THE DISK** (`resourceValues` hits the filesystem) and it is computed **twice per card load** (once for the lookup at `:95`, once for the store at `:103`). Up to **52 filesystem metadata reads per full grid scroll-through** (26 covers x 2), on the **main actor** (the `.task` closure inherits it; only the PNG decode at `:99-101` is off-main). A card re-loads every time it scrolls back into view (`.task(id: imageURL)` at `CardCoverView.swift:76`). | same sentence as C2 (= the sentence names body work; this cost is in the `.task` path, one hop out, and the same rule applies) |
| C10 | `Features/Cover/View/LoopingCoverView.swift:169-180` (called from `:139`), `:207-212`, `:135-137` | `let item = AVPlayerItem(url: videoURL); let queue = AVQueuePlayer(); queue.isMuted = true; queue.actionAtItemEnd = .advance; player = queue; looper = AVPlayerLooper(player: queue, templateItem: item)` | **An `AVPlayerItem` plus `AVQueuePlayer` plus `AVPlayerLooper` are constructed on `.onAppear` for every video card, whether or not the pointer ever arrives.** The looper's spare copy of the clip is released only in `tearDown` (`:208`, on disappear), never when the clip is merely stopped (`:196-204` pauses and rewinds but leaves the loop armed). Per video card: 1 decoder plus 1 spare copy of the clip held for the card's whole visible life. The user has 4 `cover.mp4` today, and the count grows with every generated cover. | *"What if we move the filter into the data collection itself? Now we're back to a constant number of views per element, and only those that are needed have their row contents constructed"* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ (= the same sentence C1 sits against, = = and the one that names the defect: = = a card that is NOT on screen should NOT have its player built; Apple's rendering page praises `AVPlayer`, so the API choice is compliant; = = the defect is the EAGERNESS and the loop staying armed while stopped) |
| C11 | `Shared/UI/LibraryRootView.swift:213-231` and `:283` | `private func loadWenshuLogo(named assetName: String) -> NSImage? { ... NSImage(contentsOf: url) ... }` | **A PNG DECODE PLUS A DISK READ INSIDE A VIEW BODY**, and the function searches 3 candidate paths (bundle subdirectory, bundle root, an absolute source-tree path). Up to 3 path probes plus 1 PNG decode per body pass. Onboarding-only, so the blast radius is the first-launch screen. | same sentence as C2; plus *"looking up values from bundles can be expensive"* — WWDC23 |
| C12 | `Features/LibraryMigration/View/LibraryMigrationPanel.swift:137-139` | `ProgressView(value: state.progress, total: 1.0).progressViewStyle(.linear).animation(.default, value: state.progress)` | An animation bound to a **continuously changing progress value**: 1 default-duration animation per progress update, on every tick of a library migration. | *"In apps, generally avoid adding motion to UI interactions that occur frequently."* — HIG *Motion*, https://developer.apple.com/design/human-interface-guidelines/motion |

### D. Per sidebar reload (per selection change, NOT per frame)

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| D1 | `Features/Library/View/AppleSidebarView.swift:270-298` | `loadFolderDocCount: { [bookStore] bookId, folderName in`<br>`    ... FileManager.default.contentsOfDirectory(at: shelvesRoot, ...)`<br>`    for shelfDir in shelfDirs { ... FileManager.default.contentsOfDirectory(at: folderDir, ...)` | Per folder row the code **re-lists every shelf directory** and then re-lists the target folder to count its `.md` files. Called from `SidebarService.folderChildren(for:)` (`SidebarService.swift:311`) once per (book x user-facing folder). **MEASURED 66.209 us min / 69.375 us median per single `loadFolderDocCount` call**; the real reload's books x 5 user-facing folders = 2 x 5 = 10 calls, measured as ONE bench = **759.958 us min / 788.208 us median per sidebar reload** (= the reload is a separate bench row, = = NOT the single-call figure times ten: = = the two walk different early-exit paths). = = ⇒ ⇒ AND IT COMPOSES WITH D3: = = the same `reload()` also runs the cover reconciler's shelves walk (= = 755.000 us), = = so one reload is **1,589.667 us min** measured together. The walk is O(shelves) per call, so O(shelves x books x folders). | *"Move business logic and other non-UI work out of views to model types because SwiftUI recreates views, and recalculates view bodies, frequently."* — https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance (no Apple sentence covers "don't re-list a directory you just listed"; the nearest is the model-boundary pattern Apple names) |
| D2 | `Features/Library/View/SidebarService+ReferenceLibrary.swift:269-285` and `:244-260` (same shape at `SidebarService.swift:327-347`) | `var hasher = Hasher(); hasher.combine(raw); let hash = hasher.finalize()`<br>`let u = uuidBytes.map { String(format: "%02x", $0) }.joined()` | Each tag row and each category row builds a UUID from a **`Hasher()` seeded per process**, and formats it with **16 separate `String(format:)` calls**. **MEASURED 9.333 us min per UUID**, of which **8.042 us is the 16 x `String(format: "%02x")`** and the `Hasher` itself is **0.041 us**. The real library's **12 distinct tags** = **116.292 us min / 119.000 us median per reload**. (= The first version quoted 18 ids; the 12 tags are read out of `entities.json`, and the category rows are a classifier output, so the row count is 12 + the buckets the 12 tags vote into.) | *"any heap allocation, such as for a class-bound type, can add up"* and *"string interpolation can often be expensive, so make sure to cache any strings you might need to frequently use"* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ (`String(format:)` is the class-bound form; `FormatStyle` is the cheap form) |
| D3 | `Features/Library/View/SidebarService.swift:106-235` (`reload()`) | `CoverReconciler.live().sweep(liveReferenceIds: ..., shelvesRoot: ...)` at `:120` | `reload()` walks the whole shelves tree (every book x every folder x every file) to reconcile covers. **MEASURED 755.000 us min / 781.334 us median per full shelves walk** on the real library (2 books). **IT RUNS ON THIS CORPUS:** the guard is `guard !coverKeys.isEmpty else { return 0 }` (`CoverReconciler.swift:136`), and this library holds **26 cover folders** (= = 20 `bookDoc-` + 6 `reference-`), = = so `storedKeys()` is non-empty, = = the guard does NOT fire, = = and the walk happens. = = The number is the cost of a real reload, = = not an upper bound paid only when covers exist. = = ⇒ ⇒ The walk reaches the disk through `CoverReconciler.bookDocIds(shelvesRoot:)` (`CoverReconciler.swift:58-103`), = = which lists the shelves, = = then each book's folders, = = then each folder's files. = = ⇒ ⇒ AND IT COMPOSES WITH D1: = = the same `reload()` runs D1's ten folder counts (= = 759.958 us) = = AND this walk (= = 755.000 us), = = and measured together they are **1,589.667 us min**, = = so the reload class is about twice what the class table first quoted. | same sentence as D1 |

### E. Per launch

| # | Where | The code | Cost | Apple |
| --- | --- | --- | --- | --- |
| E1 | `Features/Library/View/SidebarService+ReferenceLibrary.swift:269-285` — identity churn, and `SidebarService.swift:327-347` — the same shape | `private static func stableReferenceTagId(_ tag: String) -> UUID {`<br>`    let raw = "wenshu.sidebar.reftag.\(tag)"`<br>`    var hasher = Hasher()` | The doc comment promises *"same tag string yields the same UUID across launches, so the persisted sidebarSelection survives reload"*. **`Hasher()` is seeded per process, so the promise is false.** **MEASURED, cross-process**: three consecutive runs of the identical replica produced `F5EB52CE-…`, `F0267C71-…`, `F0B97B25-…` for the same tag — **three different UUIDs in three launches** — while **within** one process the same call is stable. So **across launches every reference-library row's identity changes**: SwiftUI discards and rebuilds every visible row, and a persisted selection keyed by that UUID cannot resolve to the row it named. Within a session there is no churn, so this is not a per-frame defect; the cost is one full row rebuild per launch. **The same shape is ALSO used for the FOLDER rows** (`SidebarService.swift:327-347` `stableFolderId`), so the churn covers the folder rows too, not only the reference-library rows. | *"Identity helps SwiftUI manage view lifetime, which is crucial for incremental updates to your hierarchy. A change to the identity means the view changed."* — WWDC23 *Demystify SwiftUI performance*, https://developer.apple.com/videos/play/wwdc2023/10160/ (`Hasher`'s per-process seeding is a Swift language fact, not an Apple-sentence claim) |

---

## The HIG axis (= the axis the first version left unread)

The first version claimed a two-axis sweep but its HIG axis was carried
entirely by Apple *developer* pages (= the Xcode performance and
rendering-efficiency articles). Those are Apple's own words about
*performance*, but they are not the Human Interface Guidelines, and the
first version said so in its own clean list ("No HIG citation is offered
for that axis because none was read"). Revision 2 read the HIG corpus
(= 173 articles, cached locally) and found HIG sentences that sit
against the SAME code the sweep already flagged. **⇒ ⇒  THE HIG
AXIS DOES NOT ADD NEW FINDINGS. = = IT RE-SOURCES EXISTING ONES, AND
IT ADDS ONE THAT IS NOT A PERFORMANCE FINDING AT ALL.**

| HIG article | Apple's sentence | The code it sits against |
| --- | --- | --- |
| *Motion* — https://developer.apple.com/design/human-interface-guidelines/motion | *"In apps, generally avoid adding motion to UI interactions that occur frequently."* | **C5** (= the detail column animates on `globalSearchQuery`, = = the search field's interaction). Every keystroke in the settings search animates the whole column. |
| *Motion* — same article | *"Avoid showing objects that oscillate in a sustained way. In particular, you want to avoid showing an oscillation that has a frequency of around 0.2 Hz because people can be very sensitive to this frequency."* | **C8** (= the forever-repeating `symbolEffect`). HIG names the frequency sensitivity that a generic performance page does not. |
| *Motion* — same article | *"Aim for brevity and precision in feedback animations."* and *"Let people cancel motion. As much as possible, don’t make people wait for an animation to complete before they can do anything, especially if they have to experience the animation more than once."* | **C12** (= an animation per progress tick, = = and a determinate progress bar that never lets the person look away). |
| *Scroll views* — https://developer.apple.com/design/human-interface-guidelines/scroll-views | *"In all cases, automatically scroll the content only as much as necessary to help people retain context."* | **B8** (= `proxy.scrollTo` on every frame, = = scrolling far more than necessary). |
| *Scroll views* — same article | *"Avoid putting a scroll view inside another scroll view with the same orientation."* | **CHECKED, NOT A FINDING.** The board's `ScrollView` (`:132`) has no inner vertical `ScrollView` (= `KanbanView` has exactly one `ScrollView`), and the grid's `ScrollView` sits in a different column. = = The board's problem is the MISSING lazy container, not a nested one. |
| *Lists and tables* — https://developer.apple.com/design/human-interface-guidelines/lists-and-tables | *"Provide appropriate feedback when people select a list item. … a table that helps people navigate through a hierarchy persistently highlights the selected row to clarify the path people are taking."* | **CHECKED, NOT A FINDING.** The sidebar's `List` is a lazy container and the selected row does highlight. No defect found. |
| *Loading* — https://developer.apple.com/design/human-interface-guidelines/loading | *"Show something as soon as possible. … consider showing placeholder text, graphics, or animations as content loads, replacing these elements as content becomes available."* and *"Let people do other things in your app or game while they wait for content to load."* | **CHECKED, NO FINDING.** The tree uses `ProgressView` broadly, and the full-text search is off the main actor with a generation counter that discards stale results (= the shape that lets the person keep typing). No surface loads with a blank screen. |
| *Progress indicators* — https://developer.apple.com/design/human-interface-guidelines/progress-indicators | *"All progress indicators are transient, appearing only while an operation is ongoing and disappearing after it completes."* | **C12** (= an animation bound to a continuously changing value is the opposite of transient: it runs for the whole operation). |
| *Sidebars* — https://developer.apple.com/design/human-interface-guidelines/sidebars | *"In general, show no more than two levels of hierarchy in a sidebar."* | **CHECKED, NOT A FINDING.** The sidebar's own folder rows are one level under a shelf. |

**⇒ ⇒  THE ONE THING THE HIG AXIS ADDS IS NOT A
PERFORMANCE FINDING.** = = HIG's *Motion* sentence ("avoid adding
motion to UI interactions that occur frequently") is about how the app
FEELS, = = and it is the sentence that makes **C5** a HIG defect and
not merely a wasted animation. = = Every other HIG sentence above
re-sources a finding the code sweep already produced. = = That is the
honest result: = = on this tree, = = **the HIG violations are a SUBSET
of the render-path waste, not an independent second set of defects.**

---

## What was checked and is clean

- **The prior audit's settled findings are not repeated here.** The chat's markdown re-parse and the pinyin search key were DROPPED on the real data; the editor's word count was fixed upstream by commit `f0bfcedb42`; the materials-column footer scan (2,174 us) and the pinyin sort (4,039.57 us) are priced already.
- **`LibraryContentFingerprint.swift`** (the whole file) — the disk-touching cache keys are ALREADY cached in `Cache.shared` and invalidated by the `.wenshuLibraryDidChange` announcement (`:183-190`), so the disk read happens **once per library change, not once per keystroke**. `ReferenceLibraryWikiLinkResolver.fingerprint()` and `ReferenceLibraryImageProvider.fingerprint()` both route through the cache. Clean, and the shape C9 should copy.
- **`WordCounter.count(_:)`** (the six-field full count) — dead on the render path. No reader of `.words` / `.sentences` / `.paragraphs` / `.characters` / `.chineseChars` remains on a `WordCount`.
- **`NativeTextViewWrapper.updateNSView`** (vendored) — the per-update fingerprint comparisons hit the cached fingerprint above, and the comparison is a pointer/value compare, not a disk read.
- **`LibraryFullTextSearchView.swift:207-258`** — the full-text search is correctly off the main actor (`Task.detached(priority: .userInitiated)`), keyed on the query so a keystroke cancels the prior search, with a generation counter discarding stale results. **This is the shape the editor's word count should copy.**
- **`AppleSidebarView.swift:86-177`** — the `List` is a lazy container, and the row identity for shelves and books is the real store UUID. The reference-library rows AND the folder rows use synthesized ids (E1).
- **`SidebarRowView.swift:288-336`** — O(1) reads of the node. No formatter, no aggregation.
- **`EditorView.swift:436-438` (`editorIdentity`), **`EngineStyleSheetBridge.fingerprint(for:)`** — both built from real values, stable across launches and body passes. The sheet key is the shape E1 should have used.
- **`EditorView.swift:537-547` and `:556-567`** — `id: UUID()` on NEW tabs. A fresh identity for a genuinely new object is correct, not churn.
- **Zero `@Query` in view code**; all 28 `context.fetch(` calls live outside the view layer (26 in `Features/Library/Service/`, 2 in `Shared/State/LayoutTreeRepository.swift`). (= The symbol is `context.fetch(`, not `modelContext.fetch(`, = = which has 0 hits in the tree.)
- **Environment injection is fine-grained**: `AppState` 31 properties, `WorkspaceUIState` 17, `BookStore` 5.
- **Zero `GeometryReader`** across the eight non-editor surfaces.
- **Exactly ONE `DateFormatter(` in the tree** (`ChatMessageFooter.swift:209`), and it sits inside a `private static let` closure, so it is constructed once and never per body. (= "zero DateFormatter" would be false; "zero per body-pass constructions" is true.)
- **15 `.animation(` LINES in the tree = 14 live calls plus 1 commented out** (`PreviewPaneGrids.swift:301`), = = and every one of the 15 carries a `value:` = = so there is no valueless animation anywhere. (= The first version said "five".)
- **`Features/Backup/` and `Features/Companion/`** carry no View file, so they have no render path at all.

---

## What was NOT measured (the open questions)

- **`WenshuEditorServicesFactory.make` per body pass vs once per mount** (`EditorView.swift:400-415` into `WenshuEditorServicesFactory.swift:14-195`). **THE SHAPE IS CONFIRMED; THE PRODUCTION COST IS NOT WHAT THE FIRST VERSION ASSUMED.** `editorSurface` is a computed property read inside `body` (`:249` and `:286`), so the factory IS rebuilt on every body pass. But **`BookStore.reload(bookId:)` has no production caller** (= `BookStore.swift:165` is the only writer of `currentBookDirectory`, and `AppleSidebarSelection.swift:128` says so), so `currentBookDirectory` is nil, so `BookAwareWikiLinkResolver.init` builds a `BookDocumentIndex` with a nil directory (= `BookDocumentIndex.swift:44` -> `?? []`) and the 7-folder scan runs ZERO times. **MEASURED: the nil-directory path is 0.000 us min; the factory's 22 `Notification.Name` allocations are 0.125 us min.** = = ⇒  So this is NOT the biggest cost in the tree.
**⇒ ⇒  THE FIRST VERSION'S OPEN QUESTION WAS THE WRONG
QUESTION.** = = It asked "how expensive is the factory?", = = and
the honest answer is "almost free" (= 0.125 us of `Notification.Name`
allocations, = = and NO disk work at all, = = because the book
directory it would scan is nil in production). = = ⇒ 
The question that matters is the one the answer makes urgent: = = **if
someone WIRES `currentBookDirectory` (= the one-line fix that makes
`BookStore.reload(bookId:)` reachable, = = and the book document path
in `EditorView.swift:527-530` work again), = = then the factory's
per-body-pass cost jumps from 0 us to a 7-folder directory scan**
(= **188.833 us min** measured above), = = AND the body still rebuilds
it on every pass. = = ⇒  So the factory is a LATENT
LANDMINE: = = it is cheap today, = = and it becomes the editor's
largest per-body-pass cost the moment the book directory is repaired.
= = ⇒  A FIX FOR THE BOOK-DIRECTORY BUG MUST CACHE
THE SCAN, = = or it will trade one bug for a worse one.

- **`DocumentLinkIndex.linkedNames` / `bodyWithoutLinkSections` per body pass** (`DocumentLinkIndex.swift:20-27` and `:57-90`, called from `EditorView.swift:355`). The shape is confirmed; the number is not produced. O(document) per body pass on a 4,731-character document, and `linkedNames` runs **twice** per pass (once for `loadKey`, once inside `load()`).
- **`EditorView.editorEmptyDocumentPlaceholder`** (`EditorView.swift:62-75`) — an `NSAttributedString` plus `NSFont.preferredFont(forTextStyle:)` plus `NSMutableParagraphStyle` allocated per body pass. AppKit caches the preferred font, so the hypothesis is tens of us, not thousands. Unmeasured.
- **`WenshuMarkdownEditor.styleSheet`'s repeated `books.first(where:)`** (`WenshuMarkdownEditor.swift:24-29`, `:46-57`, `:160`) — O(books) x ~10 per body pass; sub-microsecond on a 2-book corpus. Its real blast radius is the `.id()` remount when a sheet changes.
- **`GlassEffectContainer` at `KanbanView.swift:139`** wraps the entire scrolling board, so any change in the middle of the board updates the whole glass group. Apple's rendering-efficiency page warns about grouping spatially distant views. Not measured.
- **`InspectorTodoPageView.swift:181`** — the same forever-repeating symbolEffect as C8, but outside this sweep's surfaces. Flagged, not audited.
- **C4's `styleMask` write cost and the runtime window count** are unmeasured; whether AppKit coalesces an idempotent `.resizable` insert was not tested.
- **C7's NSImage allocation cost** is unmeasured; the segment counts at runtime are unmeasured.
- **C10's eager-player cost** is unmeasured; the multiplier today is only 4 clips, and the finding is a growth-direction one.

---

## Every Apple quote, and how it was verified

The first version's two bad sentences both came from the same place: a
sentence that circulates in a third-party reference was attributed to
a page that does not carry it. So revision 2 checked EVERY quote
against the page it cites, by opening the page and searching its
de-tagged text (a positive control was used each time, = = a quote
known to be on that page, = = to prove the page had loaded).

**HOW TO READ THE TABLE.** = = A row's quote is the string that was
searched for on the page it names. = = A row that carries an
ellipsis (= = "A … B") is an ELISION, = = and it is certified
by its TWO HALVES: = = each half is a contiguous string on the
page, = = and the page's own wording runs on between them. = =
So a verifier searches each half separately, = = and a row is HIT
when both hit. = = A row that names ONE quote = = carries the
whole of it, = = not an abbreviation (= = an abbreviation once
hid a dropped word).

| Row | Quote (abbreviated) | Page | Verified |
| --- | --- | --- | --- |
| B1, E1 | "Identity helps SwiftUI manage view lifetime… A change to the identity means the view changed." | WWDC23 10160 transcript | **HIT** |
| B2, C2, C3, C9, C11 | "Another source is work done in body. Make sure to check for expensive string interpolation or operations like data filtering and other work inside of body." | WWDC23 10160 transcript | **HIT** |
| C6 | "looking up values from bundles can be expensive" | WWDC23 10160 transcript | **HIT** |
| C7 | "any heap allocation, such as for a class-bound type, can add up" | WWDC23 10160 transcript | **HIT** |
| C1, C10 | "only those that are needed have their row contents constructed" | WWDC23 10160 transcript | **HIT** |
| C10 (second half) | "It's important to reduce the updates to only those that are necessary." | WWDC23 10160 transcript | **HIT** |
| A1, A2 | "A common cause of long view body updates is performing expensive calculations in the view’s body property." | Xcode perf page | **HIT** (= the page uses a curly apostrophe, = = so a straight-quote match misses it; = = the reviewer who reported the C2 miss found this quote with 1 hit) |
| A1, A2 | "cache the result to avoid repeating the work every time the view needs to use the result of the calculation." | Xcode perf page | **HIT** |
| B3, D1, D3 | "Move business logic and other non-UI work out of views to model types because SwiftUI recreates views, and recalculates view bodies, frequently." | Xcode perf page | **HIT** |
| B8 | "observe layout changes in their parent views to recalculate their layouts" | Xcode perf page | **HIT** (= the page renders it "GeometryReader and ScrollViewReader", = = unspaced: = = the HTML's `<wbr>` is a zero-width break opportunity inside `<code>`, = = never a rendered space) |
| C4 | "calculate the smallest region that needs updating … so the system only updates the changed region." | Xcode rendering-efficiency page | **HIT** |
| C1 | "The stack is “lazy,” in that the stack view doesn’t create items until it needs to render them onscreen." | `LazyVStack` overview | **HIT** (= the page carries CURLY quotes and a CURLY apostrophe, = = so a straight-quote match misses it) |
| C5, C8, C12 | "In apps, generally avoid adding motion to UI interactions that occur frequently." | HIG *Motion* | **HIT** (= read from the local HIG corpus) |
| Motion, 2 | “Aim for brevity and precision in feedback animations.” | HIG *Motion* | **HIT** |
| Scroll views, 2 | “Avoid putting a scroll view inside another scroll view with the same orientation.” | HIG *Scroll views* | **HIT** |
| Lists and tables | “Provide appropriate feedback when people select a list item. … a table that helps people navigate through a hierarchy persistently highlights the selected row to clarify the path people are taking.” | HIG *Lists and tables* | **HIT** |
| Loading, 2 | “Show something as soon as possible. … consider showing placeholder text, graphics, or animations as content loads, replacing these elements as content becomes available.” and “Let people do other things in your app or game while they wait for content to load.” | HIG *Loading* | **HIT** |
| Sidebars | “In general, show no more than two levels of hierarchy in a sidebar.” | HIG *Sidebars* | **HIT** |
| C8 | "Avoid showing objects that oscillate in a sustained way. In particular, you want to avoid showing an oscillation that has a frequency of around 0.2 Hz because people can be very sensitive to this frequency." | HIG *Motion* | **HIT** (= the WHOLE sentence is certified, = = because an abbreviation once hid a dropped word in it) |
| C12 | "All progress indicators are transient, appearing only while an operation is ongoing and disappearing after it completes." | HIG *Progress indicators* | **HIT** |
| C12 (Motion) | "In apps, generally avoid adding motion to UI interactions that occur frequently." and "Let people cancel motion. As much as possible, don’t make people wait for an animation to complete before they can do anything, especially if they have to experience the animation more than once." | HIG *Motion* | **HIT** (= the page carries a CURLY apostrophe in "don’t", = = and the sentence runs on past "anything" (= = "...anything, especially if they have to experience the animation more than once."), = = so the quote above is the page's WHOLE sentence, = = not an elision of it) |
| B8 | "automatically scroll the content only as much as necessary to help people retain context." | HIG *Scroll views* | **HIT** |

**THE TWO QUOTES THE REVIEW FOUND ABSENT ARE GONE, AND SO IS A THIRD
ONE THE REVIEW DID NOT FLAG.** C10's quote ("only work that is required
for the current state should happen for the current frame") is NOT on the
WWDC23 page either (0 hits, and the phrase "current frame" appears
nowhere in the 21,763-character transcript). It was the same third-party
attribution, in a row the reviewer's three sampled rows did not happen to
include. So the document now carries a table of EVERY Apple quote and
whether it verified.

---

## The corrections this revision makes (= the review's list, answered)

| The review said | What this revision does |
| --- | --- |
| CHECK 2 FAIL: every MEASURED number is inflated 2-3x by concurrent compiles; the old harness averaged | **Re-measured with a min/median/p95 harness** (= the minimum is the load-independent floor). The comparison table at the top lists every number, old and new. The probe file is `probe4-contention-robust.swift`. |
| "A1+A2 no longer crosses the 500 us threshold" | **Confirmed and adopted.** A1+A2 is 276.042 us min. The class table, the "22x" comparison, and rule 1's sentence are all re-derived. The per-keystroke class drops OUT of the "above threshold" set. |
| "The class table's 14,860 us is a sum of inflated numbers" | **Confirmed, and then corrected AGAIN**: the class table's reload figure was D1's ten counts ALONE (759.958 us), = = but one reload also runs D3's shelves walk (755.000 us), = = and measured together they are **1,589.667 us min**. = = The ratio to the per-keystroke cost becomes about 5.8x. |
| "D2's 18-id arithmetic is internally inconsistent by 2.007x" | **Confirmed and corrected.** The row count is **12 distinct tags** (read out of `entities.json`, which is a 6-item LIST; the first probe cast it to a dict and found 0 tags). The category rows are a classifier output, not a stored field. The 12-tag id cost is **116.292 us min**. |
| CHECK 4 FAIL: C2's two sentences are absent from the cited page | **Confirmed and fixed.** The two sentences ("only work that is required for the current state should happen for the current frame" and "The winning pattern is precomputation at the model boundary") are NOT on the WWDC23 10160 page (0 hits in the de-tagged text, 0 in the raw HTML, while 5 other quotes from the same page hit). They are replaced by the sentence the transcript DOES carry: *"Another source is work done in body. Make sure to check for expensive string interpolation or operations like data filtering and other work inside of body. It's important that body itself is as cheap as possible."* |
| "8 statuses" | **Corrected to 7** (the store's own distinct `ZSTATUS` values), and the 8 *columns* the board renders are now named as a different number. |
| "1,227 characters" / "10,996 characters" are bytes | **Corrected.** The longest assistant reply is 532 characters; the largest library reference is 4,731 characters; the byte counts are dropped. |
| "29 covers" | **Corrected to 26** (26 `.heic` + 4 `.mp4`), and C9's ceiling becomes 26 x 2 = 52. |
| "Only the reference-library rows use synthesized ids" | **Corrected.** `SidebarService.swift:327-347` `stableFolderId` is the same shape, so E1 now covers the folder rows too. |
| "`modelContext.fetch` does not exist" | **Corrected.** The symbol is `context.fetch(` (= 0 hits for `modelContext.fetch(`), 28 calls, 26 in `Features/Library/Service/` and 2 in `Shared/State/LayoutTreeRepository.swift`. |
| "Zero DateFormatter is false" | **Corrected.** Exactly one `DateFormatter(` exists, inside a `private static let` (= constructed once, never per body), so the claim is now "zero per body-pass constructions". |
| "15 `.animation` calls, not five" | **Corrected** (all 15 do carry a `value:`). |
| "25 Notification.Names not 25" | **Corrected to 22** (`WenshuEditorServicesFactory.swift:221-244`). |
| "7 directory listings" is one call in a loop | **Corrected.** The scan is 1 `contentsOfDirectory` call per folder, 7 folders, 1 book. |
| "521 tasks / 469 with a body" | **Corrected to 542 / 490** (= corpus drift), and the corpus table now carries the measurement time. |
| "The doc's HIG axis read no HIG article" | **Addressed.** A HIG axis section was added, reading the HIG corpus directly. It re-sources C5, C8, C12 and B8, and records four HIG checks that found NO defect. |

---

## The rules this sweep paid for

1. **Classify the path before ranking.** A per-launch cost, a per-reload
   cost, a per-keystroke cost and a per-frame cost are four different
   classes. Ranking them by raw microseconds lets a 1,590 us one-shot
   hide behind a 276 us per-keystroke number, and hides the one the user
   feels most often.
2. **Measure the FLOOR, not the mean.** A mean is the statistic that
   background load inflates. The minimum over many reps is the
   load-independent estimate of what the code path costs.
3. **Identity is a cost, not just a correctness property.** A row whose
   id is re-minted per frame costs a full subtree rebuild per frame; the
   `UUID()` is one allocation, the rebuild is the cost.
4. **Measure on the user's real corpus.** A synthetic corpus rescaled a
   number 6x, reordered the findings, and dropped two of them.
5. **A `.help(String)` is eager.** Any tooltip built in the body is
   built on every body pass, whether or not anyone hovers.
6. **A cache key that touches the disk makes the lookup an I/O.** The
   key must be derived from data already in hand (D2's `String(format:)`,
   C9's `resourceValues`).
7. **A cheap call can become an expensive one.** The editor factory is
   free today because the book directory is nil, and becomes a
   per-body-pass directory scan the moment that bug is fixed. = = The
   cost of a call that is currently disabled must be measured BEFORE
   the bug that disables it is fixed.
