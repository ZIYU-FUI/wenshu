# Issue 001 — Adopt swift-markdown-engine as wenshu chapter editor (tracer-bullet ticket)

- Date: 2026-09-04
- Spec: `.scratch/2026-09-04-editor-migration/spec.md`
- Worktree: `.worktrees/editor-001-adopt-engine` (branch `wt/editor-001`)
- Source: `https://github.com/nodes-app/swift-markdown-engine` v0.12.0 (verified 2026-09-04 via `curl https://api.github.com/repos/nodes-app/swift-markdown-engine`)
- Methodology: PO step 4 (implement) of `wenshu/.scratch/2026-08-19-frontend-integration/35-skills-methodology.md` 6-step chain
- Boss拍 2026-09-04: '好, 加 PO 全链路方法论, 跑接入' (= full plan approval; agent auto-pilot per Q182)

## 1. Scope (1 ticket = 1 commit per boss cadence)

Replace `Apple SwiftUI TextEditor` in `EditorEditContent.body` (WorkspaceView.swift L1539-1573) with `swift-markdown-engine` via a wenshu-side wrapper (`WenshuMarkdownEditor`) that wires 2 of 4 service protocols from `MarkdownEditorServices` (= WikiLinkResolver + EmbeddedImageProvider; the other 2 use prebuilt bridges).

## 2. Pre-conditions

- [ ] Worktree `.worktrees/editor-001-adopt-engine` exists (= created in this session).
- [ ] Branch `wt/editor-001` checked out from `main` HEAD (faa5edc0e).
- [ ] `swift --version` returns Swift 6.x; `swift build` succeeds on `main` (verify before starting).
- [ ] `swift-markdown-engine` v0.12.0 reachable via SPM (verify with `swift package resolve --dry-run` after editing Package.swift).

## 3. Implementation steps (single commit)

### 3.1 Edit `Package.swift`

In the `dependencies` array (alphabetized position after `smittytone/HighlighterSwift`):

```swift
// RUNTIME -- Markdown editor engine (boss 2026-09-04 ticket 001)
// Adopts nodes-app/swift-markdown-engine as the wenshu chapter
// editor (= replaces Apple SwiftUI TextEditor in EditorEditContent).
// Verified: 971 stars, Apache-2.0, 3 contributors (Munich+Zurich
// team), 0.12.0 latest 2026-08-10 (= 24 days ago), half-year 5 minor
// releases. Passes AGENTS.md §11.1 third-party 4-criteria gate:
// (a) 100+ stars: 971 PASS
// (b) 12-month active: latest release 2026-08-10 PASS
// (c) License: Apache-2.0 (= §11.1 acceptable; MIT/Apache/BSD)
// (d) macOS-first: macOS-only engine (iOS port is independent future)
// Pre-1.0: pin minor = "0.12.0" per upstream README recommendation.
// Wenshu-side wins pattern (AGENTS.md §11.3): engine provides 4 service
// protocols with no-op defaults; wenshu implements 2 (WikiLinkResolver
// for reference-library cross-refs + EmbeddedImageProvider for
// ![[name]] embeds). HighlighterSwiftBridge is transitive via the
// MarkdownEngineCodeBlocks product (= already in wenshu Package.swift
// as direct dep for v0.28 chapter-preview wiring). MarkdownEngineLatex
// product = NOT adopted in 001 (= opt-in future ticket if needed).
.package(url: "https://github.com/nodes-app/swift-markdown-engine", from: "0.12.0"),
```

In the `WenshuApp` target's `dependencies` array (alphabetized):

```swift
.product(name: "MarkdownEngineCodeBlocks", package: "swift-markdown-engine"),
```

### 3.2 New file `Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift`

