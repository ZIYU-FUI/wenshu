# ADR-0030: The deployment floor is iOS 18, and the foldable APIs arrive by availability

> Status: accepted
> Date: 2026-10-28
> Decision-maker(s): boss

## Context

The boss ruled for a native Apple client that adapts to iPadOS and the
newest foldable phones (OOB.md #2026-10-28). The foldable-native layout
APIs (`ArrangementView`, `reservedRegions`) were measured on this machine
and they are `@available(anyAppleOS 27.1, *)`: they need the iOS 27.1 SDK.

A deployment target of 27.1 would exclude every device that is not on the
newest release, and it would make the package unbuildable on any CI
runner that does not carry the 27.1 SDK.

## Decision

The package deploys to iOS 18 and reaches the foldable-native APIs
through `@available`, with a size-class layout as the fallback below
iOS 27.1.

Constraints that flow from it:

- One layout decision, chosen by the size class, serves iPhone, iPad and
  a foldable. The foldable-specific API refines that layout; it does not
  replace it.
- A foldable that unfolds into a wide screen gets the same split an iPad
  gets, whether or not the foldable-native API is available.
- The macOS platform entry exists only so the kit builds and its tests
  run on a CI host. No macOS product ships from this repository.

## Consequences

Easier: the client installs on the installed base, and CI builds it on
any current runner.

Harder: two layout paths must stay visually equal, because a user may
see the fallback on one device and the native path on another.

Locked in: a new layout rule lands with its fallback, or it does not land.

## Alternatives considered

- Deployment target 27.1 only: rejected, it excludes the installed base
  and ties the build to one SDK.
- A separate foldable app target: rejected, it doubles the surface for a
  layout difference.
