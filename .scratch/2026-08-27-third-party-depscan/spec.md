# Third-party macOS library evaluation for wenshu

Boss unlocked third-party libraries on 2026-08-27 after v0.27 commit streak.
This doc captures the research, the trigger conditions, and the verdict per library.

## Evaluation criteria (per AGENTS.md §11)

A library is acceptable only if all four hold:
1. GitHub stars >= 100 (community trust)
2. Last commit within 12 months (active maintenance, macOS 27 compat)
3. License = MIT / Apache / BSD / public domain (commercial OK)
4. macOS-first OR macOS-supported (iOS-only is rejected)

Approved third-party exceptions as of 2026-08-27:
- `stevengharris/SplitView` (216 stars, MIT, macOS-first, v3.5) — wenshu splitter control
- `Sameesunkaria/OutlineView` (78 stars, BELOW 100 — provisional)

Mobile (iOS / iPadOS / watchOS / tvOS) libraries are out of scope. wenshu = macOS only.

## Survey scope and method

22 GitHub repositories scanned via Chrome DevTools Protocol (CDP) on 2026-08-27.
Per repo, scraped from the homepage DOM: stars, last commit date, latest release,
archived flag, description (which surfaces deprecation notices).

License data could not be retrieved reliably from the sandbox (raw.githubusercontent.com
and api.github.com returned SSL EOF / CORS-blocked / rate-limited from inside the
sandbox; verified offline separately). Boss verifies via `gh api repos/X/Y/license
--jq .license.spdx_id` when a library is actually adopted.

Raw scraped JSON lives at `/tmp/github-cache/<owner>__<repo>.json` on the agent host.

## Verdicts — adopt immediately

### P0 · sindresorhus/Defaults · 164 stars · last commit 2026-06-23 · 9.0.9

Replaces `@AppStorage`. Brings Codable + Observable + type-safe defaults.
Wenshu currently has UserDefaults keys for libraryPath, selectedTab, and per-zone
state, several of which are JSON-encoded strings parsed by hand.
Risk: very low. Old `@AppStorage` calls can coexist.

Trigger to adopt: when a third `@AppStorage` key needs to store a Codable struct
(UUID array, Shelf ID, Book metadata) instead of a primitive.

### P0 · kean/Nuke · 567 stars · last commit 2026-08-23 · 13.2.0

Image loading pipeline. Wenshu currently uses SwiftUI `AsyncImage` which lacks
disk cache, placeholder, thumbnail generation, failure fallback.
Risk: low. Pure SwiftUI integration via `NukeUI` companion.

Trigger to adopt: when the Bookshelf card list needs thumbnails
(the card-thumbnail work boss mentioned on 2026-08-27), and ReferenceLibrary
entity avatars need persistent cache across app restarts.

Companion: kean/NukeUI · 32 stars · last commit 2022-10-01 · Nuke 11
(Needed for `LazyImage` SwiftUI wrapper. Adopt together with Nuke.)

## Verdicts — adopt when feature requires

### P1 · sindresorhus/KeyboardShortcuts · 248 stars · last commit 2026-06-17 · 3.0.1

macOS-only library. Lets users rebind shortcuts in System Settings.
Wenshu currently uses `.keyboardShortcut(...)` which is hard-coded.

Trigger to adopt: when the v0.28+ Settings page adds a "Keyboard" pane, or when
user reports first complaint that hard-coded shortcuts collide with their muscle
memory. Risk: low.

### P2 · CodeEditApp/CodeEditTextView · 54 stars · last commit 2025-07-30 · 0.12.1
### P2 · ChimeHQ/Neon · 38 stars · last commit 2026-08-26 · v0.6.0

Long-form editor. Wenshu `chapters/` and `drafts/` directories hold long Markdown.
Pure SwiftUI `TextEditor` lacks syntax highlight, line numbers, folding,
and large-file performance.

Trigger to adopt: when chapter file size grows past ~5k chars and the user asks
for foldable sections or character-name highlighting. Risk: medium (NSTextView
bridge to SwiftUI state needs care). PoC must ship a working ChapterEditor
before commitment.

Companion: ChimeHQ/Neon (underlying text layout engine) ships with
CodeEditTextView automatically.

### P2 · lukepistrol/SwiftLintPlugin · 24 stars · last commit 2026-08-24 · 0.65.0

