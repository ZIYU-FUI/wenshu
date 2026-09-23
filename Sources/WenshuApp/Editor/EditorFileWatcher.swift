//
//  EditorFileWatcher.swift · Wenshu · v1.70 editor-mvvm T1a
//
//  Extracted from `EditorPlaceholder.swift` (= v0.34 B-23 inline
//  `startFileWatcher()` + `stopFileWatcher()`). Lives at the
//  module's Editor layer (= the same layer as `DraftPersistence`,
//  `WikiLinkNavigation`, `EditorActions`).
//
//  Per boss 2026-09-22 OOB '拆完功能' (= the split is done; = verify
//  the functionality) + the v1.68 sidebar v1.68 UI/业务/数据分离
//  precedent (= the NavigationSplitShell sibling splits in v1.38-v1.43
//  each moved one responsibility out of the wrapper view into its
//  own file). The DispatchSource wrapper is one responsibility
//  (= it owns the fd + the DispatchSource lifecycle for a single
//  file path); = it does NOT own save / load / reload semantics.
//  Those split out as EditorPersistence (T2) + EditorNavigation (T3)
//  in subsequent commits.
//
//  Why a stateless enum (= static methods) rather than a class:
//  - The dispatch source itself is stored on `EditorTab.fileWatcher`
//    (= the @Observable per-tab state container, AppState.swift:524).
//    = the enum only mutates `tab.fileWatcher` and `tab.watchedFD`.
//  - The v0.34 B-23 invariant (= "close fd when source is cancelled")
//    is preserved by binding the close(fd) call to the DispatchSource's
//    `setCancelHandler` (= standard AppKit pattern; = no enum
//    instance state needed).
//  - The onChange callback is captured by the DispatchSource event
//    handler closure (= closure-captured, no instance field).
//
//  Apple HIG canonical pattern (= Files app / Xcode file watcher):
//  POSIX `open(path, O_EVTONLY)` returns an fd; DispatchSource
//  reads from the fd; `setCancelHandler { close(fd) }` prevents
//  fd leaks (= the previous inline code did exactly this).
//

import Foundation
import Dispatch

/// Per-tab file-system watcher. Owns the DispatchSource
/// lifecycle for a single file path (= one fd + one DispatchSource
/// per `EditorTab`). Lifecycle is the caller's responsibility:
/// `start(path:tab:onChange:)` opens + arms; `stop(tab:)` cancels
/// + clears.
///
/// All methods are `@MainActor`-isolated (= the DispatchSource
/// event handler runs on `queue: .main`; = the fd-open + cancel
/// callbacks must run on the same isolation domain to match).
///
/// Internal (= not public) because `EditorTab` itself is internal
/// (= AppState.swift:487 = `final class` with no access modifier).
/// This matches the v0.34 B-23 legacy code (= `private func`
/// inside EditorPlaceholder = module-internal).
@MainActor
enum EditorFileWatcher {

    /// Arm a file-system watcher on `path`. Writes the resulting
    /// `DispatchSourceFileSystemObject` to `tab.fileWatcher` and
    /// the POSIX fd to `tab.watchedFD` (= per-tab ownership per
    /// v0.34 B-23).
    ///
    /// - Parameters:
    ///   - path: absolute path to the .md file to watch. `nil` =
    ///     no-op (= placeholder mode = no real document; = matches
    ///     the legacy `guard let path = documentPath else { return }`).
    ///   - tab: the `EditorTab` that owns the watcher state. Mutated
    ///     in place: `tab.fileWatcher` + `tab.watchedFD`.
    ///   - onChange: invoked on the main queue whenever the
    ///     underlying file is written / extended. Delete + rename
    ///     events are NOT surfaced (= the legacy code ignored them
    ///     too; = a follow-up ticket can re-arm against the new fd
    ///     after rename).
    ///
    /// Failure modes (= silent per v0.34 B-23 invariant):
    /// - `path` is `nil` → returns without touching `tab`.
    /// - `open(path, O_EVTONLY)` returns a negative fd (= file
    ///   missing / permission denied) → returns without touching
    ///   `tab`. (Legacy code logged to stdout in DEBUG; = same
    ///   here, gated on #if DEBUG.)
    static func start(
        path: String?,
        tab: EditorTab,
        onChange: @escaping () -> Void
    ) {
        // Placeholder mode (= no real document) → no watcher needed.
        // Matches the legacy `guard let path = documentPath else { return }`.
        guard let path else { return }

        // Open the file for read (= O_EVTONLY flag on macOS = notify-only,
        // = no actual read permission needed). POSIX open(2) returns
        // the file descriptor; DispatchSource reads from it.
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            #if DEBUG
            print("[wenshu.editor.file-watcher] cannot open fd for \(path)")
            #endif
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak source] in
            guard let source else { return }
            let events = source.data
            // .write + .extend = file content changed (= the cases we care about).
            // .delete + .rename = file replaced/moved (= re-arm the watcher
            // against the new file descriptor in a follow-up ticket;
            // = current implementation just reloads from the original path).
            if events.contains(.write) || events.contains(.extend) {
                onChange()
            }
        }
        source.setCancelHandler {
            // Apple HIG: close the fd when the source is cancelled
            // (= prevents fd leaks; = standard pattern).
            close(fd)
        }
        source.resume()
        tab.fileWatcher = source
        tab.watchedFD = fd
    }

    /// Tear down the watcher (= cancel DispatchSource; = close fd
    /// happens automatically via the cancel handler bound in
    /// `start(path:tab:onChange:)`). Resets `tab.fileWatcher` to
    /// `nil` and `tab.watchedFD` to `-1`.
    ///
    /// Safe to call when no watcher is armed (= no-op: tab fields
    /// already at their initial values).
    static func stop(tab: EditorTab) {
        tab.fileWatcher?.cancel()
        tab.fileWatcher = nil
        tab.watchedFD = -1
    }
}