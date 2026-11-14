# The App Store's editorial card: the measured shape, and what Wenshu's card borrows

Research scope. Read-only: no product code changed, and the diff is this
document plus its one registry row.

The scope asked two questions and answered both by measurement:

1. Is the liquid-glass effect an iOS-only control?
2. Is the App Store's content-recommendation card (the full-image card) an
   iOS-only control, and how far is Wenshu's material-column card from it?

Both answers are the same shape: the answer is NO, and the reason is the
same. What Apple ships as a *design language* is cross-platform, and what
the App Store ships as a *card* is not a public control on any platform.

---

## 1. Liquid glass is not iOS-only

### 1.1 The availability annotations, read off every installed SDK

The oracle is the SDK on disk (`/Applications/Xcode.app/.../SDKs`), not
memory. Five platform SDKs are installed on this machine, and each one
carries its own `.swiftinterface` for `SwiftUICore`:

| SDK | interface file |
| --- | --- |
| iPhoneOS 27.2 | `arm64e-apple-ios.swiftinterface` |
| MacOSX 27.2 | `arm64e-apple-macos.swiftinterface`, `x86_64-apple-macos.swiftinterface`, `arm64e-apple-ios-macabi.swiftinterface`, `x86_64-apple-ios-macabi.swiftinterface` |
| AppleTVOS 27.2 | `arm64-apple-tvos.swiftinterface`, `arm64e-apple-tvos.swiftinterface` |
| WatchOS 27.2 | `arm64_32-apple-watchos.swiftinterface`, `arm64e-apple-watchos.swiftinterface`, `armv7k-apple-watchos.swiftinterface` |
| XROS 27.2 | `arm64e-apple-xros.swiftinterface` |

Every one of those files carries the SAME availability line for the same
declaration. Read verbatim out of the files:

```
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@available(visionOS, unavailable)
nonisolated public func glassEffect(_ glass: SwiftUICore::Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some SwiftUICore::View
```

The same pair of lines appears, in all five SDKs, on every one of these
declarations:

Every line below is in ONE file:
`iPhoneOS27.2.sdk/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface`.

| Declaration | Declaration line | `@available` line |
| --- | --- | --- |
| `View.glassEffect(_:in:)` | 3085 | 3083 |
| `Glass` (the value: `.regular` / `.clear` / `.identity` / `.tint` / `.interactive`) | 7420 | 7418 |
| `DefaultGlassEffectShape` | 3090 | 3088 |
| `GlassEffectContainer` | 11706 | 11704 |
| `glassEffectUnion(id:namespace:)` | 12827 | 12825 |
| `glassEffectTransition(_:)` | 3544 | 3542 |
| `glassEffectID(_:in:)` | 22703 | 22701 |

So the SwiftUI surface is one API with four platform availabilities and
one exclusion (visionOS). There is no "iOS has more of it" case: the
signature and the annotation are byte-identical on macOS, iOS, tvOS and
watchOS.

The button styles live in `SwiftUI` (not `SwiftUICore`) and carry the
same pair of lines. Both citations are the STRUCT declarations in
`MacOSX27.2.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface`:
`GlassButtonStyle` at `:1766` and `GlassProminentButtonStyle` at `:4713`,
each preceded by `@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)`
and `@available(visionOS, unavailable)`. Line `:4706` in that file is the
`.glassProminent` static member, not the struct.

### 1.2 The AppKit and UIKit paths are per-platform, and they differ

The low-level paths are NOT shared, and this is where a platform difference
really lives:

| Path | Header | Availability |
| --- | --- | --- |
| AppKit `NSGlassEffectView` / `NSGlassEffectContainerView` | `AppKit.framework/Headers/NSGlassEffectView.h` | `API_AVAILABLE(macos(26.0))` |
| UIKit `UIGlassEffect` / `UIGlassContainerEffect` | `UIKit.framework/Headers/UIGlassEffect.h` | `API_AVAILABLE(ios(26.0)) API_UNAVAILABLE(visionos, watchos)` |

Two measured asymmetries inside those headers, both worth naming because
a reader would otherwise assume symmetry:

- `NSGlassEffectView.effectIsInteractive` is `API_AVAILABLE(macos(27.0))`.
  The iOS `UIGlassEffect.interactive` has been there since iOS 26. So on
  macOS 26 the AppKit glass cannot respond to interaction; on macOS 27 it
  can.
