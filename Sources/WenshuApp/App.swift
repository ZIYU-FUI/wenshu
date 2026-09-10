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
import Lucide

// MARK: - v0.25.1 (= ticket 019 icon button Apple HIG hit area) — Apple recommended approach
/// Per Apple SwiftUI docs (developer.apple.com/documentation/swiftui/buttonstyle
/// + developer.apple.com/documentation/swiftui/primitivebuttonstyle/plain),
/// the canonical way to extend a plain-style button's hit area (= Apple
/// "How do I make icon buttons easier to click on macOS?") is to implement
/// `IconButtonStyle` REMOVED in v0.34 Apple-API-first #3.
/// Was a pass-through `makeBody { configuration.label }` (= no-op),
/// single call site (App.swift:1820) inside the Button label closure
/// while App.swift:1839 applied `.buttonStyle(.plain)` on the outer Button.
/// SwiftUI button-style precedence = outer-wins, so the inner style was
/// always superseded. Use Apple `.buttonStyle(.plain)` directly with
/// `Color.clear.frame(28,28).contentShape(Rectangle())` inside the label
/// closure (= Apple HIG canonical hot-area pattern).

// Boss 8/18 said "reset layout" notification bridge (LayoutShellView uses @State private vm,
// top-level .commands can't access vm instance, routed via NotificationCenter)

