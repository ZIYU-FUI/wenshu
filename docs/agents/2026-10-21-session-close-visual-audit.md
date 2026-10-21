# Session close — 2026-10-21 — the visual audit: four UI defects found, measured, and fixed

> Boss directive 2026-10-21 (rendered in English per rule 1.1): "go and look for a skill
> that raises the aesthetic bar, so you can analyze the Wenshu project through screenshots,
> find what can be improved, and then improve the user's visual experience under Apple's
> API requirements". Earlier in the same session: "I need the app launched so I can try it
> and then decide", "I found a problem: the builds kill each other; how do we avoid that in
> the process?", and "only mind your own business".
> Session: `20261021_133701_8aed68` (this one, desktop).
> Closure type: 3 code tickets (3 commits, all merged into `main`) + this closure doc.

## 1. What this session did

A screenshot-driven visual audit of the running app, with every finding measured in pixels
before it was filed and every fix proven by a test that measures the rendering rather than
the source text.

| # | Ticket | Commit | Repo impact |
|---|--------|--------|-------------|
| 1 | The selected document tab must show its title | `5824726c7` | 3 files, 194 insertions |
| 2 | The user's own message must be readable on a surface of its own | `0503303a5` | 3 files, 236 insertions |
| 3 | The status bar must not slice the last line; the counter must say what it counts | `a0720c5e3` | 6 files, 339 insertions |

All three are on `main`. The fourth finding (the sidebar) was **withdrawn**: its premise
was wrong, and the ticket was closed without shipping a change.

## 2. What changed

**The selected document tab showed no title at all.** The tab strip is a native
`NSSegmentedControl` built by `LabelSegmentedControl`, and it was configured with
`role = .tabs`. Measured with an AppKit probe that replicates the control's exact
configuration (3 segments, `.roundRect`, `.selectOne`, `.fillEqually`, `.large`,
`selectedSegment = 1`):

| role | the selected segment's max luminance | pixels above 140 |
| ---- | -------------------------------------- | ---------------- |
| `.tabs` | 46 | **0** |
| `.valueSelection` | 227 | 1049 |
| `.automatic` | 227 | 1049 |

The `.tabs` role draws the selected segment as a dark inset and leaves its label unpainted.
That role exists for ICON segments; a text-labelled strip must use `.valueSelection`. The
control now takes a `role` parameter that defaults to `.valueSelection`, and the strip
passes it explicitly. The selection binding also stopped minting a fresh `UUID()` on every
read (`selectedTabId ?? UUID()`), which could never match a label and changed on every read,
so the control's selected segment never settled; it now uses a stable sentinel.

**The user's own message was dark text on a dark field.** The outgoing card's Liquid Glass
fill collapsed into the chat panel's own colour in the dark appearance, so the user's words
were the least readable text in the window. The card now wears Apple's semantic
`unemphasizedSelectedTextBackgroundColor` with a hairline separator. Measured on the
rendered app: bubble fill RGB(61,61,61) against a chat panel of RGB(33,33,33), and the
bubble's own text RGB(221,221,221) against the bubble = **8.00:1**, well over the WCAG AA
4.5 minimum. The first turn's vertical band was evened out so the spacing between turns is
uniform.

**The status bar sliced the document's last line, and the counter named the wrong
quantity.** SwiftUI's `.safeAreaInset(edge: .bottom)` does not shrink the inner scroll
view: the inset adds the chrome's height to the receiver's bottom safe area while the
scroll view's own frame still reaches the column's bottom edge, which is under the footer.
The editor's scroll view is the engine's own `NSScrollView`, so `.contentMargins` does not
apply to it either; a bottom padding on the engine view does shrink its frame. The reserved
space is the footer's own measured height, now a token
(`DesignTokens.chromeBottomFooterHeight`). Separately, the chat footer compared a token
count against a context-window limit while the number was the SUM of every turn's
`usage.totalTokens`: each turn already reports the whole conversation it was sent with, so
the sum counted the history once per turn. The number is now the LATEST turn's count, and
the label says what it is (= it names the context usage, not a spend total).

## 3. How the findings were verified

Every finding carries a measurement, not a reading.

- **The tab title**: the selected segment's region was measured in the capture. Before the
  fix it held **zero** pixels above luminance 140; after it, **699** glyph pixels at a max
  luminance of 255. The capture shows the active document's own title inside the selected
  capsule, with the other open documents named beside it (= the tab labels are the user's
  document titles, not UI chrome).
- **The chat bubble**: the bubble's fill and the panel's fill were sampled from the PNG and
  converted to a contrast ratio.
- **The last line**: a rendering test measures the scroll view's FRAME, because a
  background colour proves nothing (= the chrome is drawn over it).
- **The counter**: a test asserts that the counter does not grow when a turn is added.

A full-suite baseline was captured at the commit the work started from and compared as a
SET of failing names (not a count): the branch's failing set was **identical** to the
baseline's, so the three commits added no failures.

## 4. The launch crash was NOT a code defect