- `UIGlassEffect` is unavailable on watchOS, and `UIGlassContainerEffect`
  carries a `spacing` property that merges nearby glass elements. The
  AppKit `NSGlassEffectContainerView` carries the same `spacing` property
  with the same meaning ("the proximity at which the glass effect
  container view begins merging eligible descendant glass effect views").

### 1.3 What the fluid feel actually is

The "flowing" quality is drawn by the system compositor, not by an API a
client can call. The three public handles are:

- `GlassEffectContainer` groups neighbouring glass so the system can
  merge and morph them.
- `glassEffectUnion(id:namespace:)` marks a view as part of one merging
  group.
- `glassEffectTransition(_:)` drives the morph between states.

Apple's own docs on `GlassEffectContainer` state that a spacing value
larger than the spacing of an interior layout causes the glass to blend
together AT REST, because the views are too close to each other. So the
container's spacing must be EQUAL to (or smaller than) the layout spacing
inside it.

### 1.4 Apple's own words

Apple's newsroom post for the new design (2025-06-09) says the design
"extends across platforms - iOS 26, iPadOS 26, macOS Tahoe 26, watchOS
26, and tvOS 26". Apple's Technology Overviews page says the same: the
picks up "the latest look and feel on the latest platform releases for
iOS, iPadOS, macOS, tvOS, and watchOS". Apple's HIG Materials page
(2025-09-09) says Liquid Glass "is a dynamic material that unifies the
design language across Apple platforms".

### 1.5 The conclusion

Liquid glass is a CROSS-PLATFORM design language, and the SwiftUI API for
it is one API with four platform availabilities. The iOS-only reading is
wrong twice over: the API is not iOS-only, and the platform differences
that do exist are in the *native* paths (AppKit vs UIKit) and in the
*intensity* of the automatic adoption, not in the SwiftUI surface.

---

## 2. The App Store's editorial card is not an iOS-only control either

### 2.1 It is not a control at all: it is private App Store code

There is no public symbol for this card. The sweep:

| Sweep | Result |
| --- | --- |
| `grep -rl "Editorial"` across the whole macOS SDK's frameworks | hits in MediaPlayer, ImageIO, MusicKit only (= unrelated metadata keys) |
| `grep -rl "AppStoreCard\|StoreCard\|CardStyle"` across `System/Library/Frameworks/` (= public frameworks only) | one hit, in CoreTelephony (= unrelated) |
| the same grep across ALL of `System/Library/` | 11 files: 10 under `PrivateFrameworks/` (= CoreParsec, SiriAppIntents, PegasusAPI, GameStoreKit, NewsCore, ContactsUICore, MapsUI, SearchFoundation, IMSharedUtilities, BlastDoor) plus CoreTelephony — none of them a public card type |
| `grep -rn "AppStore\|StoreKit"` in `AppKit.framework/Headers/` | zero hits |
| `grep -n "struct ProductView\|ProductViewStyle\|struct SubscriptionStoreView"` in `SwiftUI`'s macOS interface | zero hits — but this is the WRONG FILE, because StoreKit's SwiftUI views never lived in `SwiftUI`. Their real home is `_StoreKit_SwiftUI.framework/Modules/_StoreKit_SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface`: `SubscriptionStoreView` at `:453`, `ProductView` at `:1252`, `StoreView` at `:1337`, `ProductViewStyleConfiguration` at `:1623` — all public, and that interface holds ZERO hits for `editorial`, `artwork`, `card` and `Card` |
| The public `StoreKit.framework/Headers/` | 28 entries (= 27 `.h` headers and one `.apinotes`), none of them a card: `SKProduct`, `SKPayment`, `SKStoreProductViewController`, ... |

The card is built from PRIVATE frameworks the App Store app links:
`AppStoreUI`, `StoreUI`, `CommerceKit`, `StoreFoundation`, `StoreJavaScript`
(`/System/Library/PrivateFrameworks/`). Their binaries are not on disk (= they
live in the dyld shared cache), so they cannot be linked by a third-party
app at all.

`SKStoreProductViewController` is the one public StoreKit surface that shows
an app, and it is a product page, not a card: it is `__TVOS_PROHIBITED` and
available on `ios(6.0), macCatalyst(13.0), macos(11.0)`.

### 2.2 The card EXISTS on macOS, and it is the macOS build

The decisive measurement: the macOS App Store app renders the card, on a
native arm64e macOS binary.

- Linkage: `otool -L` shows `AppKit.framework` and `SwiftUI.framework`.
  There is NO `iOSSupport` and NO `UIKit`. The only UIKit-named framework is
  `AppleMediaServicesUIKitInternal`, a private helper whose name only
  contains the string.
- `file`: "Mach-O universal binary with 2 architectures: [arm64e] [arm64e.x1]".
  `LC_BUILD_VERSION` reports `platform 1` (= macOS), `minos 27.0`,
  `sdk 27.0`.

So this is a native macOS AppKit app, NOT an iOS app running under
iOSSupport. That distinction matters for the borrowing question: the card
the boss saw on macOS is macOS's own card, drawn by macOS's own AppKit code.

### 2.3 What the running app's accessibility tree names

The card's classes are visible in the running app's accessibility tree, and
they name themselves:

| AX identifier | What it is |
| --- | --- |
| `AppStore.shelfItem.LargeCardCollectionViewCell<HeroLargeArtworkCardView>` | the large editorial card (a full-image artwork card) |
| `AppStore.shelfItem.LargeCardCollectionViewCell<LargeVideoCardView>` | the large card's video variant |
| `AppStore.shelfItem.MediumCardCollectionViewCell<HeroMediumArtworkCardView>` | the medium card |
| `AppStore.shelfItem.SmallLockupCollectionViewCell` | the small app lockup (icon + name + subtitle) |

The same names appear as Swift classes in the App Store binary, = = read
verbatim out of its `__TEXT` (= the mangled name carries the length of the
unmangled one, = = so the prefix is a CHECK, = = not a label):
`_TtC9App_Store24HeroLargeArtworkCardView`,
`_TtC9App_Store25HeroMediumArtworkCardView`,
`_TtC9App_Store24HeroSmallArtworkCardView`,
`_TtC9App_Store19ArticleCardTextView`,
`_TtC9App_Store15TitleHeaderView`,
`_TtC9App_Store27ArticleCardFooterLockupView`,
`_TtC9App_Store16GridPageCardView`,
`_TtC9App_Store18LargeVideoCardView`,
`_TtC9App_Store12BaseCardView`.

The card's own text tiers, read out of the app's class metadata
(`ArticleCardTextView`'s ivars): `headingField`, `titleField`,
`descriptionField`, `wordmarkHeadingView`, `offerButton`,
`offerLabelPresenter`. And the shelf's section header (`TitleHeaderView`'s
ivars): `eyebrowArtwork`, `eyebrowText`, `titleArtwork`, `titleLabelView`,
`backgroundView`, `separatorLineView`, `isArticleSectionHeaderWithBackground`.

So the App Store's editorial card carries FOUR text tiers and an action:

1. an eyebrow (the category: "Editors' Picks", "New and Noteworthy", "Getting Started"),
2. a title,
3. a description,
4. an offer button.

### 2.4 The card's geometry, measured on the running macOS app

The capture: the App Store window resized to 1400 x 900 points, then
`screencapture -x -l <window id>`, read at 3024 x 2024 pixels (2x).

| Measurement | Value | How |
| --- | --- | --- |
| the card's full width | 2200 px | the panel's BACKGROUND edge (x=632) to the artwork's right edge (x=2831) |
| the artwork's width | 1650 px | the saturated region's bounding box (x 1182..2831) |
| the text panel's width | 550 px | = 25.0% of the card (275 PT) |
| the artwork's share | 75.0% of the card | |
| the card's height | 724 px | the saturated region's bounding box (y 292..1015) |
| the card's ratio | 3.039 : 1 | 2200 / 724 |
| the artwork's own ratio | 2.279 : 1 | 1650 / 724 |
| the outer corner's radius | 24.8 px (= 12.4 PT at 2x) | a circle fitted to the sub-pixel edge over 26 rows, RMS 0.18 px |

⇒ The width is measured from the PANEL'S BACKGROUND, not from its first
glyph: the leftmost ink sits at x=686, and measuring from there drops the
panel's own 54 px of leading padding (= 2146 px, which reproduces the
earlier figure but is not the card's width). The app's own AX frame for
this card agrees with the background edge: `1100 x 362` PT = 2200 x 724 px.

The four ink bands inside the panel, as a percentage down the card:

| Band | Extent | What it is |
| --- | --- | --- |
| 13.4% - 16.6% | 24 px tall | the eyebrow |
| 21.7% - 28.5% | 50 px tall | the title, line 1 |
| 30.5% - 35.5% | 37 px tall | the title, line 2 (the title wraps) |
| 90.2% - 93.5% | 25 px tall | the description, AT THE BOTTOM of the panel |

**⇒ THE KEY STRUCTURAL FACT: THE APPLE CARD IS A SPLIT CARD, NOT A
TEXT-ON-ARTWORK CARD.** The words live in their own panel beside the
image (25% of the width), and the description is pinned to the BOTTOM of
that panel while the eyebrow and title sit at the TOP. The image is never
behind the words.

The medium card's artwork is a CIRCLE, not a rectangle: its saturated
region measures 325 x 340 px (ratio 0.956) and fills 48.6% of its own
bounding box. A circle fills pi/4 = 78.5% of its box; a rounded rectangle
fills ~100%. 48.6% is lower than a circle's 78.5% because the artwork
inside the circle is not uniformly saturated (the second blob's fill is
46%), but the aspect ratio of 0.956 and the visible round crop in the
capture settle the shape.

### 2.5 The conclusion

The App Store's editorial card is:

- NOT iOS-only: it ships in the macOS App Store, in a native AppKit
  binary, and the macOS build's own classes are the ones that draw it.
- NOT a control a client can adopt: it is private App Store code in
  private frameworks, with no public API behind it.

So it is a REFERENCE, and the only thing it can lend is its shape.

---

## 3. The gap between Apple's card and Wenshu's, measured on both

Both sides measured with the same instrument (a screenshot read pixel by
pixel), on the same machine.

| Dimension | Apple's editorial card (macOS App Store) | Wenshu's material card |
| --- | --- | --- |
| where the words live | a separate panel beside the image (25% of the width) | ON the image, bottom left |
| the image's share of the card | 75.0% | 100% (the picture IS the card) |
| the card's ratio | 3.039 : 1 | 4 : 3 (`DesignTokens.coverTileRatio`) |
| the image's own ratio | 2.279 : 1 | 4 : 3 (the picture is generated in it) |
| the corner radius | 12 PT (24.8 px at 2x) | 10 PT (`DesignTokens.surfaceCornerRadiusWindow`) |
| the text tiers | eyebrow, title, description, offer button | title, tag chips |
| the description | yes, pinned to the panel's bottom | **none** |
| the eyebrow (the category) | yes | **none** |
| the shape of the image | a circle (medium card), a full-bleed rect (large card) | a full-bleed rect, always |
| the scrim over the words | none (the words are not on the image) | a black gradient wash (0.18 -> 0.55) |
| the action | an offer button, in the card | none (the card opens on a double click) |

The Wenshu side, read from the source of record:

- The card's body: `Sources/WenshuApp/Features/Editor/View/PreviewPaneCard+Body.swift`.
  The picture fills the tile; the words are a `VStack(alignment: .leading)`
  of `Text(source.title)` plus the tag chips, placed at `.bottomLeading`,
  over a `LinearGradient(colors: [.clear, .black.opacity(0.18),
  .black.opacity(0.55)])` that is applied ONLY when the card has a cover.
- The tile's shape: `.aspectRatio(DesignTokens.coverTileRatio, contentMode: .fit)`
  with `coverTileRatio = 4.0 / 3.0` (`DesignTokens.swift:410`).
- The corner: `RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusWindow,
  style: .continuous)`, and `surfaceCornerRadiusWindow = 10`
  (`DesignTokens.swift:284`).
- The words that exist: `Text(source.title)` and `CardTagChip`. Nothing
  else.

### 3.1 The gap the boss saw, named

The boss said our material card "still has a gap" against the App Store's
card. The measurement names three gaps, and only one of them is a
composition choice:

1. **The summary is not drawn.** `CardSource` HAS a `summary` property
   (`PreviewPaneCard.swift:77-83`, reading `r.summary` / `d.summary`), and
   the model HAS the text (`Reference.summary`, `BookDoc.summary`, and
   every other entity type). The card body never draws it: a repo-wide
   grep for `source.summary` returns ZERO hits outside the property's own
   definition. So the data is loaded, carried, and dropped on the floor.
   Apple's card's third tier is exactly this line, and Wenshu already has
   the text for it.
2. **The card draws no category tier.** `EntityType` HAS a `displayName`
   (the Chinese labels for character / location / event / concept, ...)
   and Apple's card HAS the same tier (its eyebrow). The card draws the
   type's ICON (`source.iconName`, = `r.entityType.icon`) as the
   empty-state watermark, but never the type's NAME. (= = The preview
   zone draws NO `displayName` at all: = = `grep -rn displayName
   Sources/WenshuApp/Features/Editor/View/` returns 12 hits, = = and not
   one of them is a card draw. = = The only occurrence inside the
   preview-zone files is the COMMENT at `PreviewPaneGrids.swift:239`
   describing the header that was removed; = = `BookFolder.displayName`'s
   UI call sites are `SidebarService.swift:315` and
   `ImportSheetHelpers.swift:323`, = = both outside the preview zone; = =
   and `CardOpenOps.swift:178`'s `title: category?.displayName` is a
   TAB's title, not a card's. = = The section
   header that once carried the category was REMOVED on purpose: = =
   `PreviewPaneGrids.swift:239` records that the boss ruled the
   preview zone's header redundant, = = because the sidebar already
   shows the selection. = = So the category tier is absent from the CARD
   by the same removal that took it off the column.)
