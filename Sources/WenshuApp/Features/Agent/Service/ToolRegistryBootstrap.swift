//
//  ToolRegistryBootstrap.swift · Wenshu · app-side tool wiring
//
//  The agent runtime package owns the tool contract, the registry, the
//  executor and the path guard. The app owns the tools. This file is
//  the seam between them: it hands the runtime the closure that touches
//  the app's tool types, and it hands the path guard the app's library
//  root.
//
//  The runtime never names an app type. The app never reaches into the
//  runtime's internals. The dependency direction stays one way.
//
//  Install point: `WenshuAppDelegate.applicationWillFinishLaunching`
//  (= the earliest app hook, = before any window, = before any tool
//  call). The path guard's accessor is a closure, so the library root
//  is read when a path is checked, not when the accessor is installed
//  (= a library picked after launch is still guarded correctly).
//

import Foundation
import WenshuAgent

/// The app's tool registrations, installed into the runtime's registry.
enum ToolRegistryBootstrap {

    /// Touch every production tool registration point exactly once.
    ///
    /// Each tool owns a `static let _registryBootstrap` that registers
    /// it into the shared registry. The `static let` runs the first time
    /// the type is referenced, so touching them here fires the
    /// registrations exactly once, in the same order, at the same
    /// moment relative to first use.
    static let touchAllToolTypes: @Sendable () -> Void = {
        _ = ReadFileTool._registryBootstrap
        _ = WriteFileTool._registryBootstrap
        _ = AVMediaTools._registryBootstrap
        _ = BookManagerTool._registryBootstrap
        _ = FileTools._registryBootstrap
        _ = KanbanStoreTool._registryBootstrap
        _ = ProcessTools._registryBootstrap
        _ = TodoStoreTool._registryBootstrap
        _ = HermesTodoTool._registryBootstrap
        _ = VisionTools._registryBootstrap
        _ = WebTools._registryBootstrap
        _ = BookChapterTool._registryBootstrap
        _ = BookEntityTool._registryBootstrap
        _ = BookOutlineTool._registryBootstrap
        _ = EditChapterTool._registryBootstrap
        _ = ReferenceLibraryTool._registryBootstrap
        _ = DelegateResearchTool._registryBootstrap
        _ = WebSearchTool._registryBootstrap
    }

    /// Install the app's tool registrations and the library-root accessor.
    ///
    /// Idempotent. The runtime runs the installed closure on every read
    /// of the shared registry, and the closure's own `static let` fires
    /// the registrations exactly one time either way.
    static func install() {
        ToolRegistry.ProductionToolRegistryBootstrap.start = touchAllToolTypes
        PathGuard.libraryRootProvider = { ActiveLibrary.path }
    }
}