Thirty SIGABRTs landed in `~/Library/Logs/DiagnosticReports/` that day, every one of them
AppKit's update-constraints guard:

> The window has been marked as needing another Update Constraints in Window pass, but it
> has already had more Update Constraints in Window passes than there are views in the
> window.

It was the measurement, not the code. `open -n` forces a SECOND process of the same bundle
id; Wenshu's SwiftUI `WindowGroup` then has two instances restoring the same saved window
geometry, the guard fires, and BOTH processes abort about five seconds in. Measured:

| launch | result |
| ------ | ------ |
| `open -n <bundle>` | dead in ~5 s, every time |
| `open <bundle>` | alive indefinitely |

A harness built on `open -n` reports a crash for every build, including the unmodified one
and the pre-change commit, which is what made it look like a regression. `Scripts/build-app.sh`
now carries the warning, and the rule is in the `wenshu-visual-audit` skill.

## 5. Two things were investigated and NOT shipped

**The sidebar's selected row.** The finding said the selection was hard to identify. The
thin white rule in the screenshot is a `Divider()` (= `SidebarNode.Kind.divider`, the
section separator), not a selection marker, and the system's own selection tint was already
working (a selected row measured 68 against an unselected 39). Apple's own source list
does not dim its unselected rows either. The ticket was closed with no production change.

**The 4 PT clipped line under the user's card.** Found late, measured, and left open on
purpose. The transcript is a `LazyVStack` whose sections carry the user's card as a PINNED
header, and the card's surface is painted at the frame's bounds. Measured on the running
app, the assistant line that follows the first user card showed only its bottom 4 PT
(a 4-pixel-tall band of 674 bright pixels where a full CJK line is ~25 PT), and the row was
whole (25 PT) when the card carried a 6 PT vertical padding.

It is left open because it collides with a contract another card committed to `main` in the
meantime: `ChatSurfaceGeometryTests` requires the outgoing band to rest at the composer
field's 36 PT, and the 36 PT floor cannot hold the card's own content AND a vertical
padding. A variant matrix (one card chain per row, rendered through `ImageRenderer`) found
that the reply is visible only when the card has BOTH a vertical padding and a paint.

Both orders of the padding were then tried against the PRODUCTION card, and both fail one
of the two contracts:

| production chain | the card's height | the crop test | the 36 PT contract |
| ----------------- | ----------------- | ------------- | ------------------ |
| `padding -> frame(minHeight: 36) -> paint` | 44 PT | passes | FAILS (= 44, not 36) |
| `frame(minHeight: 36) -> padding -> paint` | 48 PT | passes | FAILS (= 48, not 36) |
| no vertical padding | 36 PT | FAILS | passes |

(Every height is the hosting view's `fittingSize`, measured in its own cold worktree =
one variant per worktree, so no run inherited another's binary. An earlier version of
this table said 42 PT: that number came from the PAINTED bubble in a capture, which is a
different quantity. The 36 PT row was confirmed a second time in a separate worktree, and
the 44 PT row matches a run taken on the working tree at the time, so two of the three
numbers have two independent sources.)

One warning for whoever measures this next: a script that edits the production file and
runs one probe per variant in a SINGLE shared `.build` reports each variant's PREVIOUS
build. Measured 2026-10-21, that run reported 44 / 48 / 48 PT for the three chains above
(= the correct table shifted by one). Rebuild before measuring, or give each variant its
own worktree.)

So the two contracts are mutually exclusive on the production card (= its content is
taller than the 36 PT floor leaves room for), and the order of the padding is NOT the
lever. The next session to touch the card should start from that matrix; the probe and the
numbers are in the `wenshu-visual-audit` skill (Pitfalls 65 to 69).

**Handed over, not abandoned.** The boss reported that another session has already
verified the bubble against screenshots, so this session stopped there rather than
changing the card. The measurements above and the variant matrix are the handover: they
say exactly which modifier is missing and what the trade-off is, so the next session does
not have to rediscover it.

## 6. What the next session should know

- The three fixes are on `main` and need no further work. The builds are per-tree: each
  worktree has its own `.build` and its own `build/Wenshu.app`, and each tree kills only
  its own instance by absolute path.
- Never `open -n` the app, and never `pkill -f` a loose pattern (`build/Wenshu.app` matches
  every tree's bundle).
- `Localizable.strings` is compiled to UTF-16 LE while its declaration says UTF-8.
  Foundation tolerates it; a strict XML parser rejects the file. It is a separate defect.
- The screenshot hook captures `NSApp.keyWindow`, so a card that makes a secondary window
  open at launch (= the board window) changes what a capture shows. Read the capture's
  pixel size before believing it.

## 7. Skill updates

`wenshu-visual-audit` gained the findings that were expensive to learn: the `open -n`
launch trap (Pitfall 71), the `NSSegmentedControl` role table (30), the source-text
assertion trap (59 and 60), the two-contradicting-contracts trap (65), the pinned-header
overlap and its variant matrix (66, 68), and the key-window capture trap (67).