3. **The words sit on the image.** Apple's words sit beside it, so no
   scrim is needed and the picture is never darkened. Wenshu's words sit
   on it, so a black wash (up to 55% black) covers the bottom of every
   cover. **This is the one gap that is a COMPOSITION CHOICE, and it was
   already a decision**: `docs/agents/2026-10-22-card-cover-research.md`
   records the 2026-10-23 decision, taken against the App Store's own
   card, that "the artwork IS the card, and the words sit on the artwork
   over a wash".

And one thing Wenshu already has that Apple's card does not: the
artwork IS the card, with no separate panel, so one tile carries the
picture, the title and the tags at a 4:3 ratio that the generated covers
are produced in (= nothing is trimmed).

### 3.2 What is TRANSFERABLE, and what is not

Following the rule that a reference app is evidence about RULES and not
about API:

**TRANSFERS (the composition rules):**

- The card carries a CATEGORY, a TITLE and a DESCRIPTION, = = and the
  CATEGORY and the DESCRIPTION sit at the panel's TWO ENDS: = = the
  category at the top, = = the description at the bottom, = = with the
  title between them. = = So the title and the description BRACKET the
  panel rather than stacking under one another.
- The category is a small, quiet line ABOVE the title (= = measured: 24
  px tall against the title's 50 px, = = and it starts 97 px below the
  card's top edge while the title starts 157 px down).
- The description is the quietest of the three (= = 25 px tall, = = and
  its ink is the lowest-contrast band in the panel).
- The image is never behind the words, so the image needs no scrim.
- ⇒ ⇒ AND THE CATEGORY'S CASE IS NOT A RULE: = = in this capture it is
  CJK text with a Latin acronym in caps (= = the app-store label for the
  editors'-picks shelf, = = which the accessibility tree names in full),
  = = so the CATEGORY is a LABEL, = = not a typographic style to copy.

**DOES NOT TRANSFER (the implementation):**

- The card itself: private classes, private frameworks, no public symbol,
  no way to link it.
- The exact ratios (3.039 : 1 and 2.279 : 1): Apple's editorial card is
  sized for the App Store's own page at its own width, and its numbers
  are Apple's, not ours.
- The circle crop on the medium card: Apple's medium card is a different
  card from its large card, and Wenshu has ONE card for one column.
- The offer button: that is a store transaction, and Wenshu's material
  column has no transaction.
- The pixel sizes: the 24.8 px corner, the 550 px panel. These are Apple's
  numbers at Apple's window size.

### 3.3 The two cheapest gaps, if the boss wants them closed

Both are one line each, and neither needs a new API:

- **The description.** `source.summary` already exists on `CardSource`.
  Drawing it under the title = the same `VStack` in
  `PreviewPaneCard+Body.swift:163-178`, with one more `Text`. The data is
  already there; the reading is already there.
- **The category.** `EntityType.displayName` already exists. A quiet
  line above the title = the same treatment the App Store's eyebrow gets.

Both would sit on the SAME scrim the card already draws, so neither needs
a scrim change, and neither changes the card's shape or its ratio.

**⇒ AND THE HONEST CAVEAT: the gap the boss SAW may be the third one.**
The composition choice (words on the image, with a wash) is already a
settled decision, taken against this very reference, and it is what makes
Wenshu's card different at a glance. The two MISSING TIERS are invisible
in a screenshot unless you know to look for them, so they are unlikely to
be what made the boss see a gap. What made the boss see a gap is more
likely the proportions: Apple's card is 3.04 : 1 and Wenshu's is 4 : 3, so
Apple's card is a much wider band, and Apple's medium card's artwork is a
CIRCLE where Wenshu's is always a rectangle.

⇒ A WIDENED TILE or a CIRCULAR VARIANT would each be a visible change, and
each is a product decision about the material column, not a repair. So it
is the boss's call, and it is NOT built here.

---

## 4. What was measured, and how (the receipts)

| Fact | Instrument |
| --- | --- |
| the glass availability annotations | `grep` over every installed SDK's `SwiftUICore.swiftinterface` (iOS, macOS, tvOS, watchOS, visionOS) |
| the AppKit / UIKit glass headers | `cat AppKit.framework/Headers/NSGlassEffectView.h`, `cat UIKit.framework/Headers/UIGlassEffect.h` |
| no public card API | `grep -rl` over the whole macOS SDK's frameworks + `ls` of `StoreKit.framework/Headers/` |
| the App Store app is native macOS | `otool -L` (no `iOSSupport`, no `UIKit`) + `file` + `otool -l` (`LC_BUILD_VERSION platform 1`) |
| the card's class names | `otool -oV` over the App Store binary, then a Python pass for each class's ivars and properties |
| the card's AX identifiers | the running App Store's accessibility tree, read with an `AXUIElement` walk |
| Apple's card geometry | `screencapture -x -l <window id>` of the 1400 x 900 window, then a Python PNG decode and a saturation flood-fill for the artwork's bounding box, and an edge-threshold band scan for the ink tiers |
| Wenshu's card geometry | the same PNG decoder over the app's own 2x capture, plus the source of record |
| Wenshu's card composition | `PreviewPaneCard+Body.swift` and `DesignTokens.swift` read directly |

The Apple window was resized with System Events (1400 x 900 points) and
captured with `screencapture -l`, so the card was measured at its real
size and not at a scaled-down thumbnail.

### 4.1 What was NOT measured, and why it matters

- The card's behaviour while scrolling, while the carousel advances, and
  while a video card plays. The capture is one static frame.
- The card's appearance in the light appearance. The capture is the dark
  appearance.
- The card's geometry at a second window width. Apple's numbers move with
  the page's width, and one measurement cannot say whether the 3.04 : 1 is
  a constant or a consequence of the 1400-point window.

⇒ So the RATIOS are recorded as ONE measurement at ONE size, and the
decision to widen the tile must not rest on them alone.

---

## 5. The open questions for the boss

1. **The two missing tiers** (the description and the category): both are
   one line each, both use text the model already carries, and both are
   invisible in a screenshot unless looked for. Are they wanted?
2. **The proportions**: Apple's card is 3.04 : 1 and Wenshu's is 4 : 3;
   Apple's medium card's artwork is a circle. A wider tile, or a circular
   variant, is a visible change to the material column and a product
   decision, not a repair.
3. **The scrim**: Apple's card needs none because its words sit beside
   the image. Wenshu's card darkens up to 55% of every cover's bottom to
   carry its words. That is the settled 2026-10-23 decision, taken against
   this same reference, so it is raised here as a fact and not reopened.

---

## 6. The references

| Reference | Where it was read |
| --- | --- |
| Apple's newsroom post, 2025-06-09 ("the new design extends across platforms - iOS 26, iPadOS 26, macOS Tahoe 26, watchOS 26, and tvOS 26") | the search snapshot, cross-checked against the SDK annotations |
| Apple's Technology Overviews, "Liquid Glass" and "Adopting Liquid Glass" | the search snapshot |
| Apple's HIG, "Materials" (updated 2025-09-09) | quoted in the `wenshu-apple-api-first` skill's reference `liquid-glass-surfaces.md`, which carries the measured variants table |
| Apple's `GlassEffectContainer` docs (the spacing rule) | quoted in the same reference |
| Apple's App Store binary and its running accessibility tree | measured here |
| Wenshu's card of record | `Sources/WenshuApp/Features/Editor/View/PreviewPaneCard.swift`, `PreviewPaneCard+Body.swift`, `Sources/WenshuApp/DesignTokens.swift` |
