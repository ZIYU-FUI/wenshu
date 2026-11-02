# ADR-0034: The board client is its own package

> Status: accepted
> Date: 2026-11-02
> Decision-maker(s): 老板 (the directive), pocock (the implementation)

## Context

The boss asked for card-based chapter organization and a content generation
view in Wenshu, modelled on Milanote and Apple Freeform, and then ruled on
2026-11-02 that the replica is NOT built inside the shipping desktop app: "先不
考虑文枢的功能链接和实现，先把两个借鉴项目摸清，即便是写复刻，也先不进现有的文
枢桌面 app，可以起一个端，像文枢移动端一样，给个目录，共用文枢的数据和模型层".

The desktop app is an executable target (`WenshuApp`, a `.executable` product
in the repository root manifest), so its views are not consumable by another
package. A card board inside it would therefore be a copy of the desktop's
views rather than a client of the shared model, and it would land inside the
app the boss said not to touch.

The repository already holds the precedent: `Mobile/` is a second SwiftPM
package in the same checkout, with its own manifest, its own `AGENTS.md` and
its own gate set. The product-line plan records that both sides resolve the
same bytes by construction because a local path package in one checkout does
not drift.

## Decision

The card board lives at `Board/`, as a third SwiftPM package in this
repository, with its own manifest, its own `AGENTS.md` and its own test target.
It consumes the shared data layer as a local path package and the desktop app
as nothing.

The constraints that follow:

- `Board/Package.swift` declares `.package(name: "WenshuData", path: "../Sources/WenshuData")`.
  A dependency path may leave the package root; a TARGET path may not.
- The desktop app's views, its icon factory and its design tokens are not
  consumable, so the client carries its own and does not reach into
  `Sources/WenshuApp/`.
- The client is macOS-only at floor macOS 27, the same floor as the desktop app
  and as `WenshuData`, so the shared package's manifest is not widened.
- The client's SSOT is `Board/AGENTS.md`, and `Board/.hermes.md` is the file
  Hermes injects when a session opens in the client's directory.

## Consequences

Easier: the card model can be tried without touching the shipping app; the
shared data layer is shared rather than copied; the client's gates and its
SSOT are separate, so a change to the card model does not put the desktop
app's ten merge gates in its way.

Harder: the client cannot reuse any of the desktop app's views, so the icon
factory and the design tokens have to be answered again (ADR open item 5.3 in
`Board/AGENTS.md`); a second package means a second `swift build` and
`swift test` in CI; and the client's SwiftData access, if it ever needs it,
has to go through `WenshuData` rather than the app's repositories.

Locked in: the package boundary, the manifest shape, and the client's own
`AGENTS.md`.

## Alternatives considered

- **A feature of the desktop app** (a `Features/Board/` folder): rejected by
  the boss's directive, and independently impossible to share, because the app
  is an executable target.
- **A folder inside `Mobile/`**: rejected — that client is the phone's, its
  floor is iOS 18 and its product is a thin remote control over the Mac, which
  is the opposite of a Mac board that reads the library.
- **A separate repository**: rejected — the product-line plan records that the
  sharing reason is gone once the two sides are one checkout, and a local path
  package is then the right shape.
