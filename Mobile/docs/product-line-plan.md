# Wenshu Mobile: product line and architecture plan

Date: 2026-10-28
Status: proposal for project approval and architecture review
Lives in: the wenshu-mobile repository (= the native client). Paths that name
the desktop app are marked (desktop repo); everything else is relative to
this repository.
Scope: the mobile product line, the Mac companion service, the relay and tunnel
model, the sync boundary, the native client, and the phased rollout.

Every claim below marked VERIFIED was measured on this machine or read from the
source of truth during this investigation. Claims marked UNVERIFIED need a
purchase, a contract, or a legal answer before they become commitments.

---

## 1. The four rulings, translated into design consequences

| Ruling | Design consequence |
| --- | --- |
| Mobile enters the product line and may carry its own `wenshu-XXX` project | This repository (`wenshu-mobile`) holds the native client. The macOS repository keeps the desktop app. A second repository `wenshu-core` holds the code both sides share. |
| The relay must simplify user configuration, and Wenshu does not pay for it | Wenshu operates no relay. Reachability is bought from a tunnel provider on the user's own account, and the Mac companion drives that provider's client automatically. Every cost lands on the user, the enterprise, or a capped pilot budget. |
| Native Apple, adapting automatically to iPadOS and the newest foldable phones | One SwiftUI codebase, deployment floor iOS 18 with the foldable-native APIs behind `@available` (ADR-0030). The iPhone 18 family is the primary target; a foldable is the same adaptive code, adapted to fit (ADR-0032). |
| Computer-authoritative remote control, the way Hermes does it | The Mac holds the only writer. The phone is a thin client plus a local draft buffer. The Mac must be awake with Wenshu running. |

Ruling 4 removes the hardest engineering question from the first release. A
single writer needs no distributed merge, no CRDT, no operation transform. The
hard part that remains is the network and the package boundary.

---

## 2. Verified facts this plan rests on

These were measured, not assumed.

### 2.1 The code can already reach iOS

- VERIFIED (desktop repo): `Sources/WenshuData` has no AppKit or UIKit import. Copying the
  package to a scratch directory and widening its manifest from
  `platforms: [.macOS(.v27)]` to `[.macOS(.v27), .iOS(.v27)]` produced a clean
  iOS Simulator build: zero errors, zero warnings, 25 object files, both
  `arm64-apple-ios-simulator` and `x86_64-apple-ios-simulator` modules, with
  `otool -l` confirming the iOS platform on the emitted object.
- VERIFIED: the shipped manifest still says `.macOS(.v27)` only. The iOS build
  was proven on a copy. The original repository is unchanged.
- VERIFIED (desktop repo): `Sources/WenshuAgent` contains no AppKit or macOS UI symbol. Only
  a static scan, so an iOS build is still owed.
- VERIFIED: `ArrangementView` and `reservedRegions` exist in the
  iPhoneSimulator27.1 SDK and are annotated
  `@available(anyAppleOS 27.1, *)`. A probe app using both, with
  `TARGETED_DEVICE_FAMILY: "1,2"`, built successfully for
  `generic/platform=iOS Simulator`.
- VERIFIED: this machine has no iOS Simulator runtime installed, so a generic
  build is not a device or UI proof.

### 2.2 SwiftPM cannot consume a subdirectory of a remote repository

- VERIFIED: two declarations were tried against a local remote clone with a
  tag, `.package(url:from:path:)` and `.package(name:url:from:path:)`. Neither
  resolved the subdirectory package.
- Consequence, and it is the single most important packaging fact in this
  plan: a shared package that another repository consumes over the network must
  sit at the root of its own repository and expose a library product with an
  explicit version. The current `wenshu` root package exposes one executable
  product only, so `wenshu-mobile` cannot yet consume anything from it.

### 2.3 The tunnel provider sees plaintext unless the app encrypts

- VERIFIED: the currently configured public endpoint
  `https://2puepn2t.tocmcc.cn:443/` presents a certificate issued to
  `tocmcc.cn`, and the local port behind it is plain HTTP on
  `127.0.0.1:9119`. The tunnel operator terminates TLS and can read the
  decrypted traffic.
