# ADR-0033: The client's shell is iOS's own

> Status: accepted
> Date: 2026-10-28
> Decision-maker(s): boss

## Context

The client was built as a desktop layout that adapts: a
`NavigationSplitView` with a sidebar on a regular width, and a bare view
on a compact width. The boss saw it running and said it should use
iOS's own framework.

That was right on the facts. The compact branch had no navigation
container at all, so the screen carried no title and nothing to push, and
a phone app without a tab bar is a web page with a status bar.

## Decision

The client uses iOS's own containers:

- `TabView` is the top-level container, so a phone gets the bottom tab
  bar it expects.
- `NavigationStack` is the container inside a tab, so a screen pushes and
  carries a title.
- `NavigationSplitView` is iPad's layout. It appears only where the
  regular width earns it: an iPad, or a Duo unfolded into a wide screen.
  A phone never shows a sidebar.

The chrome is the system's, and it gets there by using the system's own
components, not by imitating an app. Every visual element asks one
question: does the system ship this? If it does, the client uses it and
stops there.

- The tab bar is `TabView`'s. The client draws none of its own.
- The large title is the navigation bar's display mode, not a drawn title.
- A glass card is `.glassEffect(.regular, in:)`, and the glass surfaces of
  one screen share a `GlassEffectContainer`.
- The glass buttons are the system's: `.buttonStyle(.glass)` and
  `.buttonStyle(.glassProminent)`.
- A horizontal carousel is `ScrollView(.horizontal)` with a `LazyHStack`.
- A section header is a `Text` and a `NavigationLink` with an SF Symbol
  chevron, not a drawn arrow.
- Semantic colours, the glass materials, `ContainerRelativeShape`. No
- Dark mode is a first-class case, not an inversion of the light one.

So the client looks like an iOS app because it is built from the parts the
system ships, the same way the desktop client does. Nothing is copied and
nothing is imitated: no Apple artwork, no Apple name, no Apple icon in the
shipped app, and no attempt to reproduce an Apple app's composition. The tab
count and the content are the product's.
## Consequences

Easier: the app looks like an iOS app, and the push model matches the
platform's own navigation model.

Harder: the layout is two decisions now, which container and which size
class, and both have to be testable without a device.

Locked in: a new top-level destination arrives as a tab, and a pushed
screen arrives inside a stack.

## Alternatives considered

- A collapsed `NavigationSplitView` on the phone: rejected, that is the
  desktop layout adapting to a phone, which is what this decision
  removes.
- UIKit instead of SwiftUI: rejected, one codebase covers every form
  factor.