```swift
// v0.39 ticket 001 -- wenshu-side wrapper for swift-markdown-engine
// (= wenshu-side wins pattern per AGENTS.md §11.3: library provides
// the SwiftUI bridge, wenshu wires the data layer). NSViewRepresentable
// around engine's NativeTextViewWrapper; passes binding + document id
// + MarkdownEditorConfiguration (services live inside configuration).
// Engine handles TextKit 2 layout, live styling, undo, find,
// accessibility, IME. Wenshu handles the reference-library lookups
// (wiki-link resolution + image embeds).
//
// Real API (verified 2026-09-04 from swift-markdown-engine 0.12.0 source):
//   NativeTextViewWrapper.init(
//     text: Binding<String>,
//     isWikiLinkActive: Binding<Bool> = .constant(false),
//     pendingInlineReplacement: Binding<InlineReplacementRequest?> = .constant(nil),
//     configuration: MarkdownEditorConfiguration = .default,
//     fontName: String = "SF Pro",
//     fontSize: CGFloat = 16,
//     documentId: String = "default",
//     ...
//   )
// Services are NOT a separate init parameter; they live inside
// MarkdownEditorConfiguration.services.

import SwiftUI
import MarkdownEngine

struct WenshuMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let draftId: String  // stable per tab (= engine requires it for undo scoping)
    let configuration: MarkdownEditorConfiguration

    func makeNSView(context: Context) -> NSView {
        NativeTextViewWrapper(
            text: $text,
            configuration: configuration,
            documentId: draftId
        )
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Engine handles its own diff/observation; no manual push needed.
        // updateNSView kept for SwiftUI lifecycle conformance (= the
        // standard NSViewRepresentable contract).
    }
}
```

### 3.3 New file `Sources/WenshuApp/Editor/ReferenceLibraryWikiLinkResolver.swift`

```swift
// v0.39 ticket 001 -- WikiLinkResolver conformance that searches
// wenshu's reference-library 4-layer structure for entities matching
// the wiki-link display name. Engine calls this synchronously from
// the styler; wenshu does a single-pass filesystem read (= ~1ms for
// libraries with < 10k entities).
//
// Real API (verified 2026-09-04 from swift-markdown-engine 0.12.0 source):
//   protocol WikiLinkResolver: Sendable {
//     func resolve(displayName: String, range: NSRange) -> WikiLinkResolution?
//     func name(forID id: String) -> String?
//     func fingerprint() -> AnyHashable
//   }
//   struct WikiLinkResolution: Sendable, Equatable {
//     let id: String      // NON-optional
//     let exists: Bool
//   }
// `name(forID:)` and `fingerprint()` have default implementations on
// the protocol (= we override fingerprint() so a rename refreshes link
// display; name(forID:) default returns nil = renderer falls back to
// the stored label).

import Foundation
import CryptoKit  // for fingerprint hash
import MarkdownEngine

struct ReferenceLibraryWikiLinkResolver: WikiLinkResolver {
    let referenceLibraryRoot: URL  // = library's reference-library/

    func resolve(displayName: String, range: NSRange) -> WikiLinkResolution? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Search entities/ for matching name field (= case-insensitive).
        // Engine guarantees synchronous call (per MarkdownEditorServices
        // doc comment); wenshu resolution is filesystem read = ~1ms.
        let entitiesDir = referenceLibraryRoot.appendingPathComponent("entities")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: entitiesDir, includingPropertiesForKeys: nil
        ) else {
            return WikiLinkResolution(id: "", exists: false)
        }
        for entry in entries where entry.pathExtension == "json" {
            guard let data = try? Data(contentsOf: entry),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = json["name"] as? String,
                  name.caseInsensitiveCompare(trimmed) == .orderedSame,
                  let id = json["id"] as? String else { continue }
            return WikiLinkResolution(id: id, exists: true)
        }
        // Miss: engine stores link as `[[Name]]` (no id) when resolution
        // returns id="" — equals: no id needed because target doesn't
        // exist (= link displays in gray dashed style per engine default).
        return WikiLinkResolution(id: "", exists: false)
    }

    func name(forID id: String) -> String? {
        // Reverse lookup: id -> name. Engine uses this for `[[Name|<id>]]`
        // storage form to render the latest name when the entity has been
        // renamed since the link was written.
        let entitiesDir = referenceLibraryRoot.appendingPathComponent("entities")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: entitiesDir, includingPropertiesForKeys: nil
        ) else { return nil }
        for entry in entries where entry.pathExtension == "json" {
            guard let data = try? Data(contentsOf: entry),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entryID = json["id"] as? String,
                  entryID == id,
                  let name = json["name"] as? String else { continue }
            return name
        }
        return nil
    }

    func fingerprint() -> AnyHashable {
        // Hash of (id + name) for every known entity. Renaming an entity
        // changes the hash = engine restyles wiki-links without waiting
        // for the next keystroke.
        let entitiesDir = referenceLibraryRoot.appendingPathComponent("entities")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: entitiesDir, includingPropertiesForKeys: nil
        ) else { return Data() }
        var hasher = SHA256()
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where entry.pathExtension == "json" {
            if let data = try? Data(contentsOf: entry) { hasher.update(data: data) }
        }
        return Data(hasher.finalize())
    }
}
```

