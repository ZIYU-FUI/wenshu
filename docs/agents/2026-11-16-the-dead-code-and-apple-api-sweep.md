# 2026-11-16 — The dead-code sweep and the Apple-API sweep

The tree at `main` = `58dd224bb7`, measured (= = and the numbers hold on
the later `main` too: = = the branch was rebased onto `0994a54f9` and
re-measured, = = and the file count and every bucket came out the same).
Two questions, one method: what code can no production path reach, and
what the tree wrote by hand that Apple already ships.

Every number below is re-derivable by one command:

```bash
python3 Tools/wenshu-devtool/dead-sweep-measure.py
```

The script prints its own method under every number, so a reader who
disagrees with a number changes the script, not the claim.

## The headline

**The tree's own dead-code gate looks at 22% of the tree's production
files; the same gate at full scope sees 36 files with unread declarations,
and 66 declarations in them.** The gate's default scope is ten view
directories (= **131 of the tree's 602 production files** = 21.8% = = and
29,200 of 118,251 production lines = 24.7%). ⇒ **So the gate that §7.6
names has never looked at `WenshuAgent`, `WenshuData`, `Board` or
`Mobile`** (= = four of the five production roots), = = and in the ten it
does look at it finds **3** files with unread declarations (= = plus 1
`EMPTY`), = = against the **34** the same tool finds (= = plus 2 `EMPTY`)
when it is pointed at the whole tree.

⇒ **And "36" is what the tool PRINTS.** ⇒ Its own summary line has no
`EMPTY` row, = = so it counts a file with no top-level declarations as
`PARTIAL`. ⇒ **34 of the 36 carry an unread declaration; = = 2 are
`EMPTY`** (= = no declarations at all). ⇒ Both numbers are printed by the
script (§A3), = = because a reader who runs the tool sees 36 and a reader
who reads the record must be able to reconcile the two.

⇒ And **CI never runs the gate at all**: `verify-dead.py` is called by
`Tools/wenshu-devtool/pre_review_gate.py` (= the pre-review gate, = a
process gate) and by nothing in `.github/workflows/ci.yml` and nothing in
`Scripts/`. A dead file can land on `main` and the tree stays green.

⇒ And **the Apple side has one finding that is not a "we could modernise
this" note: the app replaces the system's own Undo/Redo menu with two
buttons whose action is empty.** `⌘Z` in the editor still works (= the
vendored markdown engine supplies a per-document `UndoManager` to the
`NSTextView`), but the Edit menu's Undo and Redo items do nothing, and
the tree's own layout undo stack (`TreeHistory`) is unreachable. See
§"The Apple answers" below.

⇒ And **the tree's own dead-code gate has TWO blind spots of its own**:

- it counts a reference by **NAME**, = so `UUID.literal` (= a different
  type's member with the same name) makes `NSRegularExpression.literal`
  look alive. ⇒ A 45-line file with **zero** production call sites has
  survived the gate since 2026-10-21. ⇒ See §4a;
- it skips a **same-file call site** whose line starts with a modifier,
  = = so a declaration the file itself calls reads as dead. ⇒ **8 live
  declarations** are reported dead today. ⇒ See §3.

⇒ ⇒ **And the second one found a live bug**: = one of those 8 is a line
that shadows Apple's own `AVSpeechUtteranceDefaultSpeechRate` (= **0.5**)
with a self-reference (= **0.0**). ⇒ See §3 and proposal 11.

## §1 The scope

The scope is `Sources/ Tests/ Board/ Mobile/`, because the default scope
of the tree's own tool misses four of the five production roots.

| Root | Production Swift files |
| --- | --- |
| `Sources/` (= `WenshuApp` + `WenshuAgent` + `WenshuData`) | 571 |
| `Mobile/` | 22 |
| `Board/` | 9 |
| **total** | **602** |

The scan skips every path with a `Tests` component and every `.build`
directory, so a test file is never counted as production.

## §2 What the tree's own tool says (= the authority)

`Tools/wenshu-devtool/verify-dead.py` is the tree's dead-code gate
(§7.6). It was run two ways:

| Run | Files | ALIVE | PARTIAL | DEAD | EMPTY |
| --- | --- | --- | --- | --- | --- |
| its default scope (= what §7.6 runs) | 131 | 127 | **3** | 0 | **1** |
| full scope (`--scope 'Sources/ Tests/ Board/ Mobile/'`) | 602 | 566 | **34** | 0 | **2** |

⇒ **The default scope's own summary prints `PARTIAL: 4`** (= = 3 with an
unread declaration + **1** `EMPTY` = = `Features/Kanban/View/
SubAgentProgressView.swift`, = = a file with no top-level declaration). ⇒
⇒ **So the two conventions apply at BOTH scopes**, = = and this table uses
the split (= = the `EMPTY` column is real), = = while the tool's summary
prints the folded number. ⇒ The script prints both at both scopes.

⇒ **34 files carry at least one unread declaration** (= `PARTIAL`), and
**no file is wholly dead** (= `DEAD` = 0). The 66 unread declarations sit
in those 34 files.

⇒ **And the tool's OWN summary prints 36, = = not 34.** ⇒ Its summary has
no `EMPTY` row (= = three numbers, = = and they must add up to the file
count), = = so it counts the **2 `EMPTY`** files as `PARTIAL`:

```
Summary: 602 files
  ALIVE   (= all decls have real refs):  566
  PARTIAL (= some decls dead):            36
  DEAD    (= all decls dead):             0
```

⇒ ⇒ **So the two numbers are the same measurement read two ways**: = = the
tool's summary says **36** (= = 34 with an unread declaration + 2 `EMPTY`);
= = this table's split says **34** + **2**. ⇒ **The headline quotes 36**,
= = because that is what a reader who runs the tool sees; = = and this
table's split is the refinement. ⇒ The script prints **both** (§A3), = =
because a record that quotes one and not the other sends the next reader
to the wrong number.

⇒ **And the command that reproduces the full-scope row is not
`--scope` alone.** ⇒ `--scope` is the tool's **GREP** scope (= = where it
looks for a name); = = the **file list** is what selects the files, = = and
with no file argument the tool auto-scans its ten view directories (= = the
131). ⇒ ⇒ **So the full scope needs the file list**:

```
python3 Tools/wenshu-devtool/verify-dead.py --scope 'Sources/ Tests/ Board/ Mobile/' \
  $(find Sources/WenshuApp Sources/WenshuAgent/Sources Sources/WenshuData/Sources \
         Board/Sources Mobile/Sources -name '*.swift' -not -path '*/Tests/*' \
         -not -path '*/.build/*' | sort)
```

⇒ **And the script prints that exact command** (= §A3), = = because the
file list is what the measurement runs on.