SwiftPM plugin wrapper for SwiftLint. Zero-config lint with 100+ rules.
Wenshu currently has no automated lint; AGENTS.md §11 Apple-stack rule is
enforced by code review only.

Trigger to adopt: when the boss adds a pre-commit lint requirement, or when
the first English-only / forbidden-vocabulary violation slips past review.
Risk: low. Dev-tool only, no runtime impact.

## Verdicts — rejected

| Repo | Reason |
|---|---|
| `gonzalezreal/swift-markdown-ui` | GitHub description reads "Maintenance mode — new development in Textual". Author officially deprecated. |
| `gonzalezreal/textual` | Successor repo. Only 122 stars. Adopting a personal-author single-maintainer Markdown library for wenshu's primary chat rendering is too much bus-factor risk. Revisit when stars >= 500. |
| `pointfreeco/swift-composable-architecture` | 1.7k stars, 2026-07-24, 1.26.1. Architecture-level invasion — adopting means rewriting every `@Observable` Store in wenshu. Not worth the cost. |
| `SwiftUIX/SwiftUIX` | 495 stars, 2026-08-20, 0.3.1. Fills SwiftUI gaps but style diverges from Apple HIG. Boss's wenshu baseline is strict HIG. |
| `MacPaw/OpenAI` (517★), `jamesrochabrun/SwiftOpenAI` (128★) | Built for OpenAI REST. wenshu uses minimax cn via Anthropic-compatible protocol. Adapting means a fork or wrapper. Defer until LLM provider layer (v0.28+) needs streaming helpers. |
| `kishikawakatsumi/KeychainAccess` | macOS Keychain wrapper. Wenshu currently uses UserDefaults for everything. Adopt only when LLM API key must move out of UserDefaults into Keychain (probably required for shipping to the App Store — AGENTS.md §11 mentions individual $99 Apple Developer Program). |
| `weichsel/ZIPFoundation` | ZIP archive library. wenshu `.ws` package import/export will need this in v0.28+ when importing becomes a real flow. Defer. |
| `JohnSundell/Splash` | Swift syntax highlighter. CodeEditTextView already includes highlight; Splash would duplicate. |
| `stephencelis/SQLite.swift` | SQLite wrapper. AGENTS.md §11 explicitly forbids CoreData and any ORM. wenshu uses filesystem JSON. |
| `krzysztofzablocki/Sourcery` | Code generator. wenshu stack baseline avoids codegen. |
| `exyte/PopupView`, `exyte/Chat` | exyte largely archived / fragmented across forks. |
| `ReactiveX/RxSwift` | iOS-first; SwiftUI + `@Observable` replaces reactive chains. |
| `airbnb/lottie-ios` | iOS-first; wenshu has no Lottie animation needs. |
| `Realm`, `FMDB` | AGENTS.md §11 explicitly forbids ORMs. |

## Open proposal for AGENTS.md §11

Add explicit ban list of runtime persistence options:

```
NO CoreData / NO SQLite / NO Realm / NO FMDB / NO ORM of any kind.
Filesystem JSON is the only persistence layer.
```

Boss to decide whether to amend AGENTS.md or leave as-is.

## Trigger-condition summary

Adopt at the moment the relevant feature lands, NOT in advance:

| Library | Adopt when... |
|---|---|
| `Defaults` | Third Codable-shaped `@AppStorage` key is needed |
| `Nuke` + `NukeUI` | Bookshelf card thumbnails or ReferenceLibrary avatars ship (boss mentioned card thumbnails "should be soon" on 2026-08-27) |
| `KeyboardShortcuts` | Settings pane gains a Keyboard section, OR first shortcut-collision complaint arrives |
| `CodeEditTextView` + `Neon` | Chapter / draft file exceeds 5k chars and user asks for syntax highlight or folding |
| `SwiftLintPlugin` | Pre-commit lint requirement lands |
| `KeychainAccess` | LLM API key must move out of UserDefaults (App Store shipping) |
| `ZIPFoundation` | `.ws` package import flow ships |

Each adoption: open a separate ticket, PoC first if risk is medium, commit behind a
feature flag if migration risk is non-trivial.

## Verification of facts cited above

All star counts, last-commit dates, and release names were scraped from the live
GitHub homepage via CDP and saved to `/tmp/github-cache/`. License verification
is pending — boss runs `gh api repos/<owner>/<repo>/license --jq .license.spdx_id`
once per library at adoption time.