### 3.4 New file `Sources/WenshuApp/Editor/ReferenceLibraryImageProvider.swift`

```swift
// v0.39 ticket 001 -- EmbeddedImageProvider conformance that resolves
// Obsidian-style ![[name]] embeds by searching the active book's
// characters/ + worlds/ folders first, then the library's reference-
// library/raw/ as fallback. Engine calls synchronously from the
// image-embed render path.
//
// Real API (verified 2026-09-04 from swift-markdown-engine 0.12.0 source):
//   protocol EmbeddedImageProvider: Sendable {
//     func image(for reference: EmbeddedImageRequest) -> NSImage?
//     func fingerprint() -> AnyHashable
//   }
//   struct EmbeddedImageRequest: Sendable, Equatable {
//     let name: String                   // = part before any |
//     let id: String?                    // = optional explicit id
//     let requestedWidth: CGFloat?       // = optional explicit width
//   }
// The engine parses `![[name|optional-id|optional-width]]` into an
// EmbeddedImageRequest and asks the provider for an image.

import AppKit
import CryptoKit
import MarkdownEngine

struct ReferenceLibraryImageProvider: EmbeddedImageProvider {
    let activeBookRoot: URL           // = shelves/<shelf>/books/<book>/
    let referenceLibraryRoot: URL     // = library's reference-library/

    func image(for reference: EmbeddedImageRequest) -> NSImage? {
        // Search order: characters/, worlds/, reference-library/raw/.
        // If explicit id is provided, match by id (= entity UUID stored
        // in entity metadata). Otherwise match by file basename.
        let candidates: [URL] = [
            activeBookRoot.appendingPathComponent("characters"),
            activeBookRoot.appendingPathComponent("worlds"),
            referenceLibraryRoot.appendingPathComponent("raw"),
        ]
        let trimmed = reference.name.trimmingCharacters(in: .whitespacesAndNewlines)

        for dir in candidates {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            ) else { continue }
            for entry in entries {
                let baseName = entry.deletingPathExtension().lastPathComponent
                let matchByName = baseName.caseInsensitiveCompare(trimmed) == .orderedSame
                let matchById: Bool = {
                    guard let id = reference.id else { return false }
                    return baseName.caseInsensitiveCompare(id) == .orderedSame
                }()
                if matchByName || matchById {
                    return NSImage(contentsOf: entry)
                }
            }
        }
        return nil
    }

    func fingerprint() -> AnyHashable {
        // Hash of all image file mtimes + paths. Engine invalidates its
        // image cache when this changes (= new image added, or existing
        // one edited).
        let candidates: [URL] = [
            activeBookRoot.appendingPathComponent("characters"),
            activeBookRoot.appendingPathComponent("worlds"),
            referenceLibraryRoot.appendingPathComponent("raw"),
        ]
        var hasher = SHA256()
        for dir in candidates {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                hasher.update(data: Data(entry.lastPathComponent.utf8))
                if let mtime = try? entry.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate {
                    hasher.update(data: Data(String(mtime.timeIntervalSince1970).utf8))
                }
            }
        }
        return Data(hasher.finalize())
    }
}
```