- VERIFIED: that same public endpoint served `/api/status` with HTTP 200 and
  no authentication, returning system paths, a profile name, and an install
  identifier.
- Consequence: manuscripts never travel as plaintext through a provider
  tunnel. The phone and the companion must agree a session key at pairing time
  and encrypt the body end to end. A provider tunnel then carries ciphertext
  plus minimal metadata.

### 2.4 The authoritative body text is on disk, not in the database rows

- VERIFIED (Mac side): the live `.ws` library holds its writing as Markdown under
  `shelves/<shelf>/books/<book>/world/*.md`, 17 files and about 58 KB in the
  inspected book, plus 6 reference files at about 49 KB and the same content
  mirrored under `reference-library/`.
- VERIFIED: the `ZWSCHAPTER` table carries a `ZWBODY` column but holds zero
  rows in both stores on this machine. The Application Support store holds
  about 14.8 MB of memory and kanban-task rows and no chapter rows.
- VERIFIED: two stores exist, `~/Library/Application Support/WenshuStore.store`
  and `~/Documents/<book>.ws/WenshuStore.store`.
- Consequence: the phone is not a client of SwiftData rows. It is a client of
  a logical document model the Mac serves over the local API.
- VERIFIED: `references/<uuid>.md` is the canonical reference and
  `reference-library/<layer>/<uuid>.md` is a second copy. A sync must write the
  canonical copy and let the Mac regenerate the mirror, never write both.

### 2.5 What the license permits

- VERIFIED: `kaishi00/hermes-conduit`, `kaishi00/hermes-conduit-notifier` and
  `NousResearch/hermes-agent` all report `spdx_id: MIT` from the GitHub API and
  carry MIT license text. Reading, copying, modifying and redistributing the
  code is allowed, with the copyright notice and the license text retained.
  MIT carries no patent grant, and no brand, icon or endorsement may be reused.
- VERIFIED: the DDNSTO client repository declares no license and is an issue
  tracker. Nothing in it may be copied, redistributed, or bundled. Only the
  commercial product and its official terms are usable, and only after the
  terms are confirmed.
- VERIFIED: the relay routing in the Hermes push plugin concentrates on token
  challenges, installations, live activity, pairing, events, gateways, watch
  tools, ring, session, control and a decision mailbox. No general dashboard,
  chat, or document proxy route exists. A relay does not carry manuscripts for
  us.

### 2.6 Signing and compliance reality

- VERIFIED: this machine has no Apple Developer Program identity and no
  provisioning profile. There is a local development signing identity only.
  No device build, no TestFlight upload, and no App Store submission can be
  produced from this machine as it stands.
- UNVERIFIED: Apple Developer Program fee for the current year, the entity
  requirements, and the China mainland filing path. These need the account
  owner and, for the filing questions, a lawyer.
- VERIFIED: Apple's China mainland compliance information page requires
  filing information for apps distributed in that storefront.

---

## 3. Architecture

Four pieces. The Mac owns everything that matters; the phone is a client.

```
  phone (wenshu-mobile, SwiftUI)
        |  HTTPS, app-layer E2EE payload
        v
  provider edge (TLS terminates here, operator sees ciphertext only)
        |  outbound tunnel client, started and supervised by the Mac
        v
  Mac: Wenshu.app  ->  companion API on 127.0.0.1 (the only writer)
        |                     |
        |                     +-- store tier: .ws files + SwiftData
        +-- agent entry: WenshuConductor.handle
```

### 3.1 The Mac companion

The companion is the local service the phone talks to. It is the only writer
to the library, the only place the agent runs, and the only thing the tunnel
client points at.

- VERIFIED: the macOS app is not sandboxed
  (`com.apple.security.app-sandbox = false`), so it can bind a loopback
  listener without an entitlement change. It currently has no listener at all.
- VERIFIED: no production `NWListener`, `NWConnection`,
  `NWProtocolWebSocket` or HTTP server exists in the tree today.
- VERIFIED: `WenshuConductor.handle` is the headless-capable agent entry and is
  the correct seam for a bridge, but the package's `Public/` directory exposes
  only `LLMMessage`, `LLMResponse` and `WABaseProvider`. A stable service
  surface does not exist and has to be carved out.

