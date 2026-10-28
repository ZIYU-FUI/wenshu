# ADR-0028: The mobile product line is a separate repository

> Status: accepted
> Date: 2026-10-28
> Decision-maker(s): boss

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