// v0.24 fix (Boss 8/25 60th OOB 'corresponding feature should be implemented in menu bar'): notification
// name for menu bar zone toggle buttons (= CommandGroup can't directly
// access vm instance, so menu items post notification, vm listens).
// v0.34 boss 2026-09-02 OOB (B-04 backlog entry): all Notification.Name
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
// v0.32 boss 2026-09-02 OOB ('go all apple api default; don't write your own color wrapper'): removed the `DesignColor` enum entirely. The 5 static
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
    // Design baseline (Apple macOS 27 1x = 1 PT = 1 PX)
    static let designW: CGFloat = 1480  // v0.90 boss 2026-09-10 OOB '1480 也可以': boss's preferred column balance. Note: macOS 27 NavigationSplitView appears to ignore this defaultSize and force a minimum window width of ~2205 PT (= 4 columns + drag handles + chrome); the user can manually resize to 1480 but the initial launch is always wider.
    static let designH: CGFloat = 980

    // Ratio operators (0~1, baseline 1920×984)
    // Boss 2026-08-19 said: title bar uses macOS .windowStyle(.titleBar) 52 PT unified chrome, no longer self-written
    // v0.15 ticket 001: delete dead LayoutTokens.titleBarHeight / titleRatio code (Apple window chrome provides)
    static let bandRatio: CGFloat = 465.0 / 984.0        // = 0.4726 (boss 8/18 changed to 465 PT, total 52+465+2+465 = 984)
    // v0.15 ticket 008 fix: toolbar height = boss Sketch truth 30 PT hardcoded, 1:1 implementation without PT→PX conversion (boss 2026-08-19 said)
    // Previously toolbarRatio = 30/465 = 0.0645 with algorithm base = 465 hardcoded, but actual bandH was 932 so toolbarH = 932*0.4726*0.0645 ≈ 28 PT (didn't match boss's 30 PT, visually insufficient)
    static let toolbarHeight: CGFloat = 30  // boss Sketch master truth: top/bottom bars 30 PT (1:1 implementation)
    // v0.15 rewrite renamed: editorInset is single vertical direction (left/right flush, spec §3.2 intentional two-layer design)
    static let editorVerticalInsetRatio: CGFloat = 4.0 / 984.0  // = 0.0041 (editor 4 PT top/bottom inset)
    // v0.15 ticket 005: delete dead LayoutTokens.horizontalSplitterRatio code
    // (the drag-to-resize logic is now provided by NSSplitView).

    // Upper band 4 zone count formula: (200, middle 1, middle 2, 400) = 1920
    // Boss 8/18 said "count formula" = drag line 1 PT visual line distributed to left/right zones (0.5 PT each)
    // Middle 1 + Middle 2 = 1920 - 200 - 400 = 1320
    // Preserves original values 558 + 762 (middle 1 + middle 2 = 1320) = upper band 4 zones 1920 ✓
    // v0.24 fix (Boss 8/25 50th OOB 'still off by one or two pixels' + 51st OOB 'try to fix it'):
    // hit area 6 -> 4 PT (= the drag-to-resize logic). 3 splitters
    // upper = 12 PT (not 18).
    // Splitter hit area counted into the largest column (= editor),
    // other columns preserve design ratios.
    // Total column = 200+200+388+200 = 988 + 12 splitters = 1000
    // (= exact fit, no HStack shrinkage).
    // Upper band 4 zones (20/20/40/20 = 100% total):
    // NOTE: these constants are dead code. The active rendering
    // path (v0.28+ WorkspaceView) reads column weights from
    // LayoutTreeStore.builtinDefaultPreset (= [1, 2, 6, 1] after
    // commit b8fb940d2). Kept here for the legacy LayoutShellView
    // path (= unreachable in practice but preserved for
    // backward-compat with the AppStorage flag 'wenshu.useWorkspace'
    // = false case). Do NOT use these constants directly in new code.
    static let projectSidebarRatio: CGFloat = 200.0 / 1000.0  // 20% (= Boss 45th OOB)
    static let projectPreviewRatio: CGFloat = 200.0 / 1000.0  // 20% (= Boss 45th OOB)
    // v0.24 fix (Boss 8/25 51st OOB): editor itself contains 3 splitters (= 12 PT hit area @ 4 PT each).
    // 400 (= 40% design) - 12 (= 3 × 4 splitters) = 388 (= design includes splitter)
    static let editorWRatio: CGFloat = 388.0 / 1000.0         // 40% design - 3 splitters @ 4 PT
    static let toolsWRatio: CGFloat = 200.0 / 1000.0         // 20% (= Boss 45th OOB)

    // v0.24 fix (Boss 8/25 41st OOB 'originally 400, check official docs to fix visual width mismatch'):
    // Boss clarified: upper-right (specializedTools) and lower-right (aiDynamic)
    // original design both = 400 PT.
    // My previous commit b8d8c04a8 incorrectly changed dynamicWRatio to 1194
    // (= Boss 38th OOB misinterpretation, Boss 41st OOB clarified = originally 400).
    // Revert dynamicWRatio 1194 -> 400, aiChatRatio 726 -> 1518 (= back to
    // original 8/18 design values).
    // Real problem = same 400 PT visually different widths (= need to check
    // official docs for proper fix).
    // v0.24 fix (Boss 8/25 44th OOB 'code width is wrong'): drop aiChatRatio 1518 -> 1514
    // to absorb 1 splitter hit area (1 × 6 PT = 6 PT). New sum = 1514+400
    // = 1914 + 6 splitter = 1920 PT (= exact window width, no HStack shrinkage).
    // v0.24 fix (Boss 8/25 50th OOB 'still off by one or two pixels' + 51st OOB 'try to fix it'):
    // hit area 6 -> 4 PT. 1 splitter lower = 4 PT (not 6).
    // aiChat itself contains 1 splitter (= 4 PT hit area @ 4 PT).
    // 800 (= 80% design) - 4 (= 1 × 4 splitter) = 796 (= design includes splitter)
    // Total column = 796+200 = 996 + 4 splitter = 1000 (= exact fit, no HStack shrinkage).
    // Lower band 2 zones (80/20 = 100% total):
    static let aiChatRatio: CGFloat = 796.0 / 1000.0         // 80% design - 1 splitter @ 4 PT
    static let dynamicWRatio: CGFloat = 200.0 / 1000.0       // 20% (= Boss 45th OOB)

    // Editor Two Layers Design
    static let editorInsetRatio: CGFloat = 4.0 / 984.0  // = 0.0041


    // Top bar color block ratios (boss 8/18 Q3 answer: 22/82/142 origin + 38 PT width + 60 PT spacing)
    static let iconLeadingRatio: CGFloat = 18.0 / 1920.0  // origin 18 PT (boss 8/18 changed to 18 PT, previously 22 PT)
    static let iconSizeRatio: CGFloat = 18.0 / 1920.0     // 18 PT side length (boss 2026-08-26 'change to 18') — was 12 in v0.24 ticket 015.027 (= boss 8/24 'change to 12×12' = mid-step before 'change to 18'). Now 18 PT for top-toolbar tab / archive icons.
    // v0.24 boss acceptance fix (Boss 8/24): tab icon 12×12 PT (= interim; boss 8/24 'change to 12×12' after 18×18 too big).
    // v0.25.1 (= ticket 006 chat-zone icon size): boss 2026-08-26 OOB 'the top-bar icon size is a bit too small now, change to 18' = 12 → 18 PT.
    // Scope = top-bar icon class only (= applies to DesignTokens.tabIconSize, used
    // by ChatZoneTabBar tab + archive + DynamicZoneView tab + ZoneContentView
    // item, ALL top-toolbar tab icons). Bottom toolbar status bar (= text not
    // icons) unchanged. Toolbar height hard-capped at 30 PT (= per Boss 8/18
    // Sketch master): 18 PT icons render with 6 PT vertical padding each side (=
    // flush fit, no overflow). If owner pushes back on the toolbar-height fit,
    // ticket 006 followup will address it (= scope of THIS patch is just icon
    // size).
    static let iconSize: CGFloat = 18
    // v0.25.1 (= ticket 007 chat-zone tab hot area): owner 2026-08-26 OOB
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    // 'the hit area has an issue, it seems like the ICON itself is the hit area, you need to make the ICON's 18×18 area be the hit area, otherwise it's hard to click' = inflate click target from icon visual size
    // (= 18 PT) to a fixed hot area that maps to the boss 8/11 fix3
    // 'four chat tab height set to 28 PT' (= 28 PT). Hot area applied to
    // BOTH chat tabs (.chat + the right archive-flow icon) for consistency.
    // Hot zone = 28 PT (= boss 8/11 fix3) leaves 2 PT vertical padding in
    // the 30 PT toolbar (= flush fit). Inner icon stays at DesignTokens.tabIconSize
    // (= 18 PT, ticket 006) so visual size unchanged from previous commit.
    static let chatTabHotArea: CGFloat = 28
    // v0.25.1 (= ticket 008 chat-zone tab hit reliability): owner 2026-08-26
    // OOB 'still has an issue, response is not always triggered' = prior ticket 007 fix
    // (= .frame(28,28) + contentShape) was flaky on plain-style Button. Per
    // Apple HIG + SwiftUI Forums canon: reliable hit extension on plain
    // buttons = inline `.padding(.all, hitPad)` inside the label (= the
    // padding extends the inner view's rendered bounds, which the outer
    // button uses as its hit area). 5 PT padding + 18 PT icon = 28 PT
    // total hit area (= same as chatTabHotArea constant, kept separate
    // for clarity: hitPad is the lever, hitArea is the resulting size).
    static let chatTabHitPad: CGFloat = 5
    // v0.25.1 (= ticket 015 unified icon button hot area): owner 2026-08-26
    // OOB 'all ICON hit areas should be handled the same as the archive ICON' = the 'archive'
    // ICON (= chat zone top-right .inbox button, ticket 007 + 008 pattern)
    // is the canonical hit-area reference for ALL icon buttons in the
    // project. Apply same hot-area treatment (= 28×28 PT inflated hot
    // area via inline .padding(.all, LayoutTokens.iconButtonHotPad); .frame
    // stays 18 PT visual size; .contentShape(Rectangle()); .background
    // (.clear) for SwiftUI hit-tester reliability) to:
    //  - upper main toolbar (8 global buttons: New/Open/Import + 4 zone
    //    toggle + Export)
    //  - chat zone send button (.paperplane.fill)
    //  - the 11 tab buttons across 3 tab bar classes (= already applied
    //    in ticket 011, kept unchanged).
    static let iconButtonHotPad: CGFloat = 5
    // v0.25.1 (= ticket 010 tab selected-state underline): owner 2026-
    // 08-26 OOB 'the current tab's selected state, there's no small underline under the ICON' =
    // Apple HIG canonical selected-tab underline (= ~2 PT height accent
    // bar at bottom of selected tab, full button width). All 3 tab bar
    // classes (DynamicZoneView / ZoneContentView / ChatZoneTabBar) use
    // this constant for the underline height; the underline color is
    // Color.accentColor (= Apple system accent, matches selected-tab
    // icon color so the visual cue is consistent).
    // v0.25.1 (= ticket 025 underline height = 1 PT per owner spec):
    // owner 2026-08-26 OOB 'change all ICON underlines to 1PT' = bump down
    // from 3 PT (= ticket 024) to 1 PT (= owner final spec, = a
    // minimal visual hint rather than a heavy accent bar). Apple
    // HIG acceptable range for tab-bar selected indicator =
    // 1-4 PT (= 1 PT is the thinnest canonical option, = Apple
    // HIG Finder sidebar selected indicator style per developer
    // .apple.com/design/human-interface-guidelines/components/
    // navigation/sidebars).
    static let tabUnderlineHeight: CGFloat = 1
    static let iconSpacingRatio: CGFloat = 18.0 / 1920.0  // 18 PT spacing (boss 8/18 changed to 18 PT = icon spacing, origins 18/54/90, adjacent 36 - 18 = 18)

    // Bottom Bar Bit Elements (Boss 8/18 decision "icon 18 x 18, in the body size of an apple character style) - Absolute PT does not go through the ratio system
    static let bottomLeading: CGFloat = 18                 // 18 PT from left (left placeholder text)
    static let bottomTrailing: CGFloat = 18                // 18 PT from right (right placeholder icon)
    static let placeholderIconSize: CGFloat = 18          // 18 PT placeholder icon side length (absolute)
    static let placeholderTextLeadingRatio: CGFloat = 0.09  // placeholder text origin 18/200 = 9%

    // v0.28 followup Boss UX round 33 (Boss 2026-08-29 OOB 'the per-region
    // complete code, regarding styles, inconsistent — why don't you audit them'): single source
    // of truth for chrome padding (= replaces magic numbers 4, 6, 8
    // scattered across 15 files). Centralized here so future padding
    // changes apply uniformly across the app (= one place to edit,
    // every pane updates at once).
    //
    // Apple HIG canonical padding values for per-pane chrome items:
    // - chromePaddingSmall = 4 PT (= tight spacing for chip / pill)
    // - chromePaddingMedium = 6 PT (= standard for icon + text padding
    //   in tab bars / statusbars — matches Apple HIG statusbar item
    //   padding)
    // - chromePaddingLarge = 8 PT (= roomier spacing for top/bottom
    //   alignment of text inside chrome bars — matches Apple HIG
    //   toolbar button padding)
    // - chromePaddingLeading = 18 PT (= horizontal left padding from
    //   tab bar edge to first item — matches Apple HIG toolbar left
    //   padding for macOS 27 Tahoe tab bars)
    // - chromePaddingTrailing = 18 PT (= horizontal right padding)
    static let chromePaddingSmall: CGFloat = 4
    static let chromePaddingMedium: CGFloat = 6
    static let chromePaddingLarge: CGFloat = 8
    static let chromePaddingLeading: CGFloat = 18
    static let chromePaddingTrailing: CGFloat = 18

    // v0.28 followup Boss UX round 33: single source of truth for
    // per-region control heights (= chat input row buttons, tab
    // buttons, hover hot areas). All instances of ".frame(height: 30)"
    // for chrome controls should reference chromeControlHeight instead.
    static let chromeControlHeight: CGFloat = 30

    // v0.28 followup Boss UX round 33: single source of truth for
    // visual divider / separator thickness. All instances of
    // ".frame(height: DesignTokens.dividerHeight)" for chrome separators should reference
    // chromeDividerThickness (= 1 PT Apple HIG hairline).
    static let chromeDividerThickness: CGFloat = 1

    // v0.28 followup Boss UX round 33: selected-tab underline height.
    // (= 1 PT per v0.25.1 ticket 025 owner spec)
    static let tabUnderlineHeightNew: CGFloat = 1  // legacy alias for tabUnderlineHeight
}

