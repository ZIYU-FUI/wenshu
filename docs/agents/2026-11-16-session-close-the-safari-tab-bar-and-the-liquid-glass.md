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

MEASURED: = the control ALONE over a saturated green host layer
(= `NSColor(calibratedRed: 0, green: 0.55, blue: 0.25)`, = a `.small`
control, = the `.valueSelection` role, = the `.roundRect` style, = the
second segment selected), = read from a 2x `NSBitmapImageRep` in the
window's own appearance.

⇒ ⇒ ⇒ AND THE MEASUREMENT IS A PROBE IN THE REPO, = not a number
whose source is lost: = `Tools/wenshu-devtool/probes/segmented_control_material.swift`
( = = registered in `Tools/wenshu-devtool/probe-index.md`). = ⇒ Run it:

```
swift Tools/wenshu-devtool/probes/segmented_control_material.swift
```

⇒ ⇒ ⇒ IT PRINTS ITS OWN PARAMETERS WITH ITS NUMBERS, = because they
decide the numbers: = the host size (260 x 40 PT), = the control's frame
((10, 6, 240, 28) PT), = the control's size, = role and style, = the
selected segment, = the measured segment, = the host layer's colour, = and
the drawn band and the measured area it read.

| Appearance | The cell's own area | The backdrop beside it | The SAME area under an opaque fill |
| --- | --- | --- | --- |
| darkAqua | `(96,184,142)`, 141 colours | `(0,143,76)`, 1 colour | `(135,135,135)`, 1 colour |
| aqua | `(0,95,50)`, 116 colours | `(0,143,76)`, 1 colour | `(135,135,135)`, 1 colour |

⇒ ⇒ ⇒ ⇒ THE RENDERED BACKDROP IS `(0,143,76)`, = NOT the nominal
`(0,140,64)`: = the nominal colour is what the app asks for, = and the
rendered one is what the layer's colour space produces. = (The first
version of this document quoted the nominal value as if it were a
measured pixel, = and the review caught it.)

⇒ ⇒ ⇒ ⇒ ⇒ AND THE CELL IS NOT OPAQUE: = the cell's own area reads
GREEN-DOMINANT in both appearances (= `(96,184,142)` in darkAqua, =
`(0,95,50)` in aqua) = = = while the backdrop beside it reads the same
green, = = = so the host layer's colour comes THROUGH the cell. = ⇒
⇒ ⇒ ⇒ ⇒ ⇒ AND THE NUMBER CAN TELL: = the probe reads every region
twice, = once as the control draws it and once with an opaque fill over
the same pixels, = and the SAME area under that opaque fill reads
NEUTRAL GREY (`(135,135,135)`, = 1 colour) = = = not green. = ⇒ ⇒ So
the reading distinguishes a translucent cell from an opaque one: = the
cell paints no opaque fill of its own.

⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND ONE TRAP THIS DOCUMENT'S OWN FIRST PROBE FELL
INTO: = the bitmap that `cacheDisplay(in:to:)` writes is TOP-DOWN, = =
while an NSView's coordinates are BOTTOM-UP. = = = The first probe walked
the bitmap's rows with the view's y unchanged, = = = so its region
landed partly on the cell and partly on the bare host above it, = = = and
its mean could not tell a translucent cell from an opaque one (= the
review proved it: = the same region still read green-dominant over an
opaque grey fill). = ⇒ ⇒ ⇒ The probe now MAPS the view's rect onto the
bitmap's rows, = PRINTS the drawn band and the measured area (= (10, 30)
PT and (38, 14, 24, 12) PT), = = = and places the measured area INSIDE
the band. = ⇒ ⇒ ⇒ So the number is auditable: = a reader can check the
region without trusting the mapping.

⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ SO THE APP ASKS FOR NOTHING, = AND THE APP ADDS
NOTHING: = the control's own appearance is Apple's, = Apple's own line
says a standard component picks the material up automatically, = and so
the app adds no glass layer and no hand-drawn material: = a material
container between the control and the backdrop would put a SECOND
material there (= HIG's "do so sparingly").

⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND WHAT THIS DOCUMENT DOES NOT CLAIM: = an earlier
version of it carried four container readings (= `NSVisualEffectView`
behind the control, = `NSGlassEffectView` around it, = one per
appearance). = The review swept them (= eight `NSVisualEffectView`
materials x two blending modes, = the glass view as a content view and
as a subview, = both appearances, = one and three segments, = two
widths, = two labels, = two rendering paths) and NONE of the four
numbers reproduced, = the container readings swing by a factor of
three, = and in the dark appearance the QUALITATIVE reading flips too
(= a window-server capture renders a flat dark green, = = = not a
desaturated grey-green). = ⇒ So those four triples are gone, = and so
is the claim that a material container "replaces the green with a
neutral tint": = that is a property of the container's parameters, =
not of the control. = ⇒ What the table above supports is the claim the
source comment makes, = and the comment now says only that.

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

## The trace: every requirement, = the commit that carries it, = the verdict that cleared it, = and the proof

| The requirement | The commit that carries it | The independent verdict | The proof |
| --- | --- | --- | --- |
| "REA it and see how Safari writes its tab, = and copy Safari exactly" | `e79a35bc6c` | `t_e13a5b93` (= `changes_requested` on the document, = "the CODE is sound") = and `t_12cf0941` (= `changes_requested` again, = = = "the CODE is untouched and sound") | The export table's 12 `SFUnifiedTabBar` lines, = = = all AX wrappers, = = = in a 4,590,963-line table; = Safari ships its OWN unified tab bar class stack, = = = not an `NSSegmentedControl`; = ⇒ the private implementation is NOT copyable (= the dyld shared cache is not a file REA can open), = = = and the doc says so |
| "Include the material: = Safari uses Liquid Glass, = and the segmented control is Apple's own, = = = so it is Liquid Glass too" | `e79a35bc6c` (= the code), = `bbe2c3e230` (= the re-measured claim) | `t_12cf0941` (= numbers 1 and 2 VERIFY EXACTLY) | Apple's HIG `materials`: "Standard components from system frameworks pick up the appearance and behavior of this material automatically"; = and the probe's own output (`(96,184,142)`/141 darkAqua, = `(0,95,50)`/116 aqua, = backdrop `(0,143,76)`/1, = and the same area under an opaque fill `(135,135,135)`/1), = = = re-derivable with `swift Tools/wenshu-devtool/probes/segmented_control_material.swift` |
| "Use the HIG skill and look it up" | `e79a35bc6c` | `t_e13a5b93` (= the HIG sentence, = = = with its U+2019 apostrophe, = = = and the SDK's APIs, = = = checked out) | The HIG `materials` page (= the material, = = = the functional layer, = = = "don't use it in the content layer", = = = "use it sparingly"), = the `segmented-controls` page, = the `tab-views` page |
| "Useful front-end style code can be copied outright, = = = no need to understand, = = = translate, = = = then re-implement it" | `e79a35bc6c` | `t_e13a5b93` (= "the CODE is sound") | The material IS Apple's own component, = = = so there is nothing to translate: = = = the app adds no glass layer; = and the one place copying was TRIED = = = (letting AppKit truncate the title) = = = was MEASURED to overflow the real strip (= a 200 PT column painting a 239 PT track), = = = so the truncation ladder stays |
| "At the narrowest, = show the first character of the title" | `e79a35bc6c` | `t_e13a5b93` (= the mutation check: = = = 6 issues in 3 tests) = and `t_12cf0941` (= the gates re-run green) | Three layers of test (= the rule, = = = the production write path, = = = the real strip), = = = 29 tests in 3 suites green, = = = and the band that decides it (= the share minus `segmentLabelInset` = 20.5) |
| The band overflow and the blank title (= the work this session started from) | `deff19bac4` = and `6b73f25b51` | already APPROVED, = = = landed at `58dd224bb7` | The gates in that round's closeout |

## One open item for the boss

The strip's narrow end now shows the title's first character, and it does so
from the share that holds it (= 33.5 PT for a 13 PT CJK glyph).  Below that
share the cell has no room for even one character beside the segment's own
inset, and the strip shows nothing (= the pre-existing marker).  If the boss
wants a character visible BELOW that share, the cost is a segment that
widens past its share (= the band the fix closed), and that is a decision
about the overflow rule, not about the title.
