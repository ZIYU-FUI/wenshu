# The macOS 27 UI defaults todo list (= what the audit found, = and
# what each fix replaces)

Date: 2026-11-12. Branch: `main` (research only, = no product code touched).

Scope: a read-only audit of `Sources/WenshuApp` (436 Swift files, 90,535
lines) against the macOS 27.0.1 SDK (Xcode 27.2). Three questions, = each
answered by a measurement rather than an impression:

1. What does the app draw itself (= and what does macOS 27 already ship)?
2. Which Apple defaults does the app pin (= and what does Apple pick)?
3. What does the best-looking card on the machine actually do?

The three reference documents (= the measurements, = each with the SDK line
or the pixel that proves it) live in the visual-audit skill:

| reference | what it holds |
| --- | --- |
| `skills/wenshu-visual-audit/references/macos27-inspector-column-has-no-cards.md` | no macOS card primitive exists, = the official parts that replace the column's rows, = the three complaints on the shipping card, each measured |
| `skills/wenshu-visual-audit/references/wenshu-handrolled-ui-inventory.md` | 26 widget shapes, = 18 that duplicate a shipped control, = 8 justified hand-rolls |
| `skills/wenshu-visual-audit/references/wenshu-forced-over-apple-defaults.md` | the ~160 pinned parameters, = each against the SDK line that proves the default |
| `skills/wenshu-visual-audit/references/weather-card-architecture.md` | the reference card's numbers off the real screen, = and the fact that macOS Weather IS the iOS app |

## 0. THE COUNT (= the scope's size)

| Metric | Count |
| --- | --- |
| `struct X: View` | 112 |
| hand-rolled widget shapes | **26** |
| of those, duplicating a control macOS 27 ships | **18** |
| justified hand-rolls (= no Apple control exists) | **8** |
| custom `ButtonStyle` / `ToggleStyle` / `SliderStyle` | **0** |
| `NSView` / `NSControl` subclasses | **0** |
| `Canvas {` / `Path {` / `NSBezierPath` hand-painting | **0** |
| `NSViewRepresentable` bridges (= all thin) | 6 |
| pinned-over-Apple-default sites | **~160** |
| `DesignTokens.swift` | 480 lines, 103 constants |
| `IconStyles.swift` | 29,912 bytes (= a 190-line `IconStyle` enum + the `SFIcon` factory) |

**THE APP DOES NOT HAND-ROLL CONTROLS.** Zero custom styles, zero
AppKit subclasses, zero hand-painted geometry. What it hand-rolls is a
token layer (= ~35 KB of constants) and 26 composite shapes. The
problem is not the amount, = it is that 18 of the 26 duplicate a control
macOS 27 already ships, = and that ~160 parameters are pinned where
Apple would have picked.

## 1. THE P0 GROUP (= the three defects that make the column read as
##    "not macOS 27", = one lever each)

Each row is measured on the real screen or read out of the SDK. The
"replaces" column names the Apple's own default the fix restores.

| # | Defect | Measured | Fix | Replaces |
| --- | --- | --- | --- | --- |
| 1 | the card's radius is **half** Apple's | `surfaceCornerRadiusCard = 8` (`DesignTokens.swift:270`), = 12 call sites; Apple's own card radius measured **16 PT** | raise the token to 16 | = the app's own value |
| 2 | the glass's **shape resolution** is replaced | `glassEffect(_ glass: Glass = .regular, in shape: some Shape = **DefaultGlassEffectShape()**)` = the default shape is container-relative (`SwiftUICore.swiftinterface:3085`, `DefaultGlassEffectShape` at `:3090`) | drop the `in:` argument, = or pass a `ConcentricRectangle` | = Apple's shape resolution, = which follows the container |
| 3 | the glass is tinted **30% white** where Apple's default is untinted | `Glass.tint(_ color: Color?)` = **nil = untinted** (`SwiftUICore:7432`); wenshu pins `.regular.tint(.white.opacity(0.30))` (`InspectorCard.swift:109`); measured on the column ground: untinted **229**, tinted **222**, ground **235** | drop the tint, = or tint by the item's own colour | = Apple's untinted default |

**WHY THESE THREE ARE ONE SCOPE.** They are the only three defects that
touch the card the complaint is about, = each is one line, = and each is
measured. The reference card settles the target: Apple's own card
measured RGB **104,150,173** on a **147,188,209** backdrop (= the card is
DARKER than its ground, = by 43 levels, = and it carries no stroke and
no shadow), with a **~16 PT continuous** corner, = **16 PT** gaps, = one
hero number at **14-19 PT** ink, = one caption at **10-11 PT**, = all ink
pure white at **3.20:1**, = and the state carried by a GRAPHIC (= a
gradient bar, = a compass dial, = a sun arc), = not by a coloured edge.