⇒ **And the default scope is 131 of the tree's 602 production files**
(= 21.8% by file, = = 29,200 of 118,251 production lines = 24.7%; = = the
script prints both denominators in §A1b), = = and
it is **ten directories**, = all under `Sources/WenshuApp/`:
`Features/Agent/View`, = `Features/Chat/View`, = `Features/Chrome/View`,
= `Features/Cover/View`, = `Features/Editor/View`, = `Features/Kanban/View`,
= `Features/Library/View`, = `Features/LibraryMigration/View`, =
`Features/Settings/View`, = and `Shared/UI`. ⇒ **So four of the five production roots
(`WenshuAgent`, `WenshuData`, `Board`, `Mobile`) are outside the gate's
scope**, = = and the app's own non-view layers (= its `Shared/`, = its
`Features/*/Service/`, = = its `Features/*/Model/`, = = its `Features/*/Store/`)
are outside it too.

### The same gate at the 2026-11-02 baseline (= the delta)

The last full-scope measurement was at `e9a85dcad9` (= the
`2026-11-02-project-inventory` tree). ⇒ **The script prints this itself**
(= §A3b: = it exports the baseline with `git archive`, = = runs the
**current** tool over it at the same scope, = = and counts the verdicts):

| Tree | Files | ALIVE | PARTIAL | DEAD | EMPTY |
| --- | --- | --- | --- | --- | --- |
| `e9a85dcad9` (= 2026-11-02) | 510 | 474 | **34** | 0 | 2 |
| `58dd224bb7` (= now) | 602 | 566 | **34** | 0 | 2 |

⇒ **Both trees' tool summaries say 36 `PARTIAL`** (= = 34 + the 2 `EMPTY`
files, = = the same convention as §2's table above), = = so **the delta is
flat in EITHER convention**: = = 34 → 34 and 36 → 36.

⇒ The tree **grew by 92 production files** and the number of files
carrying a dead declaration **did not change** (= 34 at the baseline, = =
34 now). ⇒ ⇒ **So the residue is FLAT, = = not falling**: = = the tree
grew by 92 files and carried the same 34 files with an unread declaration
through the whole growth. ⇒ The residue is not accumulating either (= = it
is the same 34 files, = = plus the 52 bare declarations inside them, = =
whose names the earlier sweep's residue used to carry). ⇒ The residue
that remains is listed below.

⇒ **And the first draft of this record had the baseline at 36, = = which
was WRONG** (= = the review caught it). ⇒ The 36 came from a file list
built by a plain `find`, = = and that list included the three
`Package.swift` manifests (= = `Mobile/Package.swift`, = =
`Sources/WenshuAgent/Package.swift`, = = `Sources/WenshuData/
Package.swift`). ⇒ ⇒ **The five production roots are the SOURCES
subtrees** (= `Sources/WenshuApp`, = `Sources/WenshuAgent/Sources`, = =
`Sources/WenshuData/Sources`, = `Board/Sources`, = `Mobile/Sources`), = =
so a manifest that sits beside the sources (= = at `Mobile/`, = = not at
`Mobile/Sources/`) is **outside every root** and never enters the count.
⇒ The `find` list had **513** files; = = the script's own
`production_files` has **510**. ⇒ **510 is the count in the table**, = =
and the script prints it, = = so the number is re-derivable.

## §3 Every unread declaration, adjudicated

The tool's own `✗` list (= 66 names) was then adjudicated in this order:

1. the **framework mandate** (= SwiftData reads it by design);
2. **the tool's own `local_uses`** (= a use in the declaring file counts,
   so the declaration is ALIVE);
3. the name matched against every **other** production file **twice**: once
   with comments and string contents removed (= real code) and once against
   the raw text (= comments count too).

| Bucket | Count | Meaning |
| --- | --- | --- |
| the framework reads them | 2 | SwiftData reads them by design (= see below) |
| only a comment names them | 4 | the code is gone; a docblock still says so |
| **the file itself calls them** | **8** | **ALIVE: = the declaring file uses it** |
| nothing names them | **52** | the code and every mention of it are gone |
| a code reference exists | 0 | = the tool is right and the name is live |

⇒ **2 + 4 + 8 + 52 = 66.** ⇒ The real residue is the **52** + 4 + 2.

⇒ **The 8 are the tool's SECOND blind spot, and the first draft of this
record got them wrong.** ⇒ The tool's `has_real_ref` skips a same-file
line whose first token is a `DECL_PREFIX` (= `private `, `static `,
`fileprivate `, `final `), = = because such a line usually declares
something. ⇒ But a same-file **call site** written as `private let x =
Foo()` is skipped too, = = so the declaration reads as unread even though
the file calls it. ⇒ The eight:

| Declaration | File | The call site the tool skipped |
| --- | --- | --- |
| `resolveStableSigning` | `WenshuAgent/Keychain/MirroredKeychainStore.swift` | `private static let stableSignedOnce: Bool = resolveStableSigning()` |
| `WSMemoryMirror` | `WenshuAgent/Memory/WSMemoryProvider.swift` | `private let mirror = WSMemoryMirror()` |
| `jpegQuality` | `Features/Cover/Model/CardCoverImageEncoder.swift` | `static func decodeToJPEG(…, quality: Double = jpegQuality)` |
| `liveSnapshot` | `Features/Editor/Model/EditorPreferences.swift` | `static let live = EditorPreferences.liveSnapshot()` |
| `RowState` | `Features/LibraryMigration/View/LibraryMigrationPanel.swift` | `private func stageRow(…, state rowState: RowState)` |
| `ConductorSnapshot` | `Shared/Agent/WenshuAgent.swift` | `fileprivate static let conductorSnapshot = ConductorSnapshot()` |
| `CachedProviderList` | `Shared/Agent/WenshuAgent.swift` | `private static let cachedSnapshot = CachedProviderList()` |
| `AVSpeechUtteranceDefaultSpeechRate` | `Features/Agent/Service/AVMediaTools.swift` | see the note below |

⇒ **So the tool has TWO blind spots, not one.** The first (§4a) counts a
reference by **name**, so `UUID.literal` keeps `NSRegularExpression.literal`
alive. The second is this one: it skips a **same-file call site** whose
line starts with a modifier. ⇒ **Proposal 9 must fix both**, = = and the
second one is the more dangerous of the two, = = because it reports a
**live** declaration as dead.

### The eighth one is a live bug, not a dead declaration

`AVMediaTools.swift:72` reads:

```swift
private let AVSpeechUtteranceDefaultSpeechRate: Float = AVSpeechUtteranceDefaultSpeechRate
```

⇒ That **shadows Apple's own constant with itself**. `AVFoundation`
exports `AVSpeechUtteranceDefaultSpeechRate` (= **0.5**, = `AVFAudio.
framework/Headers/AVSpeechSynthesis.h:47`); = = the file-scope `private let`
binds the name to **its own initializer**, = = which Swift evaluates to
**0.0**.

⇒ **The measurement, and the ONE way to read it**: = = the shadow binds
the name for the **whole file**, = = so Apple's value must be read from a
**different file**. ⇒ Two standalone probes: = = one file with only
`import AVFoundation` + a print of Apple's constant prints **0.5**; = =
one file with the tree's line + the same print prints **0.0**. ⇒ ⇒ **The
tree shadows a system constant with a zero.** ⇒ (A probe that prints both
in ONE file reads **0.0** twice, = = because the shadow is already in
scope; = = that is the shadow working, = = not Apple's value changing.) ⇒ Nothing reads it today (= the name appears
exactly once in the whole repo, = on that line), = = so the value is
harmless **today**; = = but the next `speechRate:` that anyone writes in
that file gets **0.0** (= silence), = = not Apple's 0.5. ⇒ **This is a
one-line deletion**, = = and it is also the clearest example of the
record's own theme: = the tree wrote a line that **looks like** it uses
Apple's API and instead **defines a different constant with Apple's
name**.