Where the companion lives in the first release: inside the running Wenshu
app process. The Mac is awake and the app is open, which is exactly the
condition ruling 4 accepts. A separate `SMAppService` helper comes later, when
the requirement "the phone works while Wenshu.app is closed" is written down
and priced. That split keeps the first release free of a second bundle
identifier, a second signing identity, and a launchd lifecycle.

Local API, the contract the phone codes against:

| Method | Path | Meaning |
| --- | --- | --- |
| GET | `/v1/ping` | Server version and capability flags |
| POST | `/v1/pair` | Exchange a pairing code for a device token |
| GET | `/v1/library` | Shelves, books and chapter outlines, metadata only |
| GET | `/v1/chapter/{id}` | One chapter: body text plus revision |
| PUT | `/v1/chapter/{id}` | Write back with `baseRevision` for optimistic locking |
| GET | `/v1/references` | Reference list with canonical paths |
| GET | `/v1/events` | WebSocket event stream |

Security rules for that listener, each traceable to a measured failure:

- Bind to loopback only. Never a public interface, never a LAN interface.
- Every route except `/v1/ping` requires the device token.
- No unauthenticated diagnostics route. The public tunnel served exactly that
  kind of route and leaked paths and identifiers.
- The library path never appears in a response body, a log line, or an error
  message that can reach the client.

### 3.2 The relay and tunnel model, and who pays

The provider's edge is the relay. Wenshu does not run one.

The user never touches a VPS, a domain, a certificate, a port mapping, or an
FRP configuration file. The user sees one QR code.

| Path | Who pays | What the user does | When to use |
| --- | --- | --- | --- |
| LAN | Nobody | Scan the QR on the Mac | Same network. The default for a first run. |
| User's own tunnel account | The user | Pay the provider, sign in once on the Mac | Remote access. The Mac automates the rest. |
| User's own mesh account | The user | Install and sign in once | Remote access without a public endpoint. |
| Enterprise account | The enterprise | Nothing | Fleet use, own tunnel or own server. |
| Capped pilot subsidy | Wenshu, capped | Nothing | A bounded number of users for a bounded term, expiring on schedule. |

VERIFIED: cpolar supports local TLS termination with `-crt` and `-key`, and
exposes a local administration interface on port 4040, which is what lets the
companion create and refresh a tunnel without the user editing a configuration
file.
UNVERIFIED: the stability, version compatibility, authorization model and
service level of that interface. It has to be confirmed against the provider
before the companion depends on it.
UNVERIFIED: provider prices. Different searches returned cpolar Base between
about 88 and about 99 CNY per year and a Pro tier near 149 CNY per year with
end-to-end HTTPS, and DDNSTO near 26 CNY per year. No figure here is a
commitment until a purchase page and a contract are confirmed.

Two ways to pay for reachability, both acceptable, and neither puts a recurring
cost on Wenshu for the general user: the user buys a provider account on
their own card, or an enterprise buys capacity for its own people. The
companion's job is to make the first path feel like one tap: sign in once on
the Mac, and the companion creates the tunnel, keeps it alive, and rotates
the URL when the provider rotates it.

### 3.3 Security baseline

- App-layer end-to-end encryption between phone and companion, always. The
  provider terminates TLS, so the provider is treated as untrusted for
  content. The pairing QR carries the companion's public key; the session key
  comes from a key agreement, and the payload is encrypted and authenticated
  with CryptoKit primitives that ship with the OS.
- VERIFIED: the provider's edge must not be the only thing standing between a
  manuscript and a stranger. This is the consequence of the measured
  `CN=tocmcc.cn` certificate on a plain HTTP local port.
- Loopback binding plus a device token plus origin checks on the companion.
- One device per token, revocable from the Mac, with a visible pairing record.
- The phone stores its token and its key material in the Keychain, never in
  preferences and never in a file inside the app container.
- No manuscript content in logs, crash reports, or analytics events.

### 3.4 The sync boundary

The Mac writes. The phone reads and commands. That single rule removes the
class of problem that dominates multi-writer designs.

- The API exposes a logical document model: chapters with ids, titles and
  revisions; references keyed by uuid; entities; tasks; agent sessions.
