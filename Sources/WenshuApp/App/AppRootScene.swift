// AppRootScene.swift · Wenshu · v0.40 apple-001 phase 1 Q1 slice 2
//
// Q1 boss拍 split App.swift. After slice 1 (= extract WenshuAppDelegate
// to App/WenshuAppDelegate.swift), the next slice pulls the Scene
// assembly out of `WenshuApp.body` so the @main struct itself becomes
// a minimal composition root (= declares the state owners + delegates
// scene composition to AppRootScene).
//
// Why a Scene struct, not a View struct:
// WenshuApp.body returns `some Scene` (= WindowGroup + .commands +
// Settings). Scene is a SwiftUI protocol that hosts the root-level
// scene tree. The composition logic = `WindowGroup { ... }
// .windowToolbarStyle(.unified) ... .commands { ... }` then a
// sibling `Settings { ... }` scene. Both pieces are Scene-level
// concerns (= window chrome, command palette bindings, settings
// environment injection) and must stay at the scene layer; lifting
// them into a View would be a downgrade (= Settings scene cannot be
// expressed as a View body).
//
// Why state stays on WenshuApp (= not AppRootScene):
// @State + @AppStorage require an @DynamicMemberLookup storage
// instance (= the App struct itself). The state owners
// (library / appearanceMode / appState) must remain on WenshuApp;
// AppRootScene receives them as constructor parameters. The
// `@AppStorage("appearanceMode")` binding is forwarded as
// `@Binding var appearanceMode` to AppRootScene so the
// SettingsEnvironmentCapturer inside WindowGroup can still observe
// the same single source of truth.

import SwiftUI
import AppKit
import Lucide

struct AppRootScene: Scene {
    let library: WenshuLibrary
    @Binding var appearanceMode: AppearanceMode
    let appState: AppState

