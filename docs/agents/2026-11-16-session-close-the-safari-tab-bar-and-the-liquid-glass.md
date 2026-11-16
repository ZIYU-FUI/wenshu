# The pane tab strip, the Safari tab bar, and the Liquid Glass material

Session closeout. 2026-11-16.

## What the boss asked

> "你能 REA 一下，看一下 safari 是怎么写的 teb嘛。完全复刻 safari 就行"
> "包括材质，safari 用的是液态玻璃。还有分段器也是，apple 原生也是液态玻璃的。"
> "有用的前端样式代码，完全可以照抄，复制过来，没必要理解，翻译，再实现。"

Three parts: (1) read Safari's tab bar, (2) replicate it, (3) the material
is Liquid Glass, and the native segmented control already IS Liquid Glass.

The third part is a METHOD ruling, and it decided this session's work: copy
Apple's own code, do not understand it, translate it and implement it again.

## What Safari actually ships (measured, not paraphrased)

Safari's implementation is in the dyld shared cache, so it cannot be read by
REA:

- `/Applications/Safari.app/Contents/MacOS/Safari` = a 311,584 BYTE shim
  (= MEASURED with `stat -f %z`; = the cryptex's copy is the same
  size; = and the shim holds no slice of that size on its own = =
  x86_64 74,016 / arm64e 98,592 / arm64e.x1 98,592).
- The code lives in
  `/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e`
  (split into `.01` / `.02` / `.03` ...).
- `mcp__rea__open_binary` on the cache = "Unsupported binary format".
- `mcp__rea__open_binary` on
  `/System/Library/PrivateFrameworks/SafariSharedUI.framework/Versions/A/SafariSharedUI`
  = "Binary not found" (the framework ships Resources only; the Mach-O is in
  the cache).
- `dyld_info -objc <cache>` = "file not found" (the ObjC metadata lives in the
  sub-caches).

What IS readable is the cache's export table
(`dyld_info -exports -all_dyld_cache` = 4,590,963 lines), and it names
Safari's tab bar classes:

| Symbol in the export table | What it is |
| --- | --- |
| `SFUnifiedTabBarItemViewAccessibility` | the item's AX wrapper |
| `SFUnifiedTabBarItemTitleContainerViewAccessibility` | the title container's AX wrapper |
| `SFUnifiedTabBarSectionBackgroundViewAccessibility` | the section background's AX wrapper |

⇒ ⇒ ⇒ AND THAT IS THE WHOLE OF IT: = the table holds exactly 12 lines
that contain `SFUnifiedTabBar`, = and every one of them is one of those
three AX wrappers (= its class, = its metaclass, = and their `_super`
pairs). = ⇒ The PLAIN names (= `SFUnifiedTabBarItemView`, =
`SFUnifiedTabBarItemTitleContainerView`, = `SFUnifiedTabBarSectionBackgroundView`)
have ZERO whole-token hits in the table, = and that is the
SUBSTRING trap: = each plain name is a PREFIX of an AX wrapper's name, =
so a grep that does not anchor the token end reports them. = ⇒ So the
plain names are NOT evidence from the export table; = they are names
this session inferred from those prefixes, = and they are NOT claimed
here as measured. = ⇒ ⇒ ⇒ What IS measured is that Safari's tab bar
exposes AX wrappers for an ITEM, = a TITLE CONTAINER, = and a SECTION
BACKGROUND, = = which is the shape of a unified tab bar (= an item, = a
title inside it, = and a background behind the bar), = and that Safari
has its own tab bar class stack rather than an `NSSegmentedControl`.