- The file tier stays authoritative for body text. `world/*.md` holds the
  writing, `references/<uuid>.md` holds the canonical reference, and
  `reference-library/**` is regenerated by the Mac rather than written twice.
- Every write carries `baseRevision`. A mismatch returns the current body
  alongside the rejected one, and the phone presents the conflict. No merge
  algorithm, because there is one writer and the loser is always the phone.
- The phone keeps a local draft of the text being edited until the companion
  acknowledges the write. A dropped connection loses nothing the user typed.
- The active book is resolved by `workspaceUI.sidebarSelection`, which carries
  the book. The alternative fields named in `WenshuLibrary` and `BookStore`
  do not hold it.

### 3.5 The native client

One app, three postures, one codebase.

- SwiftUI throughout. No AppKit view moves to the phone. The desktop editor's
  `NSTextView` dependency stays on the desktop.
- Deployment floor iOS 18, which is the iPhone 16 generation (ADR-0030). The foldable-native APIs arrive by `@available` on iOS 27.1, where `ArrangementView` gives the foldable-aware layout and `reservedRegions` reserves the areas a fold or a camera cutout can cover.
- The primary devices are the iPhone 18 family: the iPhone 18, the iPhone 18 Pro and the iPhone 18 Pro Max. A foldable is the same adaptive code, adapted to fit, not a second product line (ADR-0032).
- The shell is iOS's own (ADR-0033): a `TabView` with a bottom tab bar on the compact width, a `NavigationStack` inside each tab, and a `NavigationSplitView` only where the regular width earns it (an iPad, or a Duo unfolded into a wide screen). A phone never shows a sidebar. `containerRelativeFrame` sizes the panes against the container rather than a fixed number.
- Reading and short edits go through the API in the first release. A full
  rich-text editor on the phone is a later phase, because matching the
  desktop's editing behaviour in a native text view is a project of its own.
- QR pairing reads through VisionKit, which needs a camera usage description
  and a privacy manifest entry.
- The phone stores a read cache and the draft buffer in its own container, and
  nothing else.

---

## 4. Repositories and package boundary

Three repositories, and the reason for three is the SwiftPM constraint in
section 2.2.

| Repository | Contents | Consumed by |
| --- | --- | --- |
| `wenshu` (existing) | macOS app, `WenshuData`, `WenshuAgent` | the desktop user |
| `wenshu-core` (planned) | The shared library. Root package, library product, explicit version, platforms macOS and iOS. Holds the link contract once a second consumer needs it, and later the shared model. Created by card C2.1, not before. | `wenshu` and `wenshu-mobile` |
| `wenshu-mobile` (this repository) | The native client. An iOS and iPadOS app target. It holds the link contract until a second consumer needs it (ADR-0031), then it depends on `wenshu-core` at a pinned version. | the phone user |

Why not put the shared code in the `wenshu` root: the root package would have
to declare iOS support, and it contains a macOS-only executable target and two
local path packages. That makes the desktop package's platform declaration
lie about what it supports, and it puts a mobile-supporting manifest in front
of a repository whose own AGENTS.md section 2.3 declares the product
macOS-only. A dedicated root package removes that conflict and gives
`wenshu-mobile` exactly one dependency to pin.

What `wenshu-core` holds in the first release:

- The wire protocol: request and response shapes, the event envelope, the
  error model, and the version handshake.
- Shared value types with no SwiftData and no AppKit: identifiers, revision
  numbers, canonical paths expressed as identifiers rather than filesystem
  paths, and the capability flags.
- The pairing and session types.

What stays in `wenshu` for now, and what moves later:

- `WenshuData` stays where it is until its own manifest is widened on
  purpose, because that widening is what the iOS cross-compile proved is
  needed. When the phone needs the real model for its offline cache, the
  decision is either a move into `wenshu-core` or a parallel model in
  `wenshu-mobile` that mirrors the schema. The move is cleaner and costs one
  manifest edit plus a repository split.
- `WenshuAgent` stays in `wenshu` until the companion's service surface is
  stable enough to publish.

The macOS repository must consume `wenshu-core` by remote URL and a pinned
version too, so both sides resolve the same bytes. A local path dependency
between two repositories on one machine is a trap: it works until the two
checkouts drift apart.

