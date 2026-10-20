// App.swift · Wenshu
//
// Workspace shell (= the App-level root scene + window groups).
// Layout structure (pane tree + tabs) lives in LayoutTreeState +
// LayoutTreeStore; this file wires them into AppKit scenes only.

import AppKit
import SwiftUI
import WenshuData

// MARK: - Apple recommended approach
/// Per Apple SwiftUI docs (developer.apple.com/documentation/swiftui/buttonstyle
/// + developer.apple.com/documentation/swiftui/primitivebuttonstyle/plain),
/// the canonical way to extend a plain-style button's hit area (= Apple
/// "How do I make icon buttons easier to click on macOS?") is to implement
/// `IconButtonStyle` REMOVED in the Apple-API-first pass.
/// Was a pass-through `makeBody { configuration.label }` (= no-op);
/// the previous call site + outer Button style (formerly App.swift
/// L1820 + L1839 before the legacy code split moved those features out
/// of App.swift) is now superseded by the canonical Apple
/// `.buttonStyle(.plain)` + `Color.clear.frame(28,28).contentShape(...)`
/// pattern (= Apple HIG hot-area convention).
/// SwiftUI button-style precedence = outer-wins, so the inner style was
/// always superseded. Use Apple `.buttonStyle(.plain)` directly with
/// `Color.clear.frame(28,28).contentShape(Rectangle())` inside the label
/// closure (= Apple HIG canonical hot-area pattern).

// "reset layout" notification bridge (AppRootScene uses @State private vm,
// top-level .commands can't access vm instance, routed via NotificationCenter)

// name for menu bar zone toggle buttons (= CommandGroup can't directly
// access vm instance, so menu items post notification, vm listens).
// all Notification.Name
// definitions moved to Sources/WenshuApp/Core/Notifications/AppNotifications.swift
// (= single source of truth, grouped into AppCommands / AppStateEvents /
// LayoutEvents enums, unified to "com.wenshu.X" naming per Apple
// Notification Programming Topics reverse-DNS convention). Backward-compat
// accessors (= .wenshuXxx on Notification.Name) live in that file for
// the migration window so the 17 existing call sites compile unchanged.
extension Notification.Name {}  // placeholder; all members moved to AppNotifications.swift

// MARK: - Self screenshot (= the canonical practice: screenshot after every code change)

enum SelfScreenshot {
    @MainActor
    static func run() {
        let env = ProcessInfo.processInfo.environment
        let path = env["WS_SCREENSHOT_PATH"] ?? "/tmp/wenshu-selfshot.png"
        let delay = Double(env["WS_SCREENSHOT_DELAY"] ?? "5.0") ?? 5.0  // 5s layout race condition (debug-only)
        let shouldExit = env["WS_SCREENSHOT_EXIT"] != "0"

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            captureOnce(path: path, exitAfter: shouldExit)
        }
    }

    @MainActor
    private static func captureOnce(path: String, exitAfter: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard
                let window = NSApp.keyWindow
                    ?? NSApp.windows.first(where: { $0.contentViewController != nil }),
                let contentView = window.contentView
            else {
                if exitAfter { exit(2) }
                return
            }
            window.layoutIfNeeded()
            contentView.layoutSubtreeIfNeeded()
            let bounds = contentView.bounds
            guard bounds.width > 0, bounds.height > 0,
                  let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds)
            else {
                if exitAfter { exit(2) }
                return
            }
            bitmap.size = bounds.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: bounds.size).fill()
            NSGraphicsContext.restoreGraphicsState()
            contentView.cacheDisplay(in: bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                if exitAfter { exit(3) }
                return
            }
            try? png.write(to: URL(fileURLWithPath: path))
            if exitAfter { exit(0) }
        }
    }
}

// MARK: - App entry

// wenshu (system / dark / light), Settings + @AppStorage
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case dark
    case light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .dark:   return "深色"
        case .light:  return "浅色"
        }
    }
    /// SwiftUI ColorScheme (system nil SwiftUI)
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

@main
struct WenshuApp: App {
    @NSApplicationDelegateAdaptor(WenshuAppDelegate.self) var appDelegate