### 3.5 New file `Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift`

```swift
// v0.39 ticket 001 -- factory that builds MarkdownEditorConfiguration
// (= wraps MarkdownEditorServices) from current AppState + BookStore +
// WenshuLibrary. One configuration instance per edit session (= bound
// to active tab's chapter). HighlighterSwiftBridge is transitive via
// MarkdownEngineCodeBlocks product; SwiftMathBridge is NOT wired
// (= LaTeX is opt-in future).
//
// Real API (verified 2026-09-04 from swift-markdown-engine 0.12.0 source):
//   MarkdownEditorServices.init(
//     wikiLinks: any WikiLinkResolver = NoOpWikiLinkResolver(),
//     images: any EmbeddedImageProvider = NoOpEmbeddedImageProvider(),
//     syntaxHighlighter: any SyntaxHighlighter = PlainTextSyntaxHighlighter(),
//     latex: any LatexRenderer = NoOpLatexRenderer(),
//     bus: MarkdownEditorBus = .default
//   )
//   MarkdownEditorConfiguration.init(
//     theme: ...,
//     services: MarkdownEditorServices = .default,
//     ...
//   )

import Foundation
import MarkdownEngine
import MarkdownEngineCodeBlocks

enum WenshuEditorServicesFactory {
    static func make(
        referenceLibraryRoot: URL,
        activeBookRoot: URL?
    ) -> MarkdownEditorConfiguration {
        let services = MarkdownEditorServices(
            wikiLinks: ReferenceLibraryWikiLinkResolver(referenceLibraryRoot: referenceLibraryRoot),
            images: activeBookRoot.map { ReferenceLibraryImageProvider(
                activeBookRoot: $0,
                referenceLibraryRoot: referenceLibraryRoot
            ) } ?? NoOpEmbeddedImageProvider(),
            syntaxHighlighter: HighlighterSwiftBridge()
            // latex: omit (= NoOpLatexRenderer default)
            // bus: omit (= .default)
        )
        var config = MarkdownEditorConfiguration.default
        config.services = services
        return config
    }
}
```

### 3.6 Edit `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`

In `EditorEditContent.body` (L1539-1573 area), swap:

```swift
// before (v0.34 B-25):
TextEditor(text: $draft)
    .font(.body)

// after (v0.39 ticket 001):
WenshuMarkdownEditor(
    text: $draft,
    draftId: tab.id.uuidString,
    configuration: WenshuEditorServicesFactory.make(
        referenceLibraryRoot: appState.library.referenceLibraryRoot,
        activeBookRoot: appState.activeBookRoot
    )
)
.frame(minHeight: 200)
```

Note: exact property names (`appState.library.referenceLibraryRoot`, `appState.activeBookRoot`) to be confirmed against current AppState surface during implementation. If names differ, adapt to existing canonical names (per Q180 git grep before patch).

### 3.7 New file `Tests/WenshuAppTests/Editor/WenshuMarkdownEditorAdapterTests.swift`

```swift
// v0.39 ticket 001 -- 5 tests covering the 2 service protocol
// implementations + the editor view mount. Per Q182.4: @MainActor on
// any test func touching AppState.

import XCTest
import SwiftUI
@testable import WenshuApp

@MainActor
final class WenshuMarkdownEditorAdapterTests: XCTestCase {
    // ... 5 tests per spec §3.8
}
```

Tests covered:
- `testWikiLinkResolver_hit`
- `testWikiLinkResolver_miss`
- `testImageProvider_hit_characterPortrait`
- `testImageProvider_miss`
- `testWenshuMarkdownEditor_mounts` (uses ViewInspector per Q182.4)

## 4. Verification (PO step 5)

### 4.1 Build verification (Z = contract)

```bash
cd .worktrees/editor-001-adopt-engine
swift build 2>&1 | head -50
# Expected: zero warning, zero error
```

### 4.2 Test verification (Z = contract)

