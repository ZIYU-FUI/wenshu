# ADR-0032: The iPhone 18 family is the primary target, and a foldable adapts

> Status: accepted
> Date: 2026-10-28
> Decision-maker(s): boss

## Context

The client had to be seen running on a device. The iOS 27.1 runtime on
this machine carries exactly one device type, the iPhone Duo, the
foldable. Seeing the app on the Duo made the product question visible:
is the foldable the target, or is it one form factor among several?

The boss ruled (OOB.md #2026-10-28): the primary devices are the iPhone
18, the iPhone 18 Pro and the iPhone 18 Pro Max. A foldable has to be
adapted to properly, and it is not the thing the product is made for.

## Decision

The iPhone 18 family is the primary target. The Duo, an iPad and a wide
window are one adaptive code with different size classes, and the
foldable-native APIs refine that code rather than define it.

The supported window is the framework's own: the floor is iOS 18, which
is the iPhone 16 generation, and the top is whatever the framework
supports today, the iPhone 18 family and the Duo. Older models may be
dropped when a performance requirement demands it; nothing below the
iPhone 16 generation is dropped as a matter of course (ADR-0030).

The Duo is adapted, so the adaptation is real work and not a footnote:

- A Duo unfolded into a wide screen gets the split layout an iPad gets.
- A Duo folded back to a narrow screen returns to the phone layout, and
  the decision is recomputed rather than latched.
- Where the platform reports the fold and the camera cutout, the layout
  respects those regions (`reservedRegions`, iOS 27.1).

## Consequences

Easier: one phone-shaped product, and the foldable is a case the
adaptive layout already handles.

Harder: the phone case is the one that has to be right first, so the
foldable-native path may only refine a layout the phone path already
proves.

Locked in: no feature ships for the foldable that the iPhone cannot
show.

## Alternatives considered

- Build the client for the foldable first: rejected, the phone is the
  product.
- Require iOS 27.1 and drop the floor: rejected, the floor buys the
  installed base and costs one fallback path (ADR-0030).