    @State private var library = WenshuLibrary(
        store: FileSystemLibraryStore(rootURL: LibraryRoot.ensureDefault())
    )
    // (Standards sub-agent report H3): preferredColorScheme UserDefaults.standard.string, SettingView $appearanceMode yes binding source-of-truth
    // commit 4ef3e2e77 UserDefaults.standard.string, change @AppStorage (SettingView key)
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    /// option A for cross-zone communication
    /// (= global @Observable store). Per-window @State (= each
    /// WindowGroup instance gets its own AppState ((see OOB.md #2026-08-27))
    /// multi-window future-proofing). Currently hosts the
    /// `llmModel` + `openTabs` signals (= the persistence-pair
    /// from commit 4b5d94f1f).
    /// Cross-zone shell-chrome state (= sidebar selection, inspector
    /// visibility, chat zone visibility) lives on `WorkspaceUIState`
    /// (= 2026-10-03 overabstraction cleanup merged ShellState +
    /// WorkspaceUIState into one @Observable class; = the Pages /
    /// Numbers / Keynote canonical shape). The
    /// `@Environment(AppState.self) var appState` lookup continues
    /// for `llmModel` + `openTabs`.
    /// The 3 other signals declared in the original spec
    /// (selectedEntity / selectedEntityCategory / previewSortOrder)
    /// are tracked in the backlog (= see CONTEXT.md AppState row).
    /// Descendants read it via `@Environment(AppState.self) var appState`.
    @State private var appState = AppState()

    /// sort order + layout edit mode). Split out from AppState.
    /// Injected via `.environment(workspaceUI)` at the AppRootScene
    /// root. Same per-window @State pattern.
    @State private var workspaceUI = WorkspaceUIState()

    /// (= newBook / newShelf / choice). Split out from AppState.
    /// Injected via `.environment(sheetRequests)` at the AppRootScene
    /// root.
    @State private var sheetRequests = SheetRequestState()

    /// (= wordCount). Split out from AppState. Injected via
    /// `.environment(editorCounters)` at the AppRootScene root.
    @State private var editorCounters = EditorCounters()

    /// WSRepositoryContainer holds the 9
    /// `@MainActor @Observable` SwiftData repositories (= `chat`,
    /// `todo`, `kanban`, ...). Per `WSRepositoryContainer.swift:18-21`,
    /// Views should pull repos via `@Environment(WSRepositoryContainer.self)`,
    /// never `WSKanbanRepository.shared` etc. (= the `.shared` static
    /// singletons exist for legacy call sites only; see the comment
    /// at `WSRepositoryContainer.swift:50-55`).
    @State private var repositories = WSRepositoryContainer()

    var body: some Scene {
        // apple canonical scene composition: Scene composition (= WindowGroup +
        // .commands + Settings) is now in AppRootScene. WenshuApp stays as the
        // composition root that owns the state (`library` / `appearanceMode`
        // / `appState`) and forwards it into AppRootScene as constructor
        // parameters. The state owner is WenshuApp (= cannot move because
        // @State + @AppStorage require the @main App struct), so AppRootScene
        // is a thin Scene assembly that consumes the state and wires the
        // scene tree.
        AppRootScene(
            library: library,
            appearanceMode: $appearanceMode,
            appState: appState,
            workspaceUI: workspaceUI,
            sheetRequests: sheetRequests,
            editorCounters: editorCounters,
            repositories: repositories
        )
    }
}

/// task (Hermes AUX_TASKS: vision/web_extract/compression/approval/mcp/title_generation/curator)
enum AuxTask: String, CaseIterable, Identifiable {
    case vision = "vision"
    case webExtract = "web_extract"
    case compression = "compression"
    case approval = "approval"
    case mcp = "mcp"
    case titleGeneration = "title_generation"
    case curator = "curator"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vision: return "视觉"
        case .webExtract: return "网页提取"
        case .compression: return "压缩"
        case .approval: return "审批"
        case .mcp: return "MCP"
        case .titleGeneration: return "标题生成"
        case .curator: return "馆长"
        }
    }

    var icon: String {
        switch self {
        case .vision: return "eye"
        case .webExtract: return "globe"
        case .compression: return "arrow.down.right.and.arrow.up.left"
        case .approval: return "checkmark.shield"
        case .mcp: return "puzzlepiece"
        case .titleGeneration: return "textformat"
        case .curator: return "tray.full"
        }
    }
}


// Spec sub-agent (deleg_10289a6b): installMainMenu 6 + create NSWindow SettingView =
// Settings { } Scene ( Picker, 8/21 "show")


// ZoneSlot -> TabKind rename: the zone enum was duplicate-
// defined here. Per (see OOB.md #2026-10-03) '' OOB (= strip
// wenshu-summary layers that conflate with the Apple-canonical
// shape), the duplicate is removed and callers use the
// canonical TabKind (= declared in LayoutTreeState.swift).
// TabKind has the same 6 cases (= projectSidebar / projectPreview
// / editor / specializedTools / aiChat / aiDynamic) so the
// duplicate was always dead code.

// MARK: - Library outline (sidebar)
//
// sidebar MVVM cleanup: `LibraryOutlineViewContent` was a
// wiring wrapper that rendered the legacy
// `NewLibraryOutlineView` (the 2366-LOC mega-file sidebar).
// Both are removed (= commit 6bd3eb7f); = the sidebar
// surface in production lives in NavigationSplitShell.swift
// (= AppleSidebarView = the Apple HIG List(.sidebar) +
// post-v1.69 split sheets/context-menu/business files). No
// replacement needed here.