---

## 5. Cost model

| Item | Amount | Paid by | Note |
| --- | --- | --- | --- |
| Relay or tunnel bandwidth, general user | The user's provider account, or 0 on the LAN path | The user | Wenshu's recurring relay cost is 0. |
| Provider account | Reported between about 26 and about 149 CNY per year across providers and tiers | The user | UNVERIFIED. Confirm the purchase page before quoting. |
| Apple Developer Program | Current-year fee, not confirmed here | Wenshu, as a company cost | Needed for any device, TestFlight, or App Store step. Not a relay cost. |
| Pilot subsidy | A number the owner sets | Wenshu, capped | Bounded user count, bounded term, expires, never auto-renews. |
| Enterprise | Per seat or per site | The enterprise | Their tunnel account or their server. |
| Engineering | Existing team time | Wenshu | Phase 1 and 2 need no new paid service. |

The rule that satisfies ruling 2: Wenshu never commits to a recurring relay
cost for a general user, and every free tier that Wenshu funds is capped in
users, in term, and in bytes, and expires on its own.

---

## 6. Phases and the cards that carry them

Tier per `docs/agents/ticket-tiers.md` (this repository). T3 means a new subsystem, a package
boundary, or a wide blast radius. Every card that writes code names a
reviewer in its `## REVIEW HANDOFF` section, per AGENTS.md rule 1.14.

### Phase 0, governance and the money decisions (T1 and T2)

| Card | Tier | Work | Gate |
| --- | --- | --- | --- |
| C0.1 | T1 | Record the four rulings: OOB.md one-line entry in both repos, AGENTS.md section 2.3 scope row amended in both repos, section 9 index entry, ADR-0028 in the desktop repo, ADR-0029 here. | `agents_gate.py --file AGENTS.md` exits 0. |
| C0.2 | T2 | Apple Developer Program enrollment, bundle identifiers for the three products, and the China filing decision. | Not a code card. Owner action, recorded as a decision. |
| C0.3 | T2 | Provider due diligence: which provider, which tier, price confirmed, local API contract confirmed, terms confirmed. | Written findings with no unverified claim left standing. |

### Phase 1, the Mac companion (T3)

| Card | Tier | Work |
| --- | --- | --- |
| C1.1 | T3 | The companion service skeleton inside the Wenshu app process: loopback listener, token authentication, `/v1/ping`, `/v1/pair`. |
| C1.2 | T3 | The document read model: library outline, chapter body, references, mapped onto the file tier and the store tier as section 2.4 describes. |
| C1.3 | T3 | The write path with `baseRevision` and the conflict payload, writing through the existing save path so there is one writer. |
| C1.4 | T3 | The event stream and the agent bridge over `WenshuConductor.handle`, with a stable published surface in `Public/`. |
| C1.5 | T2 | The client-side security checks: no unauthenticated diagnostics, no path in any response, revocation, audit of the token store. |

### Phase 2, the packages and the phone skeleton (T3)

| Card | Tier | Work |
| --- | --- | --- |
| C2.1 | T3 | Create `wenshu-core`: root package, library product, macOS and iOS 27.1 platforms, wire protocol and shared value types, version tag. |
| C2.2 | T2 | Prove remote consumption: a scratch consumer resolves `wenshu-core` by URL at a pinned version and builds for iOS Simulator. This is the proof of section 2.2. |
| C2.3 | T3 | The client app target: this repository, iOS 18 floor with the 27.1 APIs behind @available (ADR-0030), device family 1 and 2, no shared code beyond the kit (ADR-0031). |
| C2.4 | T2 | Widen `Sources/WenshuData` platforms to include iOS, and land the real iOS cross-compile that the scratch copy already proved. |
| C2.5 | T3 | The client shell: QR pairing with VisionKit, token storage in the Keychain, the library outline screen, the chapter reader. |
| C2.6 | T2 | Foldable and iPad layout: `ArrangementView`, `reservedRegions`, `NavigationSplitView` collapse on compact width. Needs an installed simulator runtime to be a real proof. |

### Phase 3, the tunnel (T3)

