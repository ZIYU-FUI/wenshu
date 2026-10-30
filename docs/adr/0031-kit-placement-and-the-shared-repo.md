# ADR-0031: The wire protocol lives in the client until the shared repository exists

> Status: accepted
> Date: 2026-10-28
> Decision-maker(s): boss

## Context

The product line plan puts the code both sides share in a third
repository, `wenshu-core`, as a root package with a library product and an
explicit version. That is forced by a measured SwiftPM limit: a remote
package cannot be consumed from a subdirectory of another repository, so
the shared unit has to be the root of its own repository.

The client needs that code now, and the Mac companion does not exist yet.
Creating a third repository to hold four small files, before any second
consumer exists, would be a repository with one dependent and no reason.

## Decision

The client carries its own copy of the link contract for now, in
`WenshuMobileKit`. The extraction into `wenshu-core` is triggered, not
scheduled: it happens when the Mac companion card lands.

Constraints that flow from it:

- The kit holds only what the two sides must agree on: the envelope, the
  pairing claims, the commands, the link states. It holds no view and no
  screen.
- The client never grows a second copy of a type the kit already owns.
- The extraction moves the types; it does not rewrite them. A type that
  changes shape during the move is two changes, so it does not move that
  way.
- The dependency is pinned by version once the shared repository exists,
  so the client and the Mac companion cannot drift.

## Consequences

Easier: the client is buildable and testable today, with no dependency
on a repository that has no content yet.

Harder: for a while the wire contract has one consumer, so nothing
forces the two sides apart except this record.

Locked in: the first change that needs a second consumer of the contract
is the extraction.

## Alternatives considered

- Create `wenshu-core` now: rejected, a repository with one dependent
  and no second consumer is a structure without a reason.
- Keep the contract in the Mac repository and have the client depend on
  it: rejected, the same SwiftPM subdirectory limit applies, and the
  Mac repository is macOS-only.
