# ADR-0029: The mobile client is native Apple, and the Mac stays the writer

> Status: accepted
> Date: 2026-10-28
> Decision-maker(s): boss

## Context

The boss ruled four things on 2026-10-28 (OOB.md #2026-10-28): the mobile
client enters the product line as its own project; the relay must simplify
the user configuration and must not be a cost this project carries; the
client is native Apple and adapts to iPadOS and the newest foldables; and
the Hermes model (the computer is online and the phone drives it) is
accepted.

The desktop app is macOS-only and its editor is built on AppKit, so its
views cannot be moved to a phone. The .ws library and its canonical body
text live on the Mac, and a phone cannot be a second writer of them.

## Decision

The mobile client is one native SwiftUI codebase for iPhone, iPad and
foldable, and the Mac companion remains the single writer of the library.

Constraints that flow from it:

- One codebase, one layout decision: the split is chosen by size class, so
  a foldable that unfolds into a wide screen gets the split an iPad gets.
- The device holds no authoritative library: it holds a read projection, a
  draft area, and a pairing key.
- Every write is a command that names the revision it was based on, so a
  Mac that has moved on refuses instead of overwriting.
- The app encrypts the body text itself. A tunnel that terminates TLS is
  transport, not confidentiality.
- Reachability is bought on the user's own account and driven by the Mac;
  the user only logs in, scans, or types a code.

## Consequences

Easier: one app to ship and one set of rules; the phone never has to
reconcile two writers; the offline question is deferred rather than
answered badly.

Harder: the phone is useless while the Mac is asleep, and that is a
product fact the UI must state plainly instead of hiding.

Locked in: the link protocol carries a version, and a peer that speaks a
different version is refused at the handshake.

## Alternatives considered

- A web client: rejected by the ruling for a native Apple client.
- Moving the AppKit editor to the phone: rejected, AppKit does not exist
  on iOS.
- Full offline sync with CRDT: deferred. The first release needs one
  writer, not a merge algorithm.