### The two the framework reads (= do NOT delete)

| Declaration | File | Why the framework reads it |
| --- | --- | --- |
| `ModelsSchemaV1.versionIdentifier` | `Sources/WenshuData/Sources/WenshuData/ModelsSchema.swift` | `VersionedSchema` requires it |
| `WSChatMessage.toolResultsJSON` | `Sources/WenshuData/Sources/WenshuData/WSChatMessage.swift` | a SwiftData persisted property |

Both are protocol requirements, not call sites. A grep for a call site
finds none, and none should exist.

### The four a comment still names

| Declaration | File | The comment says |
| --- | --- | --- |
| `BoardElement.containers` | `Board/Sources/WenshuBoardKit/BoardElement.swift` | a field the board's element carries |
| `DesignTokens.avatarSize` | `Sources/WenshuApp/DesignTokens.swift` | a token the design system names |
| `tagContainsPunctuation` | `Sources/WenshuApp/Features/Agent/Service/WenshuConductorImportRouterHelpers.swift` | a helper the router used |
| `recordSubAgentRun` | `Sources/WenshuApp/Features/Agent/Store/ConversationOps.swift` | a call the conversation used |

⇒ The comment is the residue's tombstone. The code is gone; the sentence
that described it stayed.

### The fifty-two nothing names

The list is printed in full by the script (`the bare list`). Its shape:

| Area | Count | The examples |
| --- | --- | --- |
| `WenshuApp` `DesignTokens` | 23 | `bodyFontSize`, `captionFontSize`, `kanbanColumnWidth`, `textPlaceholder`, … |
| `WenshuAgent` | 13 | `MemoryManager.SyncResult`, `MemoryAdapter.setEnabled`, `MirroredKeychainStore.hasDeveloperID`, `ContextEngine.shouldCompressPreflight`, … |
| `WenshuApp` features | 12 | `AppNotifications.wenshuToggleEditMode`, `ImportDocumentTemplates.commonHeader`, `OAuthFlow.base64URLEncodedString`, `EditorPreferences.engineDefault`, … |
| `WenshuData` | 2 | `WSChatRepository.saveContextTrick`, `WSChatRepository.subAgentRunPredicate` |
| `Mobile` `DesignTokens` | 2 | `DesignTokens.cornerRadiusCard`, `DesignTokens.cornerRadiusControl` |

⇒ **23 + 13 + 12 + 2 + 2 = 52.** The 25 `DesignTokens` (= 23 app + 2
mobile) are in the design system's own dead-token list (§4), = and the
tree's `DeadDesignTokensSweepTests` already prints them.

## §4 The design tokens nothing reads

The tree's own sweep prints its set; its own comment says the assertion
is downgraded to a non-blocking record (= the suite records, = it does not
fail).

| Set | Count |
| --- | --- |
| `WenshuApp` `DesignTokens` the tool calls unread | 24 |
| `WenshuMobileApp` `DesignTokens` the tool calls unread | 2 |

⇒ **26 design tokens are declared and read by nothing.** They are not a
crash risk and not a user-visible cost; they are a design system that
carries a ladder of sizes no surface uses. The full list is printed by the
script (`the app tokens the TOOL calls unread`).

⇒ **The 24 app tokens and the 2 mobile ones live in two files**
(= `Sources/WenshuApp/DesignTokens.swift` = = and
`Mobile/Sources/WenshuMobileApp/Shared/UI/DesignTokens.swift`).

⇒ **And 25 of the 26 appear in §3's bare list, = = not 24.** ⇒ The gap is
**one token**: = `avatarSize`. ⇒ It is **not** in the bare list because a
**comment names it** (= §3's comment-only bucket, = = the one app token
that is), = = so it is unread too, = = just not unread in the same way.
⇒ **24 app + 2 mobile = 26; = = 23 app bare + 1 app comment-only
(`avatarSize`) + 2 mobile bare = 26.**