| Card | Tier | Work |
| --- | --- | --- |
| C3.1 | T3 | A tunnel provider adapter: the interface, the local administration client, tunnel lifecycle, URL rotation handling. |
| C3.2 | T3 | End-to-end encryption between phone and companion, key agreement at pairing, and the ciphertext-only payload. |
| C3.3 | T2 | The Mac side of pairing: the QR, the code, the device list, revocation, the visible pairing record. |
| C3.4 | T2 | The LAN path, which needs no account at all and is the first-run default. |

### Phase 4, write-back and conflict (T3)

| Card | Tier | Work |
| --- | --- | --- |
| C4.1 | T3 | The phone editor over the API, the local draft buffer, and the retry on a dropped connection. |
| C4.2 | T2 | The conflict presentation and the manual resolution path. |
| C4.3 | T2 | Reference editing through the canonical copy only, with the Mac regenerating the mirror. |

### Phase 5, offline, optional and separately priced (T3)

| Card | Tier | Work |
| --- | --- | --- |
| C5.1 | T3 | The read cache and offline reading. |
| C5.2 | T3 | Offline drafts and the conflict merge on reconnect. |

### Phase 6, store and filing (T3)

| Card | Tier | Work |
| --- | --- | --- |
| C6.1 | T3 | The privacy manifest, the camera usage description, the account and deletion story. |
| C6.2 | T3 | The China mainland filing package and the Apple compliance information, once the account and the legal answers exist. |
| C6.3 | T3 | TestFlight, the review submission, and the rollback plan. |

---

## 7. Risks, and what each one costs if it lands late

| Risk | Evidence | Response |
| --- | --- | --- |
| No signing identity blocks every device and store step | VERIFIED | Owner decision in Phase 0, card C0.2. Until then the work stops at a generic simulator build. |
| A shared package cannot be consumed remotely from a subdirectory | VERIFIED | `wenshu-core` as its own root package, card C2.1, proven by card C2.2. |
| The tunnel provider reads manuscript plaintext | VERIFIED | App-layer end-to-end encryption, card C3.2, before the first remote write. |
| A diagnostic route leaks paths and identifiers | VERIFIED | Companion security checks, card C1.5. |
| Two stores and two copies of the same reference | VERIFIED | The Mac is the only writer and regenerates the mirror, cards C1.3 and C4.3. |
| Provider administration interface changes without notice | UNVERIFIED | One adapter, card C3.1, plus a second provider behind the same interface. |
| The China filing path is unknown | UNVERIFIED | Legal answer in card C0.2, before Phase 6. |
| No simulator runtime means no device proof | VERIFIED | Install the runtime in Phase 2, or accept simulator-free proof until then. |
| The desktop editor cannot be reused on the phone | VERIFIED | The phone gets its own editor, scoped to Phase 4, and the desktop keeps AppKit. |
| 26 live worktrees collide with in-flight branches | VERIFIED | Every code card runs in its own worktree, per AGENTS.md rule 1.12. |

---

## 8. What the review has to decide

1. **Account.** Is the Apple Developer Program enrolled, and under which
   entity? Without it, the plan is deliverable only as simulator builds.
2. **Repositories.** Are three repositories acceptable, or must the shared
   package live inside the `wenshu` root, which costs the desktop manifest its
   macOS-only declaration?
3. **Reachability.** Which provider and which tier, and does the first release
   support the LAN path only, or the LAN path plus one paid provider?
4. **Money.** The pilot subsidy cap: how many users, for how long, with what
   byte limit.
5. **Scope of the first release.** Does the phone ship with reading and short
   edits only, with the rich editor deferred to Phase 4, or does the first
   release carry the editor?
6. **Filing.** Who owns the China filing answer, and does the plan wait for it
   or proceed in parallel.

---

## 9. What is deliberately not in this plan

- No cloud service of Wenshu's own. That is a recurring cost and a
  data-residency obligation, and ruling 2 rules it out.
- No multi-writer merge engine. Ruling 4 makes it unnecessary, and it is the
  most expensive thing on the list to get right.
- No ported desktop views. The desktop editor is AppKit and stays there.
- No claim about provider price, service level, or China filing timing. Those
  three are the open items in section 8.
- No offline capability in the first release. It is Phase 5, priced
  separately.
