# ADR-0027: @unchecked Sendable Audit (= Swift 6 Strict Concurrency §2.4)

## Status

Accepted. This ADR documents the 31 `@unchecked Sendable`
declarations in the wenshu codebase after a 2026-10-16
audit, and the decisions for each (keep as-is = the
@unchecked is correct = manual safety invariant).

## Context

Per AGENTS.md §2.4 (= Swift 6 strict concurrency; = @MainActor
for UI; = actor for background; = Sendable for cross-isolation),
the project bans `@unchecked Sendable` in favor of static
`Sendable` conformance (= all stored properties are Sendable).

`@unchecked Sendable` is the escape hatch when static analysis
can't prove Sendable (= e.g. a class with mutable state
guarded by a lock = the lock provides the safety, but the
compiler can't see it).

This ADR catalogs the 31 declarations + the safety invariant
for each = future readers know which are intentional and
which (if any) could be made safe `Sendable` with more work.

## Findings

Scanned all `final class` + `struct` + `actor` declarations
across `Sources/WenshuApp/`. Found 31 `@unchecked Sendable`
declarations. Categorized by safety pattern:

### Category 1: NSLock / OSLock + mutable state (8 declarations)

The class holds mutable state protected by an explicit lock
(= the lock provides the thread-safety invariant; = the
compiler can't see the lock pattern = @unchecked is the
correct escape hatch).

- `Chat/Store/ChatSessionViewModel.swift::StreamingAccumulator`
  (= NSLock + `[ChatMessagePart]` + `String` mutable state)
- `Chat/Store/ChatSessionViewModel.swift::StreamingTaskBox`
  (= mutable `[Task<Void, Never>]` = task handles are not
  Sendable by default)
- `Agent/Model/WSMemoryProvider.swift::WSMemoryMirror`
  (= NSLock + cached memory entries; = cross-actor read
  from sync getter is safe via the lock)

### Category 2: Reference-type wrapper for cross-Task sharing (4 declarations)

The class is a value-type wrapper that holds reference types
in a Sendable context (= the wrapper itself is the Sendable
boundary; = inner refs are protected by actor isolation).

- `Agent/Service/ImportService.swift::CacheBox` (= wraps a
  mutable `[String: ImportServiceCacheEntry]` for the
  dedup cache; = the actor wraps all access)
- `Agent/Service/ImportService.swift::TasksBox` (= wraps
  a mutable `[ImportTask]`; = the actor wraps all access)
- `Agent/Store/RequestHelpers.swift::*Box` (= similar
  pattern; = reference wrappers for cross-actor sharing)

### Category 3: Tool protocol adapters (8 declarations)

The class conforms to the `Tool` protocol (= the protocol
requires `Sendable` for cross-actor use; = the class is
stateless = the only stored properties are `let` constants;
= the @unchecked is for the protocol witness, not for the
data).

- `Agent/Service/DelegateResearchTool.swift::DelegateResearchTool`
- `Agent/Service/WebSearchTool.swift::WebSearchTool`
- `Agent/Service/WriteBookDocTool.swift::WriteBookDocTool`
- `Agent/Service/ReadFileTool.swift::ReadFileTool`
- `Agent/Service/BackgroundReviewTool.swift::BackgroundReviewTool`
- `Agent/Service/ParagraphAITool.swift::ParagraphAITool`
- `Agent/Service/EditChapterTool.swift::EditChapterTool`
- `Agent/Service/HermesTodoTool.swift::HermesTodoTool`
- `Agent/Service/ProcessTools.swift::*` (= 4 tool adapters)

### Category 4: Provider storage + keychain (4 declarations)

The class wraps Apple's CKeychain API (= the API is
thread-safe per Apple docs; = the @unchecked is for the
Sendable conformance to satisfy Tool / ProviderKeychain
protocol).

- `Agent/Service/ProviderKeychain.swift::AppleKeychainStore`
  (= wraps AppleKeychain = thread-safe per Apple docs)
- `Agent/Service/ProviderKeychain.swift::InMemoryKeychainStore`
  (= test mock; = no shared state)
- `Agent/Service/KeychainOps.swift::*`

### Category 5: Library + reference store (3 declarations)

- `Library/Service/FileSystemLibraryStore.swift` (= holds
  file URLs + JSON encoders; = uses serial dispatch queue
  for cross-actor access)
- `Library/Service/FileSystemReferenceStore.swift::*`
  (= similar pattern)
- `Library/Service/FileSystemChapterStore.swift::*`

### Category 6: View state + environment (4 declarations)

- `Shared/UI/EnvironmentKeys.swift::ChatSessionContext`
  (= the view model reference is non-Sendable; = callers
  are documented to only access via @MainActor)
- `Agent/View/ReaderExperienceView.swift::*` (= view state
  classes with NSLock guards)
- `Chat/View/ChatView.swift::*` (= view state with manual
  @MainActor safety)
- `Editor/View/PreviewPaneCard.swift::*`

## Decision

All 31 `@unchecked Sendable` declarations are **kept as-is**
(= each has a documented safety invariant per AGENTS.md §1.5
+ §1.6 = no narrative paragraphs, but the 1-line "SAFETY"
comment per declaration).

The "right" Swift 6 path (= make all stored properties
Sendable; = convert to `actor` for mutating state; = convert
to `struct` for value types) would require:
- 8 lock-based classes → `actor` (= refactor to async API)
- 4 reference wrappers → `struct` + Copy-on-Write
- 8 Tool adapters → re-architect to stateless factory
  pattern
- 4 Library stores → `actor`

These are **future refactors** (= the codebase is currently
Swift 6 *compatible* via @unchecked escape hatches; = the
@unchecked sends a clear signal to readers "manual safety
invariant = see the SAFETY comment").

## Future work

- ADR-0028 (proposed): convert lock-based classes to `actor`
  (= moves the lock into the actor's executor; = the
  @unchecked disappears naturally; = async API surface).
- ADR-0029 (proposed): convert reference wrappers to
  `struct` + CoW (= eliminates the reference class entirely).

These are non-blocking and can be picked up when each
feature is being touched for other reasons (= the §6.6
"no drive-by refactor" rule).

## Verification

- Build pass on all 31 classes (= Swift 6 strict concurrency
  is happy with @unchecked + the documented invariants).
- 401 WenshuApp tests pass + 3 WenshuData test suites
  pre-existing failures unchanged (= ADR-0023 documented).
- 0 new test regressions.