⇒ **Deleting a token needs NO suite edit.** ⇒ The review checked this:
`DeadDesignTokensSweepTests`'s named-token test asserts that **9** tokens
are **ABSENT** (= `formLabelWidth`, = `settingsRowSpacing`,
= `chatInputMinWidth`, = `toolbarBandHeight`, = `popoverMaxHeight`,
= `chipAvatarSize`, = `formColumnWidth`, = `chromeHeight`,
= `accentTintOpacitySubtle`) = = and **none of those 9 is among the 26**.
⇒ Its live test (**"Zero dead DesignTokens with 0 callers in production"**)
**scans the file dynamically** (= it regexes every `static let <name>:`
declaration and looks for callers) = = so deleting a token needs no
change to the suite at all. ⇒ Its detection is a **non-blocking print**
(= the suite's own comment says the assertion is "downgraded to a
non-blocking info record"), = = so the suite does not fail today either.

## §4a The gate's own false negative (= one type's member counts for another)

`verify-dead.py` counts a reference **by NAME**. ⇒ So when two DIFFERENT
types declare the same member name, one type's call sites satisfy the
other's count. ⇒ The sweep measured this class across the whole tree:

| | Count |
| --- | --- |
| masked declarations (= every qualified external mention names a **different** owner) | **1** |

⇒ **One clean case**, and it is a real one:

| Declaration | File | The gate's count | The truth |
| --- | --- | --- | --- |
| `NSRegularExpression.literal` | `Sources/WenshuApp/Shared/Foundation/NSRegularExpression+Literal.swift` | the gate counts the NAME `literal` (= every occurrence of it outside this file, = = including `UUID.literal`'s) = = **53 external refs** (= ALIVE) | **0 production call sites** |

⇒ The name `literal` is declared by **two** types (= `UUID.literal` in
`UUID+Literal.swift` = = a different type with the same member name), = =
so the gate's count for one is the count for the other. ⇒ ⇒ **The gate's
own external count for the name `literal` is 53** (= = measured by calling
the gate's own `has_real_ref`, = = not by a grep), = = and that is what
kept the helper ALIVE. ⇒ The `NSRegularExpression` helper's file (45 lines) **has had no
production caller since `4c5b7748c9`** (= 2026-10-21, = "delete the
production types that only tests reach", = the commit that removed
`ReferenceEntityExtractor.swift` and `SmartQueryTrivialGate.swift`, = = the
last two files that called the helper). ⇒ **The two dead-code commits of
2026-10-21 between them took the CALL-SITE count from 10 to 0**
(= `d9ea3d0bc` = 10 → 9, = `4c5b7748c9` = 9 → 0), = and the gate
reported the helper ALIVE through both, = because the name still had
`UUID.literal`'s references. ⇒ ⇒ **The full chain, measured over the
history** (= the script prints it in §A9):

| Commit | Production call sites of `NSRegularExpression.literal(` |
| --- | --- |
| `d765169b69` (= the helper lands) | 12 |
| `4600919bf` | 11 |
| `5c94e5d5de` | 10 |
| `d9ea3d0bc~1` (= before the first dead-code commit) | 10 |
| `d9ea3d0bc` | 9 |
| `4c5b7748c9~1` (= before the second) | 9 |
| `4c5b7748c9` | **0** |
| `HEAD` | **0** |

⇒ **The count is the CALL-SITE count**, = = with the helper's own docblock
excluded (= = a mention in a comment is not a call). ⇒ ⇒ **It is a
DIFFERENT number from the gate's count**, = = and that difference IS the
finding: = = the gate counted the NAME (25 → 34 → 59 external mentions as
the tree grew), = = while the CALL SITES fell to zero. ⇒ **A gate that
counts a name it should not count cannot see a file die.**

⇒ ⇒ ⇒ **The tree's own gate is the reason this file survived.** It is
not a false positive of this sweep; it is a **false negative of §7.6's
gate**, and the gate is the thing the tree trusts. ⇒ This is the one
finding in this document that is about the gate itself rather than about
the code.

⇒ **The fix is in the gate, not in the tree**: a reference to a member
must match the **receiver**, not the bare name. ⇒ The sweep's own §A9
lens is the reproducer (= it prints this one case, = and prints nothing
else, = so a reader can check both directions).

⇒ **The same class, one level up**: `UUID.literal`'s only 4 call sites
are in `Sources/WenshuApp/Shared/State/LayoutTreeState.swift`, = which is
inside the **closed** layout-tree group (§6). ⇒ So `UUID+Literal.swift`
(41 lines) is reachable only from a closed group, = it becomes dead the
moment that group goes.

## §5 The files no production code can name (= the strict island)

A file is an **island** when no OTHER production file's code names any of
its declarations. This lens needs no reachability chain, = it cannot be
broken by a dispatch the name graph cannot see (= a protocol witness, a
member reached through a value, a name built at run time).

⇒ **6 files, 384 lines:**

| File | Lines | What it holds |
| --- | --- | --- |
| `Sources/WenshuAgent/.../Tool/ToolResultClassification.swift` | 89 | the tool-result classifier |
| `Sources/WenshuApp/Features/Agent/View/MemoryRetrievalPanel.swift` | 78 | the memory-retrieval panel + row |
| `Sources/WenshuApp/Features/Agent/View/SpecializedToolBodyModifier.swift` | 55 | the specialised-tool body modifier |
| `Sources/WenshuApp/Features/Editor/Service/CardCompletionService.swift` | 75 | the card-completion service |
| `Sources/WenshuApp/Features/Editor/View/EditorExpandShrinkTrailingButton.swift` | 77 | the editor's expand/shrink button |
| `Mobile/.../App/WenshuMobileApp.swift` | 10 | the mobile app's `@main` (= **NOT dead** = it is the entry point) |

⇒ **5 real islands** (= 374 lines). The mobile one is the app's own
`@main`, = an entry point by construction, = it is listed so the number
is falsifiable.

⇒ **And §4a adds a sixth**, which this lens cannot see (= the gate
counts a different type's member as its reference):
`Sources/WenshuApp/Shared/Foundation/NSRegularExpression+Literal.swift`
(45 lines).

⇒ `MemoryRetrievalPanel` and `EditorExpandShrinkTrailingButton` are the
two the tree's own comments describe as *no longer* used:
`AppNotifications.swift:119-121` says the maximized-notification pair is
"no longer observed by EditorExpandShrinkTrailingButton", and
`ChatMessageView.swift:345` says the hover actions are gone.

## §6 The closed groups (= a group nothing outside can reach into)

A **closed group** is a set of files where no production file outside the
group names any of the group's own types. The group list is the claim,
so it is checkable: edit a membership, re-run, and the verdict changes.

| Group | Files | Lines | Verdict |
| --- | --- | --- | --- |
| the layout-tree family | 9 | 2,021 | **CLOSED** |
| the settings credential family | 6 | 1,247 | **CLOSED** |
| the superseded streaming files | 4 | 576 | **CLOSED** |
| the test-only production files | 2 | 164 | **CLOSED** |

⇒ **4 closed groups, 4,008 lines** (= 3.4% of the production tree) that
no production path can reach.

### The layout-tree family (= `Shared/State/`)

`LayoutTreeStore`, `LayoutTreeRepository`, `LayoutTreeState` (+ its four
extensions), `TrackModel`, `TreeHistory`.

⇒ `LayoutTreeStore` has **no constructor point** anywhere in production
and no `LayoutTreeStore.shared` read. `LayoutTreeRepository` is the only
writer of `WSLayoutTreeState`, and that state has no reader outside the
group. ⇒ `OOB.md`'s "no global free layout" decision and this island
agree.

⇒ **BUT the deletion price is not the file count**: `WSLayoutTreeState`
is a SwiftData `@Model`, = deleting a model class IS a cardinality flip,
= it costs a schema version. Read `Sources/WenshuData/Sources/WenshuData/Container.swift`
before pricing it. (The dead-feature-audit skill's own rule: a comment
that predicts a cost is not evidence of one = probe it.)

⇒ `TreeHistory` is the hand-rolled undo stack = see §"The Apple answers".

### The settings credential family (= `Features/Settings/Service/`)

`AuthPool`, `AutoRotation`, `FallbackChain`, `KeychainSelector`,
`RetryUtils`, `SecretScope`.

⇒ The **live** provider path is `ProviderKeychain` (=
`WenshuAgent/Keychain/ProviderKeychain.swift`), read and written by
`Sources/WenshuApp/Features/Settings/View/SettingView+Providers.swift`.
`KeychainSelector` and `AuthPool` are a **second, parallel** credential
layer that nothing in the provider UI touches.

⇒ `FallbackChain`, `RetryUtils` and `SecretScope` are a hand-rolled
retry/fallback/secret-scope layer. Apple ships no equivalent for the
credential half (= this is the app's own design), so **this group is a
removal candidate, not a migration candidate.**

⇒ `AutoRotation` and `FallbackChain` each carry a private logger
(`wenshuRotationLogger`, `wenshuFallbackLogger`) that nothing names.

### The superseded streaming files

`SSEClient`, `WAStreamDiag`, `WAStreamWatchdog`, `ToolGuardrails`.

⇒ The **live** SSE path is `Sources/WenshuAgent/Sources/WenshuAgent/Streaming/SSEReader.swift`,
which uses `EventSource.Parser`. `SSEClient` has no production
constructor.

⇒ `Vendor/MarkdownEngine`'s `NativeTextViewCoordinator+TextDelegate.swift`
= the vendored engine, = and it IS a per-document `UndoManager` (= see
§"The Apple answers").

### The test-only production files

`ToolResultClassification.swift`, `CardCompletionService.swift`.

⇒ Two files whose only readers are tests. **Test-only means unreachable
from production, not disposable** (= the dead-feature-audit rule): a
project standard or a conformance test may require the artifact to
exist. ⇒ Before deleting either, name what requires it.

## §7 The Apple answers (= "Apple already ships this")

Every API below was read **off the installed SDK on disk**, not from a
paraphrase:

```
/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
```

| API | Where the SDK carries it | The tree's own user | Strength |
| --- | --- | --- | --- |
| `SecStaticCodeCreateWithPath` + `SecCodeCopySigningInformation` | `Security.framework/Headers/SecStaticCode.h`, `SecCode.h` | `MirroredKeychainStore` shells out to `/usr/bin/codesign` and parses its text (**2** production sites) | **strong** |
| `UndoManager` | `Foundation.framework/Headers/NSUndoManager.h` | `TreeHistory` (a hand-rolled undo stack; = = 3 call sites, = = **all 3 inside its own file**, = = **0 outside**) | **medium** |
| Swift `Regex` | `_StringProcessing.swiftmodule` | **21** live `NSRegularExpression(...)` call sites across **10** production files | **medium** |
| `CollectionDifference.difference(from:)` | `Swift.swiftmodule` | `DiffUtil`'s hand-rolled LCS (**2** call sites) | **partial** |
| `NLTokenizer` | `NaturalLanguage.framework/Headers/NLTokenizer.h` | two hand-rolled tokenizers (= 2 definitions, = = **6** call sites) | **partial** |
| `Synchronization.Mutex` | `Synchronization.swiftmodule` (= macOS 15+) | **21** `NSLock()` sites (= production only) | **partial** |

### The strong one: the signature read

`Sources/WenshuAgent/Sources/WenshuAgent/Keychain/MirroredKeychainStore.swift`
spawns **`/usr/bin/codesign`** and parses its stderr text to learn whether
the running binary carries a Developer ID signature (`resolveStableSigning`,
`codesignDescription(of:)`, `hasDeveloperID(binaryAt:)`).

⇒ Security.framework ships the same answer as a **C API**:
`SecStaticCodeCreateWithPath` (= read the code on disk) +
`SecCodeCopySigningInformation` (= read its signing information, = the
`kSecCodeInfoCertificates` key). ⇒ The subprocess, the stderr parsing, and
the ad-hoc-signature string comparison all go away.

⇒ **The migration must not change the policy**: `OOB.md` and §2.6 decide
that the provider key has a plaintext mirror at
`~/Library/Application Support/com.wenshu.app/provider-keys.json` (mode
0600). Only the **signature read** changes; the mirror decision does not.

⇒ This is the one case where the tree's own answer is *wrong in kind*:
a subprocess whose output format Apple does not promise, parsed as text.

### The medium one: the undo stack, AND the empty Edit menu

Two findings, and the second is the bigger one.

**(a) `TreeHistory` is a hand-rolled undo stack.** It keeps `entries` /
`redoEntries` of `LayoutNode` snapshots, capped at 50, guarded by an
`NSLock`. Apple's `UndoManager` registers named actions with an inverse
and keeps the redo stack.

⇒ **But `TreeHistory` is inside the closed layout-tree group** (§6), = it
is unreachable, = **the migration is moot: the group is a deletion
candidate, and deleting it removes the hand-rolled stack with it.** ⇒ Do
NOT open an `UndoManager` migration for a file that should not exist.

⇒ The `UndoManager` question is live for a **different** reason = the
next section.

**(b) The app replaces the system's Undo/Redo menu with two empty
buttons.** `Sources/WenshuApp/App/AppRootScene.swift:108-113`:

```swift
CommandGroup(replacing: .undoRedo) {
    Button(String(localized: "menu.edit.undo"), action: {})
        .keyboardShortcut("z", modifiers: .command)
    Button(String(localized: "menu.edit.redo"), action: {})
        .keyboardShortcut("Z", modifiers: [.command, .shift])
}
```

⇒ The `action` is **empty**. The Edit menu's Undo and Redo items do
nothing. The keyboard shortcuts are bound to those empty buttons.

⇒ Apple's HIG says (**`undo-and-redo`**, = =
https://developer.apple.com/design/human-interface-guidelines/undo-and-redo),
**quoted complete**:

> "People generally expect to initiate undo and redo in system-supported
> ways, such as choosing the items in a macOS app’s Edit menu, using
> keyboard shortcuts on a Mac or iPad, or shaking their iPhone."

⇒ ⇒ **The macOS half of that sentence IS the finding**: = = "choosing the
items in a macOS app's Edit menu" = = and the app **replaces** those items
with two buttons whose action is empty. ⇒ (**`edit-menus`**), **quoted
complete**:

> "**Prefer the system-provided edit menu.** People are familiar with the
> contents and behavior of the system-provided component, so creating a
> custom menu that presents the same commands is redundant and likely to be
> confusing."

⇒ ⇒ **And the HIG's own macOS platform note says it again** (= =
`undo-and-redo`, = = the "Platform considerations / macOS" section),
**quoted complete**:

> "**Place undo and redo commands in the Edit menu and support the
> standard keyboard shortcuts.** Mac users expect to find undo and redo at
> the top of the Edit menu; they also expect to use Command–Z and
> Shift–Command–Z to perform undo and redo, respectively."

⇒ ⇒ **And each quote is checked against the page's own sentence
boundaries** (= = the script fetches the article and requires the quote to
be present, = = to END on a sentence end, = = and to BEGIN at one), = = so a
truncated quote cannot pass as a complete one. ⇒ MEASURED: = = the
round-one truncation (= = it stopped at "on a Mac") is **rejected** by that
check, = = and the three quotes are **accepted**.

⇒ **The system's own undo/redo menu already exists and already works.**
SwiftUI's `.undoRedo` command group routes to the responder chain's
`undo:` / `redo:`, = to the `NSTextView`'s `UndoManager`, = and the
vendored markdown engine **already supplies a per-document `UndoManager`**
(`Vendor/MarkdownEngine/.../NativeTextViewCoordinator+TextDelegate.swift:33`,
`public func undoManager(for view: NSTextView) -> UndoManager?`).

⇒ ⇒ ⇒ **The replacement is not a custom menu that does the same thing.
It is a custom menu that does NOTHING, in the place where the system's
menu did the real thing.** The `⌘Z` that reaches the editor's undo today
reaches it through AppKit's responder chain, = **not** through these
buttons. ⇒ The buttons are a hole in the Edit menu, and the tree's own
`TreeHistory` (= the tree's intended undo stack) is unreachable.

⇒ **The fix is a DELETION, not a migration**: drop the
`CommandGroup(replacing: .undoRedo)` block and let the system's own Undo
and Redo items come back. ⇒ **This is a behaviour change the boss should
see** (= the Edit menu's Undo/Redo go from *present but inert* to
*present and working*), so it is reported here, not built here.

### The medium one: the regex

⇒ `NSRegularExpression.literal` is a **hand-rolled helper for a
compile-time-literal regex init** (= a `do`/`catch` around
`NSRegularExpression(pattern:)` with a `preconditionFailure`). Swift's own
`Regex` is available.

⇒ **THE HELPER HAS NO PRODUCTION CALLER** (= §4a: = the gate's 53
references are `UUID.literal`'s, = a different type's member with the same
name; = = the gate's own `has_real_ref` says 53, = = not a grep). ⇒ ⇒ ⇒ **The `Regex` migration for this shape is not a migration
at all: it is a 45-line file deletion**, and the 13 sites the helper's own
header says it replaced are **gone** (= that "13" is the FILE's own claim,
= = not a measurement; = = the measured CALL-SITE chain is in §4a). ⇒ The
last two files carrying call sites went with `4c5b7748c9`, = 2026-10-21.

⇒ The other `NSRegularExpression` call sites are **live**: = **21**
construction sites across **10** production files (= `WenshuAgent/Turn/
RuntimeHelpers.swift`, = `MessageSanitization.swift`, = `MessageContent.swift`,
= `InternalLinkParser.swift`, = `BookDocumentTagLine.swift`, =
`ImportSOPLoader.swift`, = `ImportDocumentTemplates.swift`, =
`SubAgentMentionParser.swift`, = `ModelMetadata.swift`, = `WordCounter.swift`),
= = and those are the ones a `Regex` migration would touch. ⇒ **The project's own
configuration already allows it.** The package is
`swift-tools-version: 6.4`, = Swift 6 language mode, = and **MEASURED in
a throwaway package with the same tools-version**: the bare-slash literal
`/\s*,\s*([}\]])/` compiles and runs with **no extra feature flag**.
(A correction to the earlier reading: the flag is needed only in Swift 5
language mode.)

⇒ **But the semantics differ in one place that matters**, and it is
MEASURED, not guessed:

| Call | Semantics | Same pattern + input |
| --- | --- | --- |
| `NSRegularExpression.firstMatch(in:range:)` | **substring** search | 1 match |
| `String.matches(of:)` / `String.firstMatch(of:)` | **whole-string** | 0 matches |
| `Regex.firstMatch(in: string)` | **substring** search | 1 match |

⇒ ⇒ ⇒ **A straight swap changes the behaviour.** The whole-string form
is `String.matches(of:)`'s default; the substring form is
`regex.firstMatch(in:)`. ⇒ Every call site must be checked individually,
= this is a real migration cost, = not a mechanical rename.

### The partial ones

**`CollectionDifference` vs `DiffUtil`.** `DiffUtil.swift` is a hand-rolled
LCS (= `lcsTable` + `backtrackDiff` + `computeUnifiedDiff`, 139 lines, **2**
call sites in `BookChapterActor+ToolProtocol.swift` and
`EditChapterActor.swift`). ⇒ The count is the **call sites**, = = the
definition excluded: = = the tree has ONE `computeUnifiedDiff` and TWO
callers, = = and a count that includes the definition over-reports by
one. ⇒ The script's §B prints it under the same rule. Apple's
`CollectionDifference.difference(from:)` gives the insertions and the
removals. **But it does not give the unified-diff TEXT** (= the
`--- old` / `+++ new` / `@@` format and the context lines), and the diff
is a **user-visible tool output** (= the agent's `edit_chapter` result).
⇒ **Partial, and the adapter layer is the real cost.** ⇒ And note
`DiffUtil.swift` is not an island (= its two callers are live), = this is
a live file either way.

**`NLTokenizer` vs the two tokenizers.**
`CSSearchableIndexSearch.tokenize` (= app) and `MemorySearchTerms.tokenize`
(= data package) are two hand-rolled tokenizers with the SAME rule (= an
ASCII word is one token, a CJK character is one token). `CSSearchableIndexSearch.swift`
already carries the comment "**Apple HIG: `NLTokenizer` would be richer;
= keep Foundation-only to avoid dep.**"

⇒ ⇒ ⇒ **That comment is the tree's own decision, and the skill says a
prior explicit decision is checked, not resolved unilaterally.** ⇒ So:
two things are separable = (a) the **duplication** (two copies of one
rule, = a real finding, = the app and the data package each hold one),
and (b) the **`NLTokenizer` migration** (= a decision the tree already
made). ⇒ The duplication is worth fixing on its own terms (= one shared
tokenizer), and `NLTokenizer` is a separate question the tree already
answered.

⇒ `NLTokenizer`'s CJK behaviour differs from this rule (= Apple's
tokenizer groups CJK differently), = a migration needs a CJK regression
test before it is safe.

**`Mutex` vs `NSLock`.** **21** `NSLock()` sites (= the **production**
roots only; = = a plain grep over `Sources/` also catches the two
`Sources/WenshuAgent/Tests/` files, = = and a test tree is not production).
`Synchronization.Mutex` needs **macOS 15+** and the tree targets **macOS 27**
(= `Package.swift` declares `.macOS(.v27)`), = the availability is fine. ⇒ **But** `Mutex`
is a value type with no recursive-lock support and a different
`lock`/`unlock` shape, = the 21 sites are not a mechanical swap. ⇒
Partial, = and the payoff (= a non-recursive mutex's contention) is
unmeasured here.

## §8 What the tree already does right (= the false positives, named)

The sweep's own false positives are listed so the next reader does not
re-derive them. ⇒ **Every count here is a grep over the production roots
AND `Vendor/`, and the script prints it with its method** (= §B's last
table). ⇒ The count is the **matching lines in code** (= comments and
string contents removed), = = so a docblock that mentions a shape does
not inflate it.

| Shape | The tree's use |
| --- | --- |
| Apple's Liquid Glass | `.glassEffect(` = **3** sites (= `InspectorCard.swift`, = `ChatInputBarView.swift`, = `Mobile/.../GlassSurface.swift`, = the last one behind an `#available` gate with a material fallback) |
| Apple's observation | `@Observable` = **25** code sites (= over the production roots AND `Vendor/`; = = the raw grep is **75** lines over **45** files, = = and the difference is comments) = = and the ONE `ObservableObject`/`@Published` in the tree is a **comment** in `LayoutTreeStore.swift` |
| Apple's own search | `.searchable` = **1** site (= `SettingView.swift`, = and its own comment explains why the other panes have none) |
| Apple's windows | `WindowGroup` = **3** sites, = `openWindow` = **2** |
| Apple's settings | `Settings {` = **7** sites |
| Apple's clipboard | `NSPasteboard` = **19** sites |
| Apple's crypto | `import CryptoKit` = **6** sites |
| Apple's markdown | `AttributedString(markdown:)` = **1** site (= `Mobile/.../ChapterReaderView.swift`; = = the app's own markdown goes through the vendored engine) |
| Apple's date formatting | `.formatted(` = **23** sites; = = of the `DateFormatter` family, **3** are `ISO8601DateFormatter` (machine timestamps) and **1** is a plain `DateFormatter` (= `ChatMessageFooter`; = = that is **1 declaration** over **2 lines** (= the `static let` and the local that builds it), = = and its own comment says why: = the format string is a `DateFormatter` format, = and only the formatter reproduces the output byte for byte) |

⇒ **The tree is not a tree that reinvents the platform.** It adopts the
native answer almost everywhere. ⇒ The Apple findings in §7 are six
specific shapes, not a pattern.

⇒ **And the table is a list of what the tree DOES, = = not a list of what
Apple ships.** ⇒ Two rows in the first draft of this record were **wrong
that way** (= the tree was credited with `MenuBarExtra` and with
`CommandGroup(replacing: .undoRedo)` as "the system's own menu"), = = and
the review caught both: ⇒ **`MenuBarExtra` has 0 code hits in the whole
repo** (= and `docs/adr/0015` says the tree must **never** self-implement
it), = = and the one `CommandGroup(replacing: .undoRedo)` site is the
**replacement**, = = not the system's own menu kept. ⇒ ⇒ **Two rows are
GONE from this table on purpose**, = = because the tree does not do them.

## §9 The two empty test suites

```
Tests/WenshuAppTests/UI/DesignSystem/Round6StandaloneSweepTests.swift
Tests/WenshuAppTests/Core/Agent/Web/KeylessProviders/KeylessProvidersLiveAPITests.swift
```

⇒ Both have **zero `@Test`** and both were **already empty at `HEAD`**,
= = they are pre-existing debt, = = not this sweep's residue.

⇒ **The tool that says so lives OUTSIDE this repository**: = = it is
`empty_test_suites.py` in the **`dead-feature-audit` skill's** `scripts/`
directory (= `~/.hermes/profiles/pocock/skills/dead-feature-audit/
scripts/`), = = **not** a file in this tree (= `git log --all --diff-filter=A
-- '*empty_test_suites*'` finds **no commit** that ever added one). ⇒ The
first draft of this record cited it as if it were the tree's own tool; = =
that attribution was wrong, = = and the review caught it.

⇒ **And the emptying commit is not the one the first draft named.**
`KeylessProvidersLiveAPITests` went from **3 `@Test`** to **0** at
`76ce4b075e` ("add `@MainActor` to tests + fix tests broken by #8
SwiftData migration", = 2026-10-05) (= measured: = `git show
76ce4b075e~1:<file>` has 3, = `git show 76ce4b075e:<file>` has 0). ⇒
`e4ffec568` ("remove the right rail, its agent tools, persistence, and
tests", = 2026-10-21) is a **real** commit (= the tree has it), = = but it
left **both** suites at **0 `@Test`** on either side of it, = = so it did
not empty this one.

## §10 The archived branches (= dead-code work that never landed)

Two branches carry dead-code work that never landed on `main`:

```
archive/old-lane/deadcode-20261025       (= 98042b2995 and its neighbours)
archive/old-lane/notifications-20261025
```

⇒ A merge test into the current tree was attempted and **did not produce
a clean-merge result**, = these branches are **not** known to replay
cleanly onto `58dd224bb7`. ⇒ They are recorded, not recommended.

## §11 What this sweep does NOT say

- **No file was deleted.** The sweep is read-only. The candidates above
  are candidates, = and §7.6's gate (`verify-dead.py`) and the
  one-candidate-per-commit rule still govern any removal.
- **No whole-suite run.** The dead-code sweep does not need the suite,
  and the suite has known pre-existing failures (= 17 at the 2026-10-31
  baseline) and a known hang (= `CSSearchableIndexSearchTests` waits on
  Spotlight). ⇒ A removal's verification is a separate step.
- **No migration was built.** §7 names the APIs; = the migrations carry
  the semantic risks the section names.
- **The 52 bare declarations are not all deletable.** §3's list is the
  tool's reachability verdict; = a project standard or a conformance test
  may require an artifact to exist, = and that must be named before the
  removal.
- **`verify-dead.py` was not changed.** Its default scope is narrow
  (= §2), = but changing the gate's scope is the boss's call, = and it
  would make every existing card's gate width change.

## §12 The recommendations (= proposed, not built)

Per the scope rule (= AGENTS.md §1.16), an expansion that is merely
USEFUL is proposed in the report and the boss decides. ⇒ **Nothing below
was built.**

| # | Proposal | Cost | Why it is a proposal |
| --- | --- | --- | --- |
| 1 | Delete the `CommandGroup(replacing: .undoRedo)` block | 5 lines | = the system's own undo/redo comes back (= a **behaviour change the boss should see**) |
| 2 | Delete the 5 real islands (§5) | 374 lines | = one candidate per commit, each with the build + the named suite green |
| 3 | Delete the 4 closed groups (§6) | 4,008 lines | = the layout-tree group costs a **schema version** (= read `Container.swift` first) |
| 4 | Delete the unread design tokens | 26 lines | = the sweep suite SCANS the file dynamically (= it regexes every `static let <name>:`), = = so it needs **no** edit |
| 5 | Migrate the signature read to Security.framework | ~40 lines | = the only change that removes a **subprocess** (= the one whose wrongness is in kind) |
| 6 | Merge the two tokenizers | ~40 lines | = the duplication is the finding; = `NLTokenizer` is the tree's own settled decision |
| 7 | Run `verify-dead.py` in CI | 1 workflow step | = the gate §7.6 names is not in CI |
| 8 | Widen `verify-dead.py`'s default scope | 1 file | = it would change every card's gate width |
| 9 | **Fix BOTH of the gate's blind spots** | 1 file | = §4a: = the name-only count kept a 45-line dead file alive for 26 days; = = §3: = the same-file skip reports **8 live** declarations as dead |
| 10 | Delete `NSRegularExpression+Literal.swift` | 45 lines | = §4a: = 0 production call sites (= the measured chain, = = not the file's own "13"), = = and the sites it replaced are gone |
| 11 | **Delete the `AVSpeechUtteranceDefaultSpeechRate` shadow** | 3 lines | = §3: = the line shadows Apple's own constant (= **0.5**) with a self-reference (= **0.0**); = = nothing reads it today |
| 12 | **Make `nfi-loc-check` read a row's CONTENT TAG, not just its LOC cell** | 1 file | = §13: = the check was written and MEASURED, = = and it fires on correct rows (= = a version, = = a date, = = the LOC itself); = = it would change **101** cards' verdicts = = so it is the boss's call |

⇒ **The order that costs the least first**: 1 (= 5 lines, = a behaviour
change the boss sees) → 11 (= 3 lines, = a real bug) → 7 (= 1 step) → 4 (=
26 lines) → 10 (= 45 lines) → 9 (= the gate gets honest) → 2 (= 374 lines)
→ 5 (= a subprocess out) → 6 → 3 (= the schema version) → 8 → 12 (= 1 file,
= = and it is the boss's call).

⇒ **Item 9 before item 2**, because a gate that cannot see a dead file
cannot certify that the others are gone either.

⇒ **Item 11 is the only one that is a BUG rather than a cleanup**, and it
is the smallest: = the line binds Apple's constant name to **0.0** where
Apple's value is **0.5**, = = so the next person who writes a
`speechRate:` in that file gets silence. = = Deleting the line restores
Apple's value, = = because the file's own `import AVFoundation` already
brings it in.

## §13 What the sweep costs

One script (`Tools/wenshu-devtool/dead-sweep-measure.py`), its own test
suite (`Tools/wenshu-devtool/tests/test_dead_sweep_measure.py`), one
README section, and this document. The script prints every number above
with its own method, = so the next sweep is a re-run, = not a
re-investigation.

⇒ **The suite found a real defect in the sweep's own lexer**: the
string-interpolation case failed, = because the lexer dropped the
interpolation, = so a declaration used only inside one would have read as
dead. ⇒ The lexer now keeps the interpolation's code (= the compiler
resolves that name, = so a reference inside it is a real reference).
⇒ **The fix changed no number in this document** (= the diff of the
whole run is empty), = so the figures above stand either way.

⇒ The script's own method notes are the falsifiability: each lens prints
what it counts and what it does NOT count (= the generic words, = the
standard-library extension targets, = the comments, = the string
contents), = so a reader who finds a false positive knows exactly which
filter to change.

### The review round (= what it caught, = and what it cost)

⇒ This record went through **one review**, = = and the reviewer returned
**six blocking findings**, = = all of them in the record's prose and in
the script's lenses, = = none in a production source file. ⇒ All six are
fixed here, = = and the fixes are the sections above. ⇒ ⇒ **And the review's
own probes found ELEVEN more** (= = the ones numbered 7-17 below), = = so
**seventeen** findings in all, = = every one of them fixed in this commit. ⇒ ⇒ **And the
review's own note flagged the baseline count as having "no script
source"**: = = the script now prints it, = = and its own file list says
**34**, = = so the delta is **flat** and not "fell by 2":

| # | The finding | The fix |
| --- | --- | --- |
| 1 | §3 claimed "zero false positives"; = = **8 of the 66** are live (= the file itself calls them) | = = §3 now uses the gate's OWN `local_uses`, = = and names the gate's **second** blind spot |
| 2 | §7 said `DiffUtil` has "3 call sites"; = = it has **2** (= = the definition was counted) | = = the script's §B counts call sites, = = and the record says so |
| 3 | §8 credited the tree with `MenuBarExtra`; = = it has **0** code hits (= = and an ADR forbids it) | = = the row is **gone**, = = and §8 says why |
| 4 | §12 said deleting a token needs a suite edit; = = the suite **scans the file dynamically** | = = the cost is 26 lines, = = no suite edit |
| 5 | §9 cited `empty_test_suites.py` as the tree's tool; = = it lives in a **skill**, = = and the emptying commit was `76ce4b075e`, = = not `e4ffec568` | = = §9 names both facts |
| 6 | `nfi.md` added **4** rows with **2** sharing one registry key (= = the first duplicate in the registry's history, = = and the merge driver drops one) | = = the two are merged into **one** row per file |
| 7 | §2's baseline said **36** PARTIAL; = = the script's own file list says **34** (= = the 36 came from a `find` that counted 3 `Package.swift` manifests) | = = §2 now says **34**, = = and the delta is **flat**, = = not "fell by 2" |
| 8 | The registry's row **content tag** carried the round-one numbers (= = "60 bare", = = "the PARTIAL count fell by 2") after the record was corrected | = = all three rows' tags carry the corrected numbers; = = the gate generalization was tried and REJECTED (= = above) |
| 9 | The headline's **line denominators** (= = 29,200 / 118,251 / 24.7%) had **no script source** | = = the script prints them in a new §A1b, = = and the figures match exactly |
| 10 | The `NSLock()` count was a **mixed scope** (= = 23, = = of which two are in `Sources/WenshuAgent/Tests/`) | = = the production count is **21**; = = the script prints the row with its scope |
| 11 | The `@Observable` row **mixed scopes** (= = 76 lines over 46 files = = that count includes the `Tests` tree) | = = the production count is **75** over **45**; = = the script prints the RAW count beside the code count |
| 12 | §3's heading still said "the sixty nothing names" | = = it says fifty-two |
| 13 | §2's headline quoted **34**; = = the **tool's own summary** prints **36** (= = it counts the 2 `EMPTY` files as `PARTIAL`, = = because it has no `EMPTY` row) | = = §2 and the headline now print **both** (= = 34 + 2 = 36), = = and the headline quotes the **36** a reader sees when they run the tool |
| 14 | §4a's chain said "13 → 10 → 0"; = = the measured **call-site** chain is **12 → 9 → 0** (= = the old number counted the helper's own docblock, = = because `git grep -h` drops the path) | = = §4a now carries the measured chain, = = the script prints it, = = and the file's own "13" is marked as the FILE's claim, = = not a measurement |
| 15 | §7's HIG quote was **truncated** (= = it stopped at "on a Mac") = = and presented as complete | = = the three quotes are now Apple's **exact bytes** (= = the curly apostrophe and the en-dashes), = = and the script fetches the article and tests each quote against the page's **sentence boundaries**, = = so a truncated quote is rejected |
| 16 | The quote check was a **containment** test, = = which a truncation can pass (= = a prefix is contained) | = = the check now requires the quote to **end** on a sentence end and to **begin** at one; = = MEASURED: = = the round-one truncation is rejected and the three quotes pass; = = the suite carries the case |
| 17 | The script **re-typed** the quote to test, = = and one en-dash differed from Apple's bytes, = = so it was testing a COPY of the quote | = = the script now **reads** the record's own quote blocks (= = and the page each belongs to), = = so there is nothing to drift; = = all three are SPAN-EQUAL |

⇒ **And the review's own probe found the live bug in §3** (= = the
`AVSpeechUtteranceDefaultSpeechRate` shadow), = = so the review paid for
itself.

⇒ **And the review's registry sweep found a defect this change introduced**:
the `nfi.md` row's **content tag** still carried the round-one numbers
(= = "60 bare", = = "the PARTIAL count fell by 2") after the record itself
had been corrected. ⇒ **A row that says "60 bare" beside a file that now
says 52 is the same defect in a different cell.** ⇒ All three rows' tags
now carry the corrected numbers.

⇒ **And a generalization of that fix was TRIED, MEASURED, and REJECTED.**
⇒ The obvious fix is a gate: = = make `nfi-loc-check` read a row's content
tag and compare each number against the file the row names. ⇒ **It was
written and measured, and it is a false-positive machine**: = = a row's tag
legitimately quotes numbers the file does not contain (= = a version, = = a
date, = = the LOC itself), = = so the check fires on **correct** rows.
⇒ Measured on a fixture: = = a correct row (= = `version 25, = = line count
3` over a file with 3 lines and no other numbers) = = made the gate exit
**1**. ⇒ ⇒ **So the gate was reverted**, = = and the defect is fixed in the
row instead. ⇒ ⇒ **The same rule the record applies to `verify-dead.py`
(= proposal 9) applies here**: = = a gate that would change **every**
card's verdict (= 101 cards name `nfi-loc-check`) = = is the boss's call,
= = not this sweep's. ⇒ ⇒ **The record's own rule is the reason this
generalization is a proposal and not a change** (= = and it is proposal
12).

⇒ **The suite grew from 7 cases to 10** (= = the three new ones cover the
lenses the review exposed: = = a declaration is not a call site, = = the
declaring file can be excluded, = = a string literal survives the
comments-only lens). ⇒ **The fixture caught one real defect while it was
being written**: = = the comments-only lens dropped a string's **opening**
quote, = = so a pattern inside a literal never matched; = = the fix is in
the shipped code, = = and no number in this document moved because of it
(= = the affected rows are the §B string-based ones, = = and they now read
2 / 1 / 2 instead of the earlier 3 / 1 / 0).
