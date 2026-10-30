# Wenshu Mobile

The native Apple client of the Wenshu product line: one SwiftUI codebase
for iPhone, iPad and foldable, driving the Mac app that owns the library.

This repo is a sibling of the macOS app (wenshu), not a folder inside it.
The reason is in ADR-0029: the desktop app is macOS-only and its editor is
built on AppKit, so the two products share a protocol and a governance
method, not a codebase.

## What is here

| Path | What it is |
| ---- | ---------- |
| AGENTS.md | The SSOT: 10 sections of hard rules, gates, and the workflow. |
| docs/product-line-plan.md | The product line and architecture plan (= the decisions, the phases, the cost model). |
| docs/adr/ | The decision records. |
| docs/agents/ | The governance documents: the NFI registry, the tiers, the parallel-dev contract, the glossary. |
| Sources/WenshuMobileApp/ | The app target: App/ + Features/<Name>/ + Shared/. |
| Sources/WenshuMobileKit/ | The kit: the versioned link contract both sides speak. |
| Tests/WenshuMobileTests/ | The test target. |
| Tools/wenshu-devtool/ | The gates that decide whether a change may land. |
| OOB.md | The index of boss directives. |

## Build

```bash
Scripts/setup-dev-env.sh     # once per machine
swift build                  # the package
swift test                   # the tests
```

The product target is iOS and iPadOS, so the build that proves the
product compiles is the simulator build:

```bash
xcodebuild -scheme WenshuMobile-Package \
  -destination 'generic/platform=iOS Simulator' build
```

## Work on a card

A card that writes `Sources/**` or `Tests/**` runs in its own git
worktree, created on the board wenshu-mob-par and bound to the project
project-2. Read docs/agents/parallel-development.md for the whole flow.

```bash
cd /Volumes/ANAN/Engineering/wenshu-mobile
python3 Tools/wenshu-devtool/ticket_tier.py --body card.md
hermes kanban create "[<tier>] <title>" \
  --assignee wenshu-dev --workspace worktree --project project-2 \
  --body-file card.md --max-runtime <cap> --max-retries <budget>
```

## The one rule

The Mac is the writer. The device reads a projection, keeps a draft, and
sends commands. It never writes the library itself.