    var body: some Scene {
        // v0.24 fix (Boss 8/25 17th OOB 'hide Wenshu title'): WindowGroup
        // title set to empty string (= no NSWindow title shown). Combined
        // with .windowToolbarStyle(.unified, showsTitle: false) below for
        // canonical Apple HIG API to hide title slot in unified chrome.
        WindowGroup("") {
            // v0.21 ticket 01 (重做 #10): 撤回 SettingsEnvironmentCapturer wrapper (commit a78d758bc Q15 翻车 #11 dead code)
            // SettingsEnvironmentCapturer 之前包 LayoutShellView 注入 OpenSettingsAction, 但 openSettings?() → nil (Q15 翻车 #11), 现在 NSMenu 自己装 + 自创建 NSWindow 装 SettingView 不需要 capture
            // CHATBOX-002 (2026-09-04): wrap with CommandPaletteHost so the
            // ⌘K sheet binds to the WindowGroup scene (= the sheet
            // inherits the window's focus + key state per Apple HIG).
            CommandPaletteHost {
                SettingsEnvironmentCapturer(library: library, appearanceMode: appearanceMode)
            }
                // v0.30 boss 8/31 OOB: inject AppState at root so all
                // descendants can read cross-zone UI state via
                // `@Environment(AppState.self)`. Per-window state
                // (= owned by @State on WenshuApp struct = each
                // WindowGroup instance has its own AppState).
                .environment(appState)
        }
        // Boss 8/24 feedback: 'use the 52 PT one'. Apple SwiftUI macOS 14+ windowToolbarStyle
        // options: .automatic, .unified (52 PT), .unifiedCompact (28 PT), .expanded.
        // v0.24 fix (Boss 8/25 28th OOB 'use default size' + Apple docs):
        // use .unified (52 PT) = macOS default toolbar style. Per Apple
        // developer.apple.com/documentation/SwiftUI/WindowToolbarStyle,
        // .unified is the default style (52 PT). .unifiedCompact is
        // COMPACT (= smaller, NOT default). Boss spec 'default size' = .unified.
        // v0.28 followup Boss UX round 12 (Boss 2026-08-29 OOB '算了,
        // 本来我们也要伪 apple 官方嘛, 用 52 高的那个原生标题栏,
        // 把按钮放上面, 去掉自己写的那一栏, 全面适配液态玻璃'):
        // = adopt Apple Liquid Glass design language fully per
        // developer.apple.com/documentation/technologyoverviews/
        // liquid-glass. Use .unified (= 52 PT default macOS chrome)
        // = the full Liquid Glass titlebar experience (= traffic lights
        // + grouped toolbar items in 1 unified capsule = the macOS 26
        // Tahoe canonical look that Pages / Xcode / Mail / Finder all
        // use). Remove .toolbarBackground(.clear) (= let the default
        // Liquid Glass material render). 100% native macOS look.
        //
        // Final titlebar = 1 macOS native .unified 52 PT titlebar
        // (= Apple standard = Liquid Glass = 1 unified capsule
        // containing 8 toolbar items + traffic lights). No custom
        // chrome above or below (= fully Apple-native = '伪 apple
        // 官方' per Boss spec).
        .windowToolbarStyle(.unified)  // 52 PT default macOS chrome with Liquid Glass unified toolbar background
        // .windowToolbarStyle(.unifiedCompact(showsTitle: false))  // 28 PT compact chrome, no unified toolbar background
        .defaultSize(width: LayoutTokens.designW, height: LayoutTokens.designH)  // Boss Sketch design baseline 1920x984 PT
        // v0.24 boss验收fix: .contentMinSize (window doesn't shrink below initial
        // size, can grow to fit larger content).
        .windowResizability(.contentMinSize)
        .commands {
            // v0.40 apple-001 + boss real-device test (2026-09-07) fix:
            // removed the custom `CommandGroup(replacing: .appSettings) { Button("设置…") }`
            // block. The custom Button was duplicating the macOS system
            // "Settings..." menu item (= which is auto-rendered when the
            // App has a `Settings { ... }` scene, see L206). The
            // duplication showed as 2 menu items: "设置…" (Chinese) +
            // "Settings..." (English) in the WenshuApp menu.
            //
            // Apple HIG: the macOS standard for Settings menu is the
            // system-default "Settings..." (= Apple-localized, = Cmd+,).
            // The Settings scene below provides the actual content
            // (= SettingView, the 6-tab segmented settings panel).
            //
            // The previous custom Button was a v0.24 workaround
            // (= "Settings... menu item is required for SwiftUI
            // Settings scene to be accessible"). That workaround is
            // no longer needed (= the Settings scene at L206 is the
            // real source of the menu entry). Cmd+, opens Settings
            // automatically when the App has a Settings scene (= no
            // custom CommandGroup required).
            //
            // CHATBOX-002 (2026-09-04): ⌘K command palette (= hermes
            // commands.py + slash_registry.py parity). Replaces
            // .newItem group so ⌘K shows the palette instead of the
            // macOS-default "New File" behavior. Posts
            // .wenshuShowCommandPalette (= the SwiftUI scene listens
            // and presents the palette sheet).
            CommandGroup(replacing: .newItem) {
                Button("Open Command Palette") {
                    CommandPaletteController.show()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                // v0.27 macOS-standard cross-component sync (boss 8/27
                // OOB): File → 新建项目 is the macOS-standard menu item
                // (= Cmd+N shortcut) for the file-creation kind. Per boss
                // 8/27 standing rule 'a new feature should appear
                // everywhere = synced', this Menu mirrors the toolbar '+'
                // Menu (= 新建书 / 新建书架). Both sub-items post a
                // NotificationCenter event that NewLibraryOutlineView
                // listens for and triggers the matching sheet.
                Menu("新建项目") {
                    Button("新建书") {
                        NotificationCenter.default.post(name: .wenshuNewBookRequested, object: nil)
                    }
                    Button("新建书架") {
                        NotificationCenter.default.post(name: .wenshuNewShelfRequested, object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
                // v0.27 boss 8/27 OOB: 菜单栏同步 toolbar '导入' button.
                // Per boss 8/27 standing rule 'a new feature should
                // appear everywhere = synced', the menu bar gets a
                // matching 导入 entry (= macOS-standard File → Import
                // Convention; Cmd+Shift+I is the macOS default shortcut
                // for File → Import per developer.apple.com/design/
                // human-interface-guidelines/app-architecture/importing-
                // and-exporting-data). Functionality deferred (= '功能
                // 一会拷问后规划'); placeholder posts a
                // NotificationCenter event so v0.27 followups can
                // listen + implement.
                Button("导入…") {
                    NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销", action: {})
                    .keyboardShortcut("z", modifiers: .command)
                Button("重做", action: {})
                    .keyboardShortcut("Z", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Divider()
                // v0.24 fix (Boss 8/25 60th OOB menu bar primary): 4 zone
                // toggle menu items. Per Apple HIG Rule 1.3 (toggle
                // checkmarks for on/off states). Toggle forwards via
                // NotificationCenter to vm (= .commands block can't access
                // vm directly per L20). Static labels (= dynamic checkmark
                // would require vm access which commands lack).
                Button("显示/隐藏 项目管理区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.projectSidebar)
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])
                Button("显示/隐藏 素材预览区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.projectPreview)
                }
                Button("显示/隐藏 工具区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.specializedTools)
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])
                Button("显示/隐藏 聊天区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.aiChat)
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
                Button("显示/隐藏 动态区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.aiDynamic)
                }
                .keyboardShortcut("4", modifiers: [.command, .shift])
                Divider()
                Button("恢复默认布局") {
                    NSLog("[wenshu.reset] menu posted wenshuResetLayout")
                    NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
                Divider()
                // v0.28 ticket 028-006: Layout edit mode menu entry
                // (= ⌘⇧\ toggles edit mode on/off; per the hermes
                // sibling pattern of `view.flipPanes = mod+\` +
                // `layout.editMode = mod+shift+\`). Posts a
                // NotificationCenter event that the active
                // WorkspaceView's LayoutEditMode singleton listens
                // for and flips the bool (= the menu and the
                // in-window hotkey share the same notification
                // path so the user sees a consistent state).
                Button(WenshuI18n.t("button.layout_edit_mode")) {
                    NotificationCenter.default.post(name: .wenshuToggleEditMode, object: nil)
                }
                .keyboardShortcut(KeyEquivalent("\\"), modifiers: [.command, .shift])
            }
        }
        Settings {
            SettingView()
        }
        // B-11: inject AppState into the Settings scene so
        // SettingView's `@Environment(AppState.self) private var
        // appState` lookup (= appState.llmModel on the model picker
        // binding) doesn't assert-fail when the user opens Settings
        // via ⌘,. Without this, opening Settings crashed in
        // `_assertionFailure` from `EnvironmentValues.subscript.getter`
        // because the Settings scene had no `.environment(appState)`
        // modifier (= only the WindowGroup's content view had one).
        .environment(appState)
    }
}