// MARK: - Self screenshot (boss 8/14 12:38 + 8/15 14:48: must screenshot after every code change)

enum SelfScreenshot {
    @MainActor
    static func run() {
        let env = ProcessInfo.processInfo.environment
        let path = env["WS_SCREENSHOT_PATH"] ?? "/tmp/wenshu-selfshot.png"
        let delay = Double(env["WS_SCREENSHOT_DELAY"] ?? "5.0") ?? 5.0  // v0.10.7: 5s layout race condition
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
    // v0.21 ticket 01 (redo #11): @AppStorage("appearanceMode") (commit 4ef3e2e77, change @AppStorage)
    // (Standards sub-agent report H3): preferredColorScheme UserDefaults.standard.string, SettingView $appearanceMode yes binding source-of-truth
    // commit 4ef3e2e77 UserDefaults.standard.string, change @AppStorage (SettingView key)
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    /// v0.30 boss 8/31 OOB "option A for cross-zone communication"
    /// (= global @Observable store). Per-window @State (= each
    /// WindowGroup instance gets its own AppState = boss 8/27 OOB
    /// multi-window future-proofing). Currently hosts the
    /// `sidebarSelection` signal (= the 4-layer @Binding chain
    /// from commit d845fe9c9 has been collapsed to a single
    /// `@Environment(AppState.self) var appState` lookup).
    /// The 3 other signals declared in the original spec
    /// (selectedEntity / selectedEntityCategory / previewSortOrder)
    /// are tracked in v0.31 backlog (= see CONTEXT.md AppState row).
    /// Descendants read it via `@Environment(AppState.self) var appState`.
    @State private var appState = AppState()

    var body: some Scene {
        // v0.40 apple-001 phase 1 Q1 slice 2: Scene composition (= WindowGroup +
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
            appState: appState
        )
    }
}

