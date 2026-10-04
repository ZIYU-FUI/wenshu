// App.swift · Wenshu · v0.09.0 6-zone layout shell (boss 8/18 component-based truth, 1920×984 PT)
// Data source: Sketch AF7B1C87 / page Wenshu / Artboard Home
// Component-based truth: mcp__sketch__run_code (2026-08-18) = 6 SymbolMaster + 13 SymbolInstance
// Unit: 1 PT = 1 PX (macOS 27 1x), 1:1 mapping, no scaling.
//
// 6 masters (boss 8/18 component planning):
//   1. Title bar               (1920×39)
//   2. Zone top toolbar        (758×30)   ← zone top-bar reuse
//   3. Zone bottom toolbar     (200×30)   ← zone bottom-bar reuse
//   4. Zone module             (200×472)  ← zone main container reuse
//   5. Drag line - vertical    (1×472)
//   6. Drag line - horizontal  (1920×1)
//
// 13 instances all 1:1 mapped to SwiftUI, see LayoutTokens.

import SwiftUI
import AppKit

// Symbols 6 (3rd generation) with palette rendering': LucideSwift
// import removed (= see Package.swift + IconStyles.swift).

// MARK: - v0.25.1 (= ticket 019 icon button Apple HIG hit area) — Apple recommended approach
/// Per Apple SwiftUI docs (developer.apple.com/documentation/swiftui/buttonstyle
/// + developer.apple.com/documentation/swiftui/primitivebuttonstyle/plain),
/// the canonical way to extend a plain-style button's hit area (= Apple
/// "How do I make icon buttons easier to click on macOS?") is to implement
/// `IconButtonStyle` REMOVED in v0.34 Apple-API-first #3.
/// Was a pass-through `makeBody { configuration.label }` (= no-op);
/// the previous call site + outer Button style (formerly App.swift
/// L1820 + L1839 before the Q2 boss split moved those features out
/// of App.swift) is now superseded by the canonical Apple
/// `.buttonStyle(.plain)` + `Color.clear.frame(28,28).contentShape(...)`
/// pattern (= Apple HIG hot-area convention).
/// SwiftUI button-style precedence = outer-wins, so the inner style was
/// always superseded. Use Apple `.buttonStyle(.plain)` directly with
/// `Color.clear.frame(28,28).contentShape(Rectangle())` inside the label
/// closure (= Apple HIG canonical hot-area pattern).

// Boss 8/18 said "reset layout" notification bridge (LayoutShellView [no longer defined post-v0.72 — AppRootScene + NavigationSplitView; = ADR-0007 pending ADR-0010; = type references kept as historical landmarks pending 老板 拍] uses @State private vm,
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

// MARK: - Layout tokens (ratio operators 0~1, boss 8/18 answered "1:1 PT truth" + 8/18 said "convert to ratios")
//
// Data source: Sketch AF7B1C87 / Artboard Home 1920×984 PT 1:1 mapping
// Formula: layoutPT(token) = totalW * ratio (e.g. projectSidebar ratio = 200/1920 = 0.1042)
// Apple HIG responsive: GeometryReader reads actual window size × ratio = 1:1 self-adaptive at any window size

/// Apple Semantic Color — fully dark-mode adapted, zero RGB hardcoded
// removed the `DesignColor` enum entirely. The 5 static
// lets (= titleBar / zoneSurface / dynamicZoneSurface / accentBlue /
// splitterLine) were each just a thin wrapper over a bare
// `Color(nsColor: .NSColorStaticProperty)` Apple API call. The
// wrapper added an extra type with no semantic value (= it renamed
// Apple NSColor static properties with no-op translation). All 4
// callers migrated to bare `Color(nsColor: .NSColor)` form in this
// commit. The 1 unused member (dynamicZoneSurface) had zero callers
// and is gone entirely. Apple canonical = direct NSColor calls; no
// project-local color wrapper enum.

enum LayoutTokens {
    // (designW / designH / chromeControlHeight removed 2026-10 in
    //  q99-spec-p0-batch1 commit after verify-dead.py confirmed 0
    //  external callers; = the original 1480 / 980 baseline never
    //  bound to a window, and macOS NavigationSplitView ignores the
    //  design values; = chromeControlHeight was superseded by
    //  DesignTokens chromeHeight = 30 (= the canonical chrome standard
    //  per AGENTS §11 token rule). See wenshu-pocock-workflow
    //  references/v3.0-design-system-rule.md.)


    // complete code, regarding styles, inconsistent — why don't you audit them'): single source
    // of truth for chrome padding (= replaces magic numbers 4, 6, 8
    // scattered across 15 files). Centralized here so future padding
    // changes apply uniformly across the app (= one place to edit,
    // every pane updates at once).
    //
    // Apple HIG canonical padding values for per-pane chrome items:
    // - chromePaddingSmall = 4 PT (= tight spacing for chip / pill)
    // - chromePaddingLarge = 8 PT (= roomier spacing for top/bottom
    //   alignment of text inside chrome bars — matches Apple HIG
    //   toolbar button padding)
    static let chromePaddingSmall: CGFloat = 4
    static let chromePaddingLarge: CGFloat = 8

    // per-region control heights (= chat input row buttons, tab
    // buttons, hover hot areas). chromeControlHeight was removed
    // 2026-10 (= verify-dead.py confirmed 0 external callers; =
    // superseded by DesignTokens chromeHeight = 30, the canonical
    // chrome standard per AGENTS §11 token rule). See
    // wenshu-pocock-workflow references/v3.0-design-system-rule.md.


}

// MARK: - Self screenshot (boss 8/14 12:38 + 8/15 14:48: must screenshot after every code change)

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
    /// WindowGroup instance gets its own AppState = boss 8/27 OOB
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
    /// are tracked in v0.31 backlog (= see CONTEXT.md AppState row).
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
        // apple-001 phase 1 Q1 slice 2: Scene composition (= WindowGroup +
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
// Settings { } Scene (ticket 04 commit 984ea556b Picker, 8/21 "show")


// ZoneSlot -> TabKind rename: the zone enum was duplicate-
// defined here. Per boss 2026-10-03 '清多余的层' OOB (= strip
// wenshu-summary layers that conflate with the Apple-canonical
// shape), the duplicate is removed and callers use the
// canonical TabKind (= declared in LayoutTreeState.swift).
// TabKind has the same 6 cases (= projectSidebar / projectPreview
// / editor / specializedTools / aiChat / aiDynamic) so the
// duplicate was always dead code.

// MARK: - Library outline (sidebar)
//
// sidebar MVVM cleanup: `LibraryOutlineViewContent` was a
// wiring wrapper that rendered the pre-v1.69e legacy
// `NewLibraryOutlineView` (the 2366-LOC mega-file sidebar).
// Both are removed in v1.69e (= commit 6bd3eb7f); = the sidebar
// surface in production lives in NavigationSplitShell.swift
// (= AppleSidebarView = the v1.68b Apple HIG List(.sidebar) +
// post-v1.69 split sheets/context-menu/business files). No
// replacement needed here.
