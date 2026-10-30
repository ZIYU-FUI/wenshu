# ADR-0028: The mobile product line is a separate repository

> Status: superseded (2026-10-30)
> Date: 2026-10-28
> Decision-maker(s): boss
> Superseded by: the client's move into this repository, at `Mobile/`

## Superseded

The client is in THIS repository, at `Mobile/`, as a second SwiftPM
package beside the desktop one. This decision is history, and it is kept
because the reason it was made is the reason the move was hard.

**What was decided here was a PM's inference, not the boss's ruling.** The
boss said a new project DIRECTORY (OOB.md, 2026-10-28). The separate git
repository was added on top of that, and this ADR recorded it as if it had
been ruled. It was not: the decision-maker line above said so at the time,
and the reasoning was the PM's.

**The cost was counted.** Forty-one files existed under both names,
twenty-one of them the gate scripts and the method documents, and every
change to a gate had to land in both. The port rule was the only thing
keeping them honest, and it cost a card every time: the review-gate fix
this week was one card on the desktop and another to port it.

**The technical objection here did not hold.** This ADR said the root
manifest would have to claim a support it does not have. Measured
2026-10-30: SwiftPM uses the NEAREST manifest, so a package in a
subdirectory builds with the plain command from inside it, and the root
manifest keeps declaring macOS only while the client declares ios and
macos for itself. A package's target path may not escape its package
root, so the client had to move as ONE package (= app + kit + tests),
which is what it did.

**What survives from this decision.** The client is still a separate
PRODUCT with its own release train, its own signing identity, its own CI
job, and its own rules (its SSOT is `Mobile/AGENTS.md`). What changed is
where it lives and who owns the method: the gates are one copy at the
repository root, and the product lines are declared once in
`Tools/wenshu-devtool/product_lines.py`.

## Context

The boss ruled on 2026-10-28 (OOB.md) that the mobile client enters the
product line as its own project, that the relay must simplify the user
configuration without this project paying for it, that the client is
native Apple and adapts to iPadOS and the newest foldables, and that the
Hermes model (the computer stays online and the phone drives it) is
accepted.

This repository is macOS-only, and its editor is built on AppKit, which
does not exist on iOS. Its root package declares macOS only, and it
holds two local path packages. Adding an iOS client here would make the
root manifest claim a support it does not have, and it would put a
mobile-supporting package in front of a repository whose own scope row
says macOS-only.

## Decision

The native client lives in the sibling repository wenshu-mobile, with
its own governance, its own board, and its own project. This repository
keeps the desktop app.

Constraints that flow from it:

- The two repositories share a method, not a codebase. The same SSOT
  shape, the same gates, the same board-card workflow, the same commit
  and review contracts.
- The code both sides must agree on = the link contract. It lives in the
  client until a second consumer needs it, then it moves to a shared
  repository pinned by version, because SwiftPM cannot consume a
  subdirectory of a remote repository.
- This repository names the sibling in its scope row and its reference
  index. It does not restate the mobile plan.

## Consequences

Easier: the desktop package keeps declaring what it actually supports,
and the mobile client ships on its own cadence.

Harder: a change to the link contract touches two repositories, and the
gate scripts exist in both. The port rule (each repo's copy is the
semantic SSOT, a gate change lands in both) is what keeps them honest.

Locked in: the mobile product line is a peer, not a subdirectory.

## Alternatives considered

- An iOS target inside this repository: rejected, the root manifest
  would have to declare iOS, and the AppKit editor cannot be shared.
- A web client: rejected by the ruling for a native Apple client.
- A monorepo: rejected, the two products have different release trains
  and different signing identities.