/// task (Hermes AUX_TASKS: vision/web_extract/compression/skills_hub/approval/mcp/title_generation/curator)
enum AuxTask: String, CaseIterable, Identifiable {
    case vision = "vision"
    case webExtract = "web_extract"
    case compression = "compression"
    case skillsHub = "skills_hub"
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
        case .skillsHub: return "技能中心"
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
        case .skillsHub: return "wand.and.stars"
        case .approval: return "checkmark.shield"
        case .mcp: return "puzzlepiece"
        case .titleGeneration: return "textformat"
        case .curator: return "tray.full"
        }
    }
}


// v0.21 ticket 01 (redo #10): SettingsEnvironmentCapturer (Q15 #11 dead code) + VibeMeter Mirror reflection NSApp.openSettings extension (Q15 #12 dead code)
// Spec sub-agent (deleg_10289a6b): installMainMenu 6 + create NSWindow SettingView =
// Settings { } Scene (ticket 04 commit 984ea556b Picker, 8/21 "show")


/// Zone slot enum (= 6 named cases, one per functional module in
/// the new framework). Used by WorkspaceView's renderTabByKind to
/// dispatch to the right view (= projectSidebar → NewLibraryOutlineView,
/// projectPreview → EntityPreviewPane, editor → editor, etc.).
/// v0.10.3 split chatSidebar + chatDialogue 2, aiChat.
enum ZoneSlot {
    case projectSidebar
    case projectPreview
    case editor
    case specializedTools
    case aiChat        // 8/18 "four on top, two on bottom", lower band full-width AI chat (v0.10.3 chatSidebar + chatDialogue)
    case aiDynamic
}