**WHY 22 IS DARKER THAN 229 IS THE POINT.** The current card is a grey
slab that sits BELOW its ground. Apple's is a tinted sheet that sits
BELOW its backdrop but reads as a separate surface. The difference is
the tint's colour and its strength, = not the presence of a tint.

**THE MEASURE THAT PROVES THE FIX.** The card's ground must measure
DARKER than the column ground (= as Apple's does against its backdrop),
= and its corner must measure ~16 PT on the real screen. A claim about
"more native" is not a measurement; = a pixel number is.

## 2. THE P1 GROUP (= replace a hand-rolled shape with the shipped
##    control)

Ordered by how much of the app each one touches.

| # | Hand-rolled | Apple's control (= the availability) | Sites | Replaces |
| --- | --- | --- | --- | --- |
| 4 | `EmptyStateView` (= a clone of `ContentUnavailableView`, = its own docblock says so) | `ContentUnavailableView` (macOS 14.0+, `SwiftUI.swiftinterface:23409`) | 11 | a duplicate of Apple's control |
| 5 | `InspectorSectionSwitch` (= the column's three tabs) | `Picker` + `.pickerStyle(.tabs)` = `TabsPickerStyle` (**macOS 27.0+**, `SwiftUI.swiftinterface:16770-16777`) | 1 | a `Picker(.segmented)` with icon-only labels |
| 6 | `LabelSegmentedControl` (= a 22.7 KB `NSSegmentedControl` bridge whose own docblock says it exists because "SwiftUI does NOT expose `NSSegmentedControl.Role`") | the same `.pickerStyle(.tabs)` = the role macOS 27 exposes, = without the bridge | 2 | the bridge itself |
| 7 | `StatusPulse` (= a hand-written 5-second timer fading a dot) | `.symbolEffect(.pulse)` (macOS 14.0+, `Symbols.swiftinterface:22-24`; the `symbolEffect(_:options:isActive:)` overload at `SwiftUICore:16856`) | 1 | a hand-rolled timer |
| 8 | `SFLabelRow`, `InspectorStyleKnobView`, `CoverRouteRow`, `MemoryEntryRow`, `ImportTaskRow` (= hand label/value rows) | `LabeledContent` (macOS 13.0+, `SwiftUI.swiftinterface:5343`) = the app uses it **4** times in 436 files | 5 | five copies of the same row |
| 9 | `InspectorFormatCommandStrip` (= icon buttons joined by a hand `Divider()`) | `ControlGroup` (macOS 12.0+, `SwiftUI.swiftinterface:20187`) | 1 | the hand-drawn divider |
| 10 | `InspectorFormatBlock` (= a hand-drawn "control surface") | `GroupBox` (macOS 10.15+) = the only official bounded container | 1 | the hand-drawn surface |
| 11 | `CardTagChip`, `ChapterFocusLockBadge`, `ChatAttachmentPreviewChip` | `.badge(_:)` (macOS 12.0+, `SwiftUI.swiftinterface:27407`) + `Label` + `.quaternary` capsule | 3 | three hand-drawn chips |
| 12 | `WizardStepIndicator` (= dots joined by a hand `Rectangle()` connector) | `Stepper` (macOS 10.15+, `SwiftUI.swiftinterface:26975`) + `Picker(.radioGroup)` | 1 | the hand-drawn connector |
| 13 | `ImportProgressStrip` (= a `ScrollView` + `LazyVStack` of rows) | `List` | 1 | a hand-rolled list |
| 14 | the state edge (= a 2 PT `Rectangle()` overlaid on the rounded glass) | a graphic inside the row (= a `Gauge` / `ProgressView` / SF Symbol), = the way the reference card carries its state | 1 | the edge that protrudes past the card's rounded corner |

**THE TYPE LADDER IS PART OF 14.** The card's name, state and task text
all carry `.primary`, = so three primary inks compete in one record; and
the trailing time measures **2.30:1** against the card ground (= below
the **3.20:1** the reference card's own body text achieves). The fix is
the four-tier ladder the app already defines (= `DesignTokens.textBody`
/ `textChrome` / `textMetadata` / `textPlaceholder`), = plus a state
that is a graphic.

**THE THREE P1 ROWS THAT ARE NOT STRAIGHT REPLACEMENTS.** #5 and #6
replace the control, = but the tab strip's appearance must be measured on
a SCREEN capture (= an offscreen `cacheDisplay` renders `.tabs` with its
selected label INVISIBLE, = a trap already recorded in the skill).
#6's `.valueSelection` role stays (= the chat zone's scope bar is a value
selection, = not a page switcher). #14 changes what the card SAYS, = so
it needs the boss's eye (gate 7.7), = not a pixel diff.

## 3. THE P2 GROUP (= the pins that are right to keep, = and the ones
##    that are not)

### 3a. Keep (= each matches Apple's own value)

| Pin | Apple's value | Measured |
| --- | --- | --- |
| `IconStyle.small` = 16 | `ControlSize.mini` = 16 PT | matches |
| `IconStyle.toolbar` / `.paneTab` = 18 | `ControlSize.small` = 18 PT | matches |
| `IconStyle.emptyStateHero` = 76 | `ContentUnavailableView`'s default icon zone = 76 PT | matches |
| `bodyFontSize` / `captionFontSize` / `caption2FontSize` | read `NSFont.preferredFont(forTextStyle:)` | = reads the default, = the ONE place the token layer does not pin |
| `bezelStyle = .glass` + `borderShape = .circle` | a documented pairing (= without the circle the glass bezel renders as a rectangular panel) | keep |
| `GlassEffectContainer(spacing:)` in 3 places | groups adjacent glass | keep |
| `.hoverWash` | `.hoverEffect` is `@available(macOS, unavailable)` (`SwiftUICore:2227`) = macOS has NO hover-effect API | keep (= it is the only path) |
| `.contentShape(Rectangle())` × 15 | Apple's own idiom for extending a glyph's tap target | keep |
| the 5 cover-art shadows | Apple's own text-over-media does the same | keep |

### 3b. Change (= each pins a value Apple no longer picks)

| # | Pin | Apple's default | Verdict |
| --- | --- | --- | --- |
| 15 | `segmentStyle = .roundRect` / `.rounded` | `NSSegmentStyleAutomatic = 0` = "appearance is chosen depending on the type of window and **the control's position inside it**" (`NSSegmentedControl.h:26`) | = the position-awareness is lost. Use `.automatic` |
| 16 | `segmentDistribution = .fit` (2 sites) | `NSSegmentDistributionFill` = **"Default value"** (`NSSegmentedControl.h:42-43`; `:117` says it defaults to Fill on 10.13+) | = `.fit` is the pre-10.13 behaviour. Use `.fill` |
| 17 | `IconStyle.hitArea` = 28 | `ControlSize.regular` = 32 PT for a toolbar button; 28 PT is the HIG **minimum** tap target | = the pane tab and the trailing icon buttons are 4 PT smaller than Apple's toolbar |
| 18 | `.controlSize(.small)` × 13 | `ControlSize.regular` | = the density comes from here. Each site decides on its own |
| 19 | `spacing: 0` × 41 | the stack's default spacing | = 41 sites switch Apple's rhythm off. Most are legitimately tight; = each is a decision to re-confirm |
| 20 | `.font(.system(size: 14, weight: .regular))` (`WindowOpenButton.swift:92`) | the semantic scale | = replace with a semantic font |
| 21 | the other 5 radius tokens (= 3, 5, 6, 10, 12) | the container's concentric radius (`ConcentricRectangle`, macOS 26+, `SwiftUICore:17279`; `concentricCornerRadii(in:)`, `:10388`) | = each is a fixed number where Apple resolves the radius from the container |

**WHY 19 IS NOT A DEFECT YET.** `spacing: 0` inside a card is a deliberate
tight packing, = and Apple's own rows are tight. The count is a
re-confirmation list, = not a defect list. It is on the list because 41
sites is where a rhythm drifts, = not because 41 is wrong.

**WHY 21 IS A GROUP AND NOT A LIST OF SEVEN.** The seven radius tokens
are one decision (= "the app picks its own corner numbers") wearing seven
names. `surfaceCornerRadiusCard` (8) is the load-bearing one, = because
it drives the inspector card, = the chat tool cards, = the plan card, =
the tool-result card, = the attachment chip, = the diff preview, = and
the sidebar sheets.

## 4. THE TWO DECISIONS THE BOSS OWNS (= they are not the audit's to
##    make)

### 4a. Does the column keep cards at all?

| | A. Keep the card, rebuild it on Apple's parts | B. Replace the card with native rows |
| --- | --- | --- |
| the column reads as | macOS 27's own cards (= if the parts are Apple's) | macOS 27's own inspector (= what Pages ships) |
| the HIG | "Don't use Liquid Glass in the content layer" (= the card's glass is in the content layer) | the rows are content, = the column carries the material |
| the cost | the glass stays in the content layer | the card form is gone |
| the work | the P0 group + the P1 group | the P0 group's #1, #2, #3 lose their subject, = and the P1 group grows |

**THE AUDIT'S RECOMMENDATION: A, = then B as the separate scope.**
Pages' format inspector has no cards (= measured, = and the reference
holds the measurement), = so B is the macOS-native end state. But A is
what makes the column legible TODAY, = and A's three defects are three
measured lines. Doing A first, = and letting B arrive with its own
scope, = keeps both honest.

**THE REFERENCE CARD DOES NOT SETTLE THIS.** macOS 27's Weather IS the
iOS app (= it links `/System/iOSSupport/.../UIKit.framework` and
`WeatherUI.framework`, = and its window is a UIKit scene), = so its
cards are an iOS design language. What it proves is the CARD MODEL
(= a radius that is a per-container configuration, = a background and a
foreground effect resolved separately, = one hero number, = a state that
is a graphic, = white ink at 3.2:1) = and the card model is portable.
The SKIN (= a tinted panel over a wallpaper photo) = is not.

### 4b. Does the tab strip become Apple's `.tabs`?

The column's three tabs are `Picker(.segmented)` with icon-only labels
today. macOS 27 ships `Picker(.tabs)` = the official tab strip, = with
the selected segment's label VISIBLE. Whether the three tabs keep their
icons or gain their names is the boss's call, = because the names are
what make the tab strip Apple's, = and the icons are what the column
has now.

## 5. WHAT THIS SCOPE DID NOT TOUCH

- **No product code changed.** `git diff` on `Sources/**` is empty; the
  tree carries only untracked scratch files from earlier sessions.
- **No board card.** Rule 1.12: the developer writes the code in its own
  session and worktree, = and creates NO board card for the work. A
  review card follows a commit, = not this document.
- **No simulator, no device, no app launch.** Every number is from the
  SDK's own interface files, = from the app's own source, = or from a
  real-screen capture of the running app and of `/System/Applications/
  Weather.app`.
- **The 8 justified hand-rolls stay.** `ChatSurfaceShape` (= a speech
  bubble has no Apple control), = the `IconStyle` factory, = the
  `DesignTokens` layer, = `GlassIconButton` (= the AppKit glass bezel
  with its circle), = `EditorChatNSController` (= an AppKit split), = and
  three thin bridges.

## 6. THE OPEN ITEMS, = AND WHO OWNS THEM

| item | owner | state |
| --- | --- | --- |
| #1 #2 #3 (the P0 group) | pocock | = = = ready to build, = one scope, = one commit, = one review card |
| the four P0 measurements on the running app (the card's ground vs the column ground, = the corner's PT, = the ink's contrast, = the shape's radius) | pocock | = = = ready to build with #1 #2 #3 |
| #4..#14 (the P1 group) | pocock | = = = one scope each, = or one scope for the four `LabeledContent` rows |
| #15..#21 (the P2 group) | pocock | = = = each a decision to confirm, = not a defect to fix blind |
| 4a (cards or rows) | the boss | = = = the decision, = and it gates the P0 group's subject |
| 4b (icons or names on the tab strip) | the boss | = = = the decision, = and it gates #5 #6 |
| the tab strip's own appearance | pocock | = = = measured on a SCREEN capture, = never on `cacheDisplay` |
| the three findings' place in the column's visual record | pocock | = = = the P0 measurements land as the record |

## 7. THE TRAPS THIS AUDIO HIT (= each cost time, = each is now in the
##    skill)

| Trap | The rule |
| --- | --- |
| `grep 'List *{'` returns **0** | the call is `List(` with a data argument. Always grep `List *(` |
| `grep 'Form *{'` returns 52 | most are a `Section {` inside a `Form`; the real `Form {` count is **10** |
| `grep 'Slider'` returns 0 | = there is no slider in the app (= the style knobs are `Menu` pickers). Do not report "custom sliders" |
| `grep 'cornerRadius:'` returns **0** | every radius goes through a `DesignTokens` name, = and the token file lives at `Sources/WenshuApp/DesignTokens.swift`, = NOT under `Shared/UI/` |
| `NSFont.systemFont(ofSize:)` hits 2 | = they are in a PDF export, = not UI |
| `.hoverEffect` greps in the SDK | it is `@available(macOS, unavailable)` = it is NOT a macOS replacement |
| `Glass.tint(_:)` takes `Color?` | = nil = untinted is the default, = so "the app tints 30% white" is a deviation |
| `glassEffect`'s default shape | = `DefaultGlassEffectShape()`, = a container-relative shape with a `ShapeRole` = passing `in:` REPLACES Apple's shape resolution |
| the Weather window is AX-only | = a UIKit scene, = so no CGWindow id, = `screencapture -l` cannot target it, = `AXRaise` returns -25206, = and `activate` works |
| an offscreen `cacheDisplay` hides a selected label | = a control's appearance must be measured on a SCREEN capture |
