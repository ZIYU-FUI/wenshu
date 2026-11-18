# Session closeout: the chat bubble's surface becomes Apple's Liquid Glass

## What the boss ruled

| The boss's words | What it decided |
| --- | --- |
| "不用抄信息的气泡了 / 你就把现在的背景改一下材质就好" | The scope is the MATERIAL of the outgoing bubble. The Messages app's bubble geometry (= its shape, its tail, its proportions, its colours) is NOT the target. The bubble's shape, width, padding, words and position stay exactly as they were. |
| "液态玻璃材质，apple 应该做了视觉的应对，所以你可以完全信任 apple。使用即可，不用反复验证可见性。可见性我肉眼看更准" | Apple's rendering is trusted: the app does not chase a contrast number for the bubble's visibility, and no hand-drawn imitation of a glass is built. The visibility is judged by the boss's own eye. |

The ruling is recorded in `OOB.md` #2026-11-18.

## What changed

| File | The change |
| --- | --- |
| `Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift` | The outgoing bubble's own solid fill is replaced by Apple's Liquid Glass: `.glassEffect(.regular, in: ChatSurfaceShape())`. The shape (= the shared chat-surface shape), the width cap (= `DesignTokens.chatBubbleMaxWidth`), the padding (= `DesignTokens.spacingModerate`), the height floor (= `DesignTokens.controlHeightLarge`) and the text tier are untouched, and the surface is still applied BEFORE the width cap, so it hugs the words instead of spanning the column. |
| `Sources/WenshuApp/Features/Chat/View/ChatUserBubblePalette.swift` | `surface` becomes `inspectorOutputSurface`: the palette's colour now names what it still owns (= the INSPECTOR's output bubble's surface, = its one remaining reader), and the chat bubble's surface is Apple's glass. The appearance-aware text tier stays. |
| `Sources/WenshuApp/Features/Editor/View/InspectorStatusOutputSheet.swift` | The one remaining call site follows the rename. Its bubble keeps its solid surface: the ruling is about the chat transcript's bubble, and the inspector's output bubble is a read-only surface of its own. |
| `Tests/WenshuAppTests/Chat/View/ChatUserBubbleReadabilityTests.swift` | The three colour assertions are re-scoped to the inspector's output bubble (= the chat bubble's surface is Apple's now, = and its legibility is Apple's), and a new assertion holds the MATERIAL: the bubble wears `.glassEffect(.regular, in: ChatSurfaceShape())`, paints no fill of its own, does not read the inspector's surface, applies the glass before the width cap, and wears the palette's text tier. |
| `Tests/WenshuAppTests/Chat/View/ChatUserBubbleShapeTests.swift` | The bubble's geometry is measured from the PRODUCTION LAYOUT (= the laid out frame) instead of from painted pixels. |
| `Tests/WenshuAppTests/Chat/View/ChatTranscriptFlatFlowTests.swift` | The transcript's flat-flow claims ride on the laid out rows and the resting scroll position instead of on the painted card. |
| `docs/agents/nfi.md`, `OOB.md`, this file | The registry rows, the boss's ruling and this record. |

## Why the guards had to move (the measured reason)

The bubble's surface is Apple's glass, and **an offscreen read does not composite a glass surface at all** (= the house's rule from the macOS 27 tab strip: = a control's appearance must be measured on a SCREEN capture). Measured on the real `ChatView` over a host background the app never paints:

- the user's bubble paints NOTHING in an offscreen read (= its words and its surface included: = the bubble's area carries the panel's own colour, = `rgb(251,26,249)`, = 0 pixels of any other kind), while the agent's flat reply text still paints;
- the composer's own glass field still paints (= it is an AppKit text field, = not a SwiftUI text under a glass host).

So the pixel marker that named the user's row is gone, and the claims are carried by what IS there:

| The claim | The instrument now | The measured fact |
| --- | --- | --- |
| The user's row is laid out on the trailing side | the laid out rows: the user's bubble is the one that hugs the TRAILING edge (= every reply is flat text on the leading side) | the user's bubble ends at 592 PT of a 600 PT column; every reply ends at 73 PT |
| No row is held at the viewport's top | the transcript's resting scroll position (= a held row parks the scroll at the top: = the old pinned section header's trigger did exactly that) | the transcript rests at its bottom: the offset is 554 PT of a 970 PT document; the pinned code parked it at 0 |
| The bubble is not a slab | the laid out frame (= the bubble's content = 355x49 at x = 368 in a 723 PT column) | the trailing edge is 723 PT (= the column's width); the width stays under the cap |

## Apple's own words (the citations)

| Apple's sentence | Where it comes from | What it decided here |
| --- | --- | --- |
| "The [regular] variant blurs and adjusts the luminosity of background content to maintain legibility of text and other foreground elements." | Apple's HIG, the `materials` page (= `https://developer.apple.com/design/human-interface-guidelines/materials`, = macOS 27) | The regular variant is Apple's legibility mechanism, so the app does not add its own contrast logic on top of the bubble. |
| "This should be enabled for glass that is used as the background for interactive controls or when used as the container of interactive controls." | Apple's own SDK header, `NSGlassEffectView.h` (= `effectIsInteractive`, = macOS 27) | The bubble wears the NON-interactive variant: a message bubble is content, not a control. |
| "Don't use Liquid Glass in the content layer." | Apple's HIG, the `materials` page (= macOS 27) | The tension with the boss's ruling is recorded here on purpose: the chat bubble IS a content-layer element, and the boss ruled for the glass on it anyway (= OOB #2026-11-18). The next reader sees both. |

## The measured result (the live app, the window-server capture)

The bubble on screen, measured from the running app's own window (= `screencapture -x -o -l<window id>`, = because the offscreen read cannot see the glass):

| Appearance | The glass | The chat panel behind it | The user's words |
| --- | --- | --- | --- |
| Dark | `rgb(75,75,75)` (= a gradient from 77 at the top to 74 at the bottom) | `rgb(42,42,42)` | `rgb(239,239,238)` |
| Light | `rgb(238,238,238)` … `rgb(241,241,241)` | `rgb(234,234,234)` | `rgb(81,81,81)` |

The dark appearance's glass sits a clear step above the panel and Apple's own rim draws the edge; the light appearance's glass is a near-white surface on a near-white panel (= 5 levels of separation, = and Apple's rim draws the edge).

## The open items

- The HIG's content-layer line against the boss's ruling (= above): the ruling stands, and the record carries Apple's line so the next reader sees the tension instead of inheriting it silently.
- Apple's glass samples what is behind it, so the bubble's tone follows the desktop wallpaper (= the house's earlier finding on the right-column cards: = `rgb(228)` … `rgb(255)` across three desktops). The bubble now sits over the app's own translucent root material, so the wallpaper reaches it through that material.
- The layout of the bubble grows by the glass's own rim room (= the content's frame = 355x49 where the solid fill's was 355x36). The shape, the width and the words are unchanged; the band is taller because Apple's glass reserves room for its rim.