// MARK: - Library outline (sidebar)

/// sidebar (= v0.27 wiring: NewLibraryOutlineView reads from
/// BookStore via @Environment). Replaces v0.25.x WenshuLibrary-backed
/// LibraryOutlineView (= no longer used in production zone).
    struct LibraryOutlineViewContent: View {
        @Environment(BookStore.self) private var bookStore
        var body: some View {
            // v0.30: NewLibraryOutlineView has default dummy binding init.
            NewLibraryOutlineView()
            // v0.28 followup Boss UX round 44 (Boss 2026-08-29 OOB
            // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
            // ', top barbottom bar' = the
            // `.padding(.vertical, DesignTokens.chromePaddingNano)` was pushing the sidebar content
            // (= NewLibraryOutlineView's tree outline) up by 2 PT,
            // which made the sidebar's bottom status bar (= ":0")
            // appear higher than the other 3 general panes'
            // (= ":0" / ":0" / "") = visual.
            // Fix = removed `.padding(.vertical, DesignTokens.chromePaddingNano)`. The horizontal
            // `.padding(DesignTokens.chromePaddingVertical)` (= 8 PT left/right margin) is preserved
            // for the tree outline indentation.
            .padding(DesignTokens.chromePaddingVertical)
            .environment(bookStore)
    }
}