The same table also carries `TeaUI24FloatingTabBarControllerC17` (= the
floating tab bar's controller, = in the TeaUI framework).

So Safari 26+ draws its tab bar with its OWN `SFUnifiedTabBar` view stack
(= a title container per item, = and a section background behind the bar),
not with `NSSegmentedControl`.  That code is private, so it cannot be
copied into this app; what CAN be copied is Apple's PUBLIC equivalent, and
that is what the strip uses.

## What Apple says the material is (HIG, the `materials` page)

> "Liquid Glass forms a distinct functional layer for controls and navigation
> elements — like tab bars and sidebars — that floats above the content layer"

> "Don't use Liquid Glass in the content layer."

> "Use Liquid Glass effects sparingly. **Standard components from system
> frameworks pick up the appearance and behavior of this material
> automatically.** If you apply Liquid Glass effects to a custom control, do
> so sparingly."

That last sentence is the answer to the boss's question, and it is Apple's
own: the native segmented control IS Liquid Glass, because a standard
component picks the material up by itself.

## MEASURED: the native control carries the material by itself

MEASURED: = the control over a saturated green host layer
(`NSColor(calibratedRed: 0, green: 0.55, blue: 0.25)`, = a `.small`
control, = the `.valueSelection` role, = the segment selected), = read
from a 2x `NSBitmapImageRep` in the window's own appearance. = EVERY
number below names its appearance, = its region, = and the container it
was read from; = the first row of each pair is the CONTROL'S OWN AREA
(= the cell's surface and its glyph), = and the second is the HOST
BACKDROP BESIDE IT (= the same layer, = untouched, = and therefore the
colour the backdrop actually renders as):

| Appearance | Container | The control's own area | The backdrop beside it |
| --- | --- | --- | --- |
| darkAqua | the control ALONE | `(18,150,88)`, 29 colours | `(0,143,76)`, 1 colour |
| darkAqua | an `NSVisualEffectView` behind it | `(94,116,106)`, 108 colours | `(0,143,76)`, 1 colour |
| darkAqua | an `NSGlassEffectView` around it | `(92,107,100)`, 113 colours | `(0,143,76)`, 1 colour |
| aqua | the control ALONE | `(0,133,70)`, 26 colours | `(0,143,76)`, 1 colour |
| aqua | an `NSVisualEffectView` behind it | `(139,161,151)`, 118 colours | `(0,143,76)`, 1 colour |
| aqua | an `NSGlassEffectView` around it | `(154,169,162)`, 128 colours | `(0,143,76)`, 1 colour |

⇒ ⇒ ⇒ AND THE RENDERED BACKDROP IS `(0,143,76)`, = NOT the nominal
`(0,140,64)`: = the nominal colour is what the app asks for, = and the
rendered one is what the layer's colour space produces. = (The first
version of this document quoted the nominal value as if it were a
measured pixel, = and the review caught it.)

⇒ ⇒ ⇒ WHAT THE TABLE SAYS: = the control alone still shows the
GREEN through its cells (= the cell's own area reads green-dominant, =
`(18,150,88)` in darkAqua and `(0,133,70)` in aqua, = and the backdrop
beside it reads the same green) = ⇒ the control does not paint an
OPAQUE fill of its own. = And the two material containers REPLACE that
green with a NEUTRAL tint (= `(94,116,106)` and `(92,107,100)` in
darkAqua) = = which is what a material does: = it samples and tints what
is behind it.

⇒ ⇒ ⇒ ⇒ SO THE APP ASKS FOR NOTHING, = AND THE APP ADDS NOTHING:
= the native control's own appearance is Apple's, = Apple's own line
says a standard component picks the material up automatically, = and
adding a glass container would put a SECOND material between the control
and the backdrop (= HIG's "do so sparingly" = against it) = and = with
no backdrop to sample (= an offscreen window, = and = the review's own
measurement) = that glass renders near black.

⇒ ⇒ ⇒ AND THE CORRECTION: the tree's rationale said "the Liquid Glass
material is applied to the window chrome, not to the segmented control
itself".  That is wrong, and the comment now cites Apple's line and the
measurement above.

## MEASURED: `.tabs` role vs `.valueSelection` role

`NSSegmentedControl.role` is a macOS 27 API (`NSSegmentedControlRole`).
Rendering all three roles with all four styles over a saturated background:

| Role | The selected segment | Its label |
| --- | --- | --- |
| `.tabs` | a DARK inset | NOT DRAWN AT ALL |
| `.valueSelection` | a raised lighter capsule | drawn |
| `.automatic` | a raised lighter capsule | drawn |

⇒ The tree's `.valueSelection` is right, and the comment saying `.tabs`
would put the active document's name behind a blank dark capsule is
CONFIRMED by the render, not by opinion.

## The narrow end: what the app must still decide (and what it must not)

AppKit truncates on its own.  Handing the WHOLE title to the control, the
cell draws Apple's own truncation:

| Share | AppKit draws | Ink |
| --- | --- | --- |
| 14 – 25 PT | the lone `…` | 29 |
| 26 – 38 PT | `十…` | 119 |
| 39 – 45 PT | `十二…` | 200 |
| 60 PT | the whole title | 613 |

Two consequences:

1. **The lone ellipsis is the one case the app must own.**  The boss ruled it
   out (= "连...都不显示"), so in the band where the cell holds the first
   character but not the character BESIDE the ellipsis, the app supplies the
   title's FIRST character.  That is the 2026-11-16 rule.

2. **The hand-rolled title ladder stays.**  The boss's "copy it, do not
   re-implement it" ruling was TRIED on the title, and the measurement
   refused it:

   | Host | Whole title handed over | Track |
   | --- | --- | --- |
   | a bare `NSSegmentedControl` | AppKit truncates | `over = +0.0` at every share 10 – 60 PT |
   | the REAL strip (= the hosted editor strip) | the cell grows to `label + 20.5` | 3 tabs in a 200 PT column drew a **239 PT** track |

   ⇒ On the real strip AppKit does not truncate, = it widens the cell
   (= `PaneTabStripWidth.segmentLabelInset` = 20.5 PT = that growth), so the
   ladder (`PaneTabStripTitle.fitted`) is LOAD-BEARING.  ⇒ The "copy it"
   ruling applies to the MATERIAL, where Apple's own component already does
   the work, and NOT to the layout, where the app must pre-truncate.  The
   tree's own lesson (= "the bare control is not the truth") is what caught
   this.

⇒ ⇒ ⇒ SO THE CHANGE IS SMALL: the ladder keeps its shape, = and the one
case the boss named (the narrowest tab) now answers with the title's FIRST
character instead of the nothing marker.

## The gates

| Gate | Result |
| --- | --- |
| `swift build --build-tests` | PASS |
| the three title/strip suites | 29 tests, 3 suites, PASS |
| `verify-dead.py` | DEAD 0 |
| the mutation check (= the first-character rule removed) | 6 issues in 3 tests, = so the new assertions FAIL without the rule |

The three new assertions, one per layer:

1. `PaneTabStripTitleTests`: the rule itself (= the narrowest cell holds
   `十`, = not the marker, = and the character fits the cell).
2. `PaneTabStripTitleWriteTests`: the PRODUCTION write path (= the cell
   holds `十` AND paints it).
3. `EditorTabStripOverflowTests`: the REAL strip (= the narrowest band
   holds `十` alone, = and the drawn track stays inside the column at
   every tab count and column width).

## What was NOT built, and why

- **A `NSGlassEffectView` around the strip.**  MEASURED: the native control
  is already the material, and the glass wrapper is a SECOND material
  (HIG: "do so sparingly").  Copying Apple's own component is the copy.
- **Safari's `SFUnifiedTabBar` view stack.**  It is private code in the
  shared cache (= not readable, = not copyable), and Apple's public
  equivalent for a native tab strip is the segmented control the strip
  already uses.
- **A new title ladder.**  Measured to be worse on the real strip (= the
  239 PT track), so the ladder stays.

## One open item for the boss

The strip's narrow end now shows the title's first character, and it does so
from the share that holds it (= 33.5 PT for a 13 PT CJK glyph).  Below that
share the cell has no room for even one character beside the segment's own
inset, and the strip shows nothing (= the pre-existing marker).  If the boss
wants a character visible BELOW that share, the cost is a segment that
widens past its share (= the band the fix closed), and that is a decision
about the overflow rule, not about the title.