```bash
swift test --filter WenshuMarkdownEditorAdapterTests 2>&1 | tail -30
# Expected: 5 tests, all pass
```

### 4.3 End-to-end X-test (single track per Q180; not dual-track for 001)

Documented in §5.3 = manual verification on `swift run WenshuApp`:
1. Open wenshu app, navigate to any chapter
2. Type `# Hello World` — verify heading style applied (large + bold)
3. Type `**bold text**` — verify bold style applied inline
4. With `Anna` entity in reference-library: type `[[Anna]]` — verify blue underlined link
5. Type `[[GhostEntity]]` (no entity) — verify gray dashed link
6. Type ```` ```swift ```` + `print("hi")` — verify code-block background + syntax highlight

## 5. Commit pattern

Per boss cadence (1 RULE 1 commit) + Q146 (to-tickets blocking-edge):

- Single commit = whole ticket 001 (file additions + 1 edit + tests)
- Commit message:
  ```
  feat(wenshu): v0.39 ticket 001 -- adopt swift-markdown-engine as chapter editor
  
  - Package.swift: +swift-markdown-engine 0.12.0 (= MarkdownEngineCodeBlocks product, transitive HighlighterSwiftBridge)
  - Sources/WenshuApp/Editor/: +4 files (WenshuMarkdownEditor + 2 service adapters + factory)
  - Sources/WenshuApp/Views/Workspace/WorkspaceView.swift: EditorEditContent.body TextEditor -> WenshuMarkdownEditor
  - Tests/WenshuAppTests/Editor/: +5 tests (wiki-link hit/miss, image hit/miss, editor mount)
  
  Apache-2.0 license; wenshu-side wins pattern per AGENTS.md §11.3 (= engine
  provides 4 protocols, wenshu implements 2: WikiLinkResolver + EmbeddedImageProvider).
  Pre-1.0 pin minor "0.12.0" per upstream README recommendation. Zero file
  overlap with hermes-core-translation (wt/multi-agent-dispatch) = no merge
  conflict. iOS/iPad future port remains independent per boss 2026-09-04 OOB.
  ```

## 6. Definition of Done (= ticket close criteria)

- [ ] All 5 new files exist with the exact content per §3.2-3.5 + 3.7
- [ ] Package.swift has both edits per §3.1
- [ ] WorkspaceView.swift has the swap per §3.6 (1-line change, no other edits)
- [ ] `swift build` succeeds with zero warning
- [ ] `swift test --filter WenshuMarkdownEditorAdapterTests` = 5/5 pass
- [ ] Manual X-test (4.3) succeeds on the running wenshu app
- [ ] Commit message follows §5 template
- [ ] No file outside the 5 + 2 listed is touched

## 7. After completion (= PO step 6)

PO step 6 = domain-modeling. Per boss 2026-09-04 cadence, this is a small one-ticket change; domain-modeling update = optional (no new domain words beyond what spec already captures: "WikiLinkResolver", "EmbeddedImageProvider", "MarkdownEditorServices" — all derived from upstream README, no wenshu-specific terminology invented).

If after 001 ships the boss拍 "ship it" or accepts the 一次性 visual verify, agent reports and awaits further boss direction (002 / 003 / etc. or move to next wenshu priority).

## 8. Cross-references

- Spec: `.scratch/2026-09-04-editor-migration/spec.md` (§5 = ticket 001 acceptance)
- PO methodology: `.scratch/2026-08-19-frontend-integration/35-skills-methodology.md`
- Auto-pilot stance: `.hermes/profiles/pocock/skills/wenshu-pocock-workflow/references/2026-09-03-pocock-po-push-authority-and-test-cleanup.md` (Q182)
- Test cleanup patterns: same reference (Q182.4)
- Parallel spec: `.scratch/2026-09-03-hermes-core-translation/spec.md` (different file scope, no conflict)

*Issue 001 written 2026-09-04 by wenshu auto-pilot (= pocock single-agent) per boss OOB "好, 加 PO 全链路方法论, 跑接入".*
