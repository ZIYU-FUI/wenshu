//
//  LibraryRootView.swift · Wenshu · v0.24 boss acceptance
//
//  Boss 2026-08-24 OOB said: 'like FCP, on first run, whether or not to create a shelf,
//  must first specify a .ws file library location' (tactical UX decision).
//  Boss 8/24 follow-up: 'text shouldn't contain our decisions, like "like FCP".
//  Just say directly, what this library file is for. Also don't say the library file is called .ws.
//  Just say ask the user to specify a Wenshu repository'.
//
//  User-facing text (per boss said): no decision words (like FCP, better than X,
//  etc.), no .ws library file terminology, just describe the purpose. Use 'Wenshu repository'
//  terminology.
//
//  Apple HIG reference: 1 library file = 1 .lrlibrary (Lightroom) /
//  .photoslibrary (Photos) / .fcpbundle (FCP). Boss said wenshu uses 'repository'.
//  Selected path stored in UserDefaults 'wenshu.libraryPath'.
//
//  LibraryRootView behavior:
//  1. If 'wenshu.libraryPath' NOT set → show LibraryOnboardingView (NSOpenPanel)
//  2. If 'wenshu.libraryPath' set → show LayoutShellView (main app)
//  3. User can change library via Settings → '更换仓库' button (future)
//
//  Wenshu repository folder structure (planned for ticket 5):
//  - repository root/             = the repository (selected location)
//  - shelves/             = book shelves (sub-libraries)
//  - books/               = individual book content (.md)
//  - chat.sqlite          = chat history
//  - kanban.sqlite        = kanban board
//  - todo.sqlite          = todo list
//  - assets/              = images, attachments
//  - chapters/            = book chapters (long-form content)
//  - backups/             = auto-generated backups
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// LibraryRootView: Routes between onboarding (first launch) and main app.
///
/// Trigger condition (Boss 8/24 OOB said: 'if persistent info has no library file info,
/// need to go to library-creation/library-selection page'):
/// - if UserDefaults 'wenshu.libraryPath' empty → onboarding
/// - if UserDefaults 'wenshu.libraryPath' set but path doesn't exist
///   on disk (= boss deleted repository externally, or repository was on a now-disconnected
///   drive) → onboarding (re-pick)
/// - else (= path set + path exists) → main app LayoutShellView
public struct LibraryRootView: View {
    @AppStorage("wenshu.libraryPath") private var libraryPath: String = ""

    private var shouldShowOnboarding: Bool {
        // v0.24 boss acceptance fix (Boss 8/24 OOB): trigger condition strict.
        //
        // Boss said 'anbaiqiang.ws' = wenshu repository = .ws directory (= per v0.26 spec ticket 015,
        // .ws is now a macOS-style package directory, NOT a single file;
        // LibraryRootView.swift:296-309 creates Info.plist inside it).
        //
        // Trigger = libraryPath empty OR path doesn't end with '.ws' OR
        // .ws directory doesn't exist on disk.
        //
        // v0.24 boss验收fix #2 (Boss 8/24 OOB follow-up): 之前 trigger only
        // checked path existence, too lax. Boss 之前 saved '/Users/anbaiqiang/Documents'
        // (= parent folder, not anbaiqiang.ws file) → existed on disk → trigger
        // passed → main UI shown, even though no .ws file 实际 created.
        // v0.26 amendment: .ws is a DIRECTORY (not file); require path ends
        // with '.ws' AND directory exists AND Info.plist is readable.
        if libraryPath.isEmpty { return true }
        // v0.24 boss验收fix: must end with .ws extension
        if !libraryPath.hasSuffix(".ws") { return true }
        // Directory must exist (v0.26: .ws is a directory, not a file)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: libraryPath, isDirectory: &isDir)
        if !exists { return true }
        if !isDir.boolValue { return true }
        // v0.26: Info.plist must be readable (= WSSchemaVersion check)
        let infoPlistURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("Info.plist")
        if !FileManager.default.isReadableFile(atPath: infoPlistURL.path) { return true }
        return false
    }

    public var body: some View {
        Group {
            if shouldShowOnboarding {
                LibraryOnboardingView(onLibraryPicked: { url in
                    libraryPath = url.path
                })
            } else {
                // v0.27 wiring: run the LibraryLifecycleHook at layout entry.
                // - LibraryMigrator.migrateIfNeeded (= v0.x → v0.26)
                // - LibraryBootstrapper.ensureValidStructure (= self-heal)
                // - Construct LibraryStores + BookStore (= single @Observable)
                // - Inject BookStore via .environment for LayoutShellView + child views
                WiredShell(libraryPath: libraryPath)
                    // v0.40 boss 9/7 OOB '这个功能, 应该在聊天区的对话框
                    // 使用. 这个提示, 应该在 /help 里呈现': removed the
                    // top banner (= ChatBookManagerHint was a hint
                    // above the workspace, telling users to type
                    // slash commands in the chat zone). Boss wants
                    // the chat zone to be the SOLE input surface for
                    // slash commands (= no duplicate hint above the
                    // workspace). The hint text (= "Tell the chat
                    // to create a book: e.g. /create-book My new
                    // novel") moves to the .help() modifier on the
                    // chat TextField (= macOS NSHelpManager tooltip
                    // on hover, = Apple HIG canonical "explainer
                    // tooltip" pattern). The ChatBookManagerHint
                    // struct itself is deleted (= no longer
                    // instantiated).
            }
        }
    }
}

/// v0.40 boss 9/7 OOB '这个功能, 应该在聊天区的对话框使用. 这个
/// 提示, 应该在 /help 里呈现': ChatBookManagerHint deleted (= top
/// banner removed in the same commit). The slash-command hint
/// moves to the .help() modifier on the chat TextField (= macOS
/// NSHelpManager tooltip on hover; = Apple HIG canonical
/// "explainer tooltip" pattern, = non-intrusive but always
/// available on demand).

/// v0.27 wiring wrapper (= isolated to keep LibraryRootView's body
/// simple). Constructs the BookStore via LibraryLifecycleHook and
/// provides it via @Environment.
private struct WiredShell: View {
    let libraryPath: String
    // CHATZONE-CRASH-FIX (2026-09-08, post-docs-check):
    // Apple HIG canonical guidance is that NavigationSplitView typically
    // is used as the root view in a Scene. When nested under
    // WorkspaceView.body (= the prior M1 implementation), child column
    // views crash with 'No Observable object of type AppState found'
    // on @Environment lookup. Fix = promote the NavigationSplitView to
    // the Scene root (= here, inside WiredShell.body, which is what
    // LibraryRootView embeds directly).
    @Environment(AppState.self) private var appState
    @State private var bookStore: BookStore?
    // v0.27 ticket 027-34 (= boss 8/27 grill D1 'Xcode paradigm +
    // user-customizable layout'): feature flag toggles between the
    // legacy LayoutShellView and the new WorkspaceView (= wraps the
    // LayoutTreeStore).
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    // v0.30 boss 8/30 OOB: '我看截图, 你把库管理顶栏右边的新建和导入按钮
    // 改掉了' = trailing 新建/导入 buttons were MISSING in LayoutShellView
    // path's screenshots because LayoutShellView uses ZoneModule (=
    // no ZoneContentView trailingButton slot). Flipping default to
    // true = WorkspaceView path (= has ZoneContentView trailingButton
    // wiring per App.swift:2626 + v0.27 commit bca226704) = trailing
    // buttons render correctly.
    // v0.30 boss 8/31 OOB: removed the legacy useWorkspace toggle
    // (= no Settings/View writes to the AppStorage flag, so it was
    // always-true dead code). LayoutTreeStore is constructed once
    // per WiredShell lifetime; its UserDefaults round-trip preserves
    // state across launches.
    @State private var workspaceStore: LayoutTreeStore? = nil
    // v0.28 followup Boss UX round 4: zone visibility flags (= for the
    // macOS native toolbar zone toggle buttons). Mirrors LayoutShellView's
    // @AppStorage declarations (= same UserDefaults keys so state is
    // shared across paths).
    // B-05: `wenshu.zoneVisible.*` are now owned by LayoutTreeStore
    // (single source of truth). The 5 @AppStorage declarations below
    // were dead (= the hand-rolled toolbar block that toggled them
    // was removed by the v0.34 toolbar flatten). The actual
    // hide/show is driven by `.wenshuToggleZone` notifications read
    // by `PaneNSController.applyPersistedZoneVisibility()` at startup
    // (= reads UserDefaults directly, no SwiftUI property wrapper
    // dance on the AppKit side) and `LayoutTreeStore.resetToDefault()`
    // clears them on '恢复默认布局'.
    //
    // v0.28 followup Boss UX round 4: model name (= for the model picker
    // icon in the macOS native toolbar). Mirrors SettingsEnvironmentCapturer's
    // modelName definition (= same UserDefaults key "wenshu.llm.model").
    // B-05: `wenshu.llm.model` now has a single owner =
    // AppState.llmModel. The dead `modelName` @AppStorage declaration
    // (= removed by the v0.34 toolbar flatten) is dropped. The model
    // picker reads `appState.llmModel` directly via
    // `@Environment(AppState.self)`.

    var body: some View {
        Group {
            if appState.useThreeColumnSplit {
                // CHATZONE-CRASH-FIX part 2 (2026-09-08): defer rendering
                // NavigationSplitShell until BookStore is constructed
                // (= descendants like ForeshadowingView / PlaceholderView
                // / PreviewPane read @Environment(BookStore.self)
                // non-optional; = SwiftUI crashes if BookStore is
                // missing from env at layout time). LibraryLifecycleHook
                // constructs BookStore asynchronously (= nil at first
                // frame; = we show a ProgressView until ready).
                if let bookStore = bookStore {
                    NavigationSplitShell(appState: appState, bookStore: bookStore)
                        // CHATZONE-CRASH-FIX (2026-09-08): re-inject AppState
                        // into NavigationSplitView's column env. NavigationSplitView
                        // re-roots each column view in its own env subgraph
                        // (= the @Environment chain is broken at the column
                        // boundary for @Observable types). Re-injecting via
                        // .environment(appState) at the column-root level
                        // restores the chain so ChatZoneView / ZoneModuleView /
                        // NewLibraryOutlineView can read appState from env
                        // (= previously crashed with 'No Observable object of
                        // type AppState found' at Environment+Objects.swift:34).
                        .environment(appState)
                        // CHATZONE-CRASH-FIX part 2b: also re-inject bookStore
                        // explicitly (= NavigationSplitView's internal
                        // layout engine reads env values during
                        // makeSplitViewController; = without this
                        // re-injection, the env chain fails at
                        // _FlexFrameLayout.sizeThatFits with 'No
                        // Observable object of type BookStore found').
                        .environment(bookStore)
                } else {
                    ProgressView("正在启动文枢…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // 老 PaneSplitHost path (= unchanged; = the WorkspaceView
                // View is unchanged from M1).
                Group {
                    if let bookStore = bookStore {
                        // WorkspaceView path (= v0.28 followup).
                        // LayoutTreeStore is constructed once per
                        // WiredShell lifetime (= a new instance per
                        // window); its UserDefaults round-trip preserves
                        // state across launches.
                        if workspaceStore == nil {
                            // Defer to a single task so we don't mutate
                            // @State during view update.
                            Color.clear
                                .task { workspaceStore = LayoutTreeStore() }
                        } else if let workspaceStore = workspaceStore {
                            WorkspaceView(store: workspaceStore)
                                .environment(bookStore)
                                // Same env-chain fix (= see above).
                                .environment(appState)
                        }
                    } else {
                        ProgressView("正在启动文枢…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .task {
            await runLaunch()
        }
    }

    @MainActor
    private func runLaunch() async {
        let wsRoot = URL(fileURLWithPath: libraryPath)
        let hook = LibraryLifecycleHook(wsRoot: wsRoot)
        do {
            let result = try hook.runLaunch()
            self.bookStore = result.makeBookStore()
            // B-07 015.019 (boss 2026-09-04 OOB '往后推进'):
            // populate the reactive `books` mirror at launch so
            // `bookStore.books.count` (= the sidebar bottom-status
            // "书: N" source) is correct on the first render.
            self.bookStore?.reloadAllBooks()
        } catch {
            // v0.27 MVP: log + show alert would be ideal; for now,
            // fall back to a layout shell without the BookStore so the
            // user sees the app rather than a blank screen.
            #if DEBUG
            print("LibraryLifecycleHook failed: \(error)")
            #endif
        }
    }
}



/// v0.24 boss验收fix: NSImage load helper (for PNG not in .xcassets).
/// Searches multiple paths in .app bundle for wenshu-original-fanbai.png.
private func loadWenshuLogo() -> NSImage? {
    // Build process: Package.swift copies AppIcon.icon/ → Wenshu.app/Contents/Resources/AppIcon.icon/
    // AppIcon.icon contains icon.json (Apple Icon Composer format) and Assets/ subdir.
    let paths = [
        // 1. Subdirectory: Resources/AppIcon.icon/Assets/wenshu-original-fanbai.png
        Bundle.main.url(forResource: "wenshu-original-fanbai", withExtension: "png",
                        subdirectory: "AppIcon.icon/Assets"),
        // 2. Root of bundle: Resources/wenshu-original-fanbai.png
        Bundle.main.url(forResource: "wenshu-original-fanbai", withExtension: "png"),
        // 3. Source path (for swift run debug): Sources/WenshuApp/Resources/AppIcon.icon/Assets/
        URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Resources/AppIcon.icon/Assets/wenshu-original-fanbai.png"),
    ]
    for path in paths {
        if let url = path, let nsImage = NSImage(contentsOf: url) {
            return nsImage
        }
    }
    return nil
}

/// LibraryOnboardingView: First-launch .ws file picker (NSOpenPanel).
/// Shows welcome + '选择 .ws 库' button. User must select or create a
/// .ws file location (FCP-style event library UX).
public struct LibraryOnboardingView: View {
    let onLibraryPicked: (URL) -> Void

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

// v0.24 boss验收fix (Boss 8/24 OOB): 红框 (books.vertical) 替换成文枢 LOGO.
// Boss 拍 '我是说这个文件' (= use wenshu-original-fanbai.png directly).
// .colorInvert() converts 灰-blue ink to white text. .resizable +
// .aspectRatio keeps aspect ratio.
//
// Why NSImage(contentsOf:) not Image("wenshu-original-fanbai"):
//   Package.swift copies entire AppIcon.icon/ folder to .app bundle, but
//   SwiftUI Image("name") only finds images in .xcassets or main bundle
//   root, NOT in subdirectories. So Image("wenshu-original-fanbai")
//   returns empty (= "没有内容" = no icon visible). Use NSImage(contentsOf:)
//   to load PNG from absolute path inside .app bundle.
Group {
    if let nsImage = loadWenshuLogo() {
        // v0.24 boss验收fix (Boss 8/24 OOB): '不是白色字' = show the
        // PNG as-is (gray-blue calligraphic ink), don't .colorInvert.
        // .colorMultiply(.white) makes the ink truly white
        // (consistent across light/dark mode).
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: DesignTokens.coverThumbnailSize, height: DesignTokens.coverThumbnailSize)
    } else {
        // Fallback: Lucide canonical if PNG load fails (boss 2026-09-02: SF Symbol fully replaced)
        LucideIconSystemFallback("text.book.closed", size: 96)
            .foregroundStyle(.white)
    }
}

            VStack(spacing: 12) {
                Text(WenshuI18n.t("auto.libraryrootview.l366.h45346224"))
                    .font(.title.weight(.semibold))
                Text(WenshuI18n.t("onboarding.library.choose_location"))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(WenshuI18n.t("onboarding.library.welcome_blurb"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                    .padding(.horizontal, DesignTokens.chromePaddingXLarge)
            }

            VStack(spacing: 12) {
                // v0.24 boss验收fix (Boss 8/24 反馈: '文字不要带有我们的决策'):
                // - 2 buttons = 新建 / 打开 (标准 macOS 范式, not 决策描述)
                // - 文案 不用 '库' / '.ws' / 'Final Cut Pro' (boss 拍 不要带决策)
                // - boss 拍 '让客户指定一个文枢仓库' → primary text = '新建文枢仓库'
                Button {
                    showSavePanel()
                } label: {
                    Label(WenshuI18n.t("auto2.libraryrootview.l387.h40947105"), systemImage: "doc.badge.plus")
                        .frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showOpenPanel()
                } label: {
                    Label(WenshuI18n.t("auto2.libraryrootview.l396.h53178210"), systemImage: "folder")
                        .frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text(WenshuI18n.t("onboarding.library.new_vs_open"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // v0.40 boss real-device test 2026-09-07: removed
        // .regularMaterial (= Liquid Glass onboarding background);
        // now uses Color.clear (= no background).
        .background(Color.clear)
    }

    /// showOpenPanel: NSOpenPanel for selecting existing .ws directory.
    /// v0.26 amendment: .ws is now a DIRECTORY (= macOS-style package;
    /// LibraryRootView.swift:296-309 creates Info.plist inside it).
    /// Boss 8/24 OOB original: .ws file is the 仓库 format.
    /// Boss 8/26 OOB clarification: .ws is the package directory containing
    /// shelves/ + reference-library/ + cache/ + Info.plist + chat.sqlite.
    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = WenshuI18n.t("auto2.libraryrootview.l424.h53178210")
        panel.message = WenshuI18n.t("auto2.libraryrootview.l425.h5152056")
        panel.prompt = WenshuI18n.t("auto2.libraryrootview.l426.h19738884")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = false
        if #available(macOS 11.0, *) {
            // v0.30 boss 2026-09-01 OOB (UTI filter): was `[]` (= default
            // filter hid .ws package directories on macOS 27 Tahoe).
            // Now explicitly allow the exported UTI from
            // Info.plist's UTExportedTypeDeclarations (= surfaces
            // .ws packages with the wenshu bundle icon).
            if let wsType = UTType("com.wenshu.workspace") {
                panel.allowedContentTypes = [wsType]
            } else {
                // Fallback: no filter (= shows everything, user can
                // navigate manually). Better than default which hides
                // the .ws packages.
                panel.allowedContentTypes = []
            }
        }

        if let window = NSApp.mainWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    onLibraryPicked(url)
                }
            }
        } else {
            if panel.runModal() == .OK, let url = panel.url {
                onLibraryPicked(url)
            }
        }
    }

    /// showSavePanel: NSSavePanel for new .ws package directory.
    /// v0.26 amendment: .ws is now a package DIRECTORY (= boss 8/26 OOB
    /// 'library-public / cross-book shared' model). The NSSavePanel still
    /// takes a "filename" but createWenshuWorkspace creates a directory
    /// at that name (no .ws file inside).
    /// Boss 8/24 OOB 拍: '.ws 默认的文件名, 取用户电脑的用户名.
    /// 我的电脑应该是 anbaiqiang. 所以建出来的文件应该叫 anbaiqiang.ws'
    /// = default name = NSUserName() (Apple API for current Mac username).
    /// Apple HIG 'create new package' pattern (NSSavePanel with default name).
    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.title = WenshuI18n.t("auto2.libraryrootview.l472.h40947105")
        panel.message = WenshuI18n.t("auto2.libraryrootview.l473.h20911334")
        panel.prompt = WenshuI18n.t("auto2.libraryrootview.l474.h92696757")
        // v0.24 boss验收fix (Boss 8/24 OOB): default filename = NSUserName() + ".ws"
        // NSUserName() = current Mac username (Apple API, returns "anbaiqiang"
        // on 老板's machine). Boss 拍 '我的电脑应该是 anbaiqiang'.
        let username = NSUserName()
        panel.nameFieldStringValue = "\(username).ws"
        panel.nameFieldLabel = "仓库名"
        panel.showsTagField = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        // Boss 拍 '不用说库用件叫 .ws' (no .ws in user-facing text) but the
        // .ws package IS .ws (technical package format, like .photoslibrary
        // or .fcpbundle). Show extension so user sees what they're creating.
        if #available(macOS 11.0, *) {
            panel.canSelectHiddenExtension = true
            panel.allowedContentTypes = []
        }

        // v0.24 boss验收fix (Boss 8/24 OOB '点了创建, 不成功'): NSSavePanel
        // returns URL on OK but does NOT actually create the directory.
        // For .ws registered as com.apple.package (= Finder bundle),
        // caller must create the package directory. Call createWenshuWorkspace
        // (at:) to make package + Info.plist + subdirs on disk.
        let handle: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url = panel.url {
                Self.createWenshuWorkspace(at: url)
                onLibraryPicked(url)
            }
        }
        if let window = NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

// MARK: - Bundle creation helper (Boss 8/24 OOB fix)

}  // close LibraryOnboardingView struct

extension LibraryOnboardingView {
    /// createWenshuWorkspace: explicitly create the package directory at url
    /// (NSSavePanel may not create the directory if Info.plist registration
    /// isn't fully loaded by Finder). Also create initial subdirs for
    /// 文枢 仓库 (= shelves/ books/ chat.sqlite kanban.sqlite todo.sqlite).
    static func createWenshuWorkspace(at url: URL) {
        let fm = FileManager.default
        // 1. Create root package directory if not exists
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        // 2. Create subdirs (shelves/, books/, chapters/, assets/, backups/)
        let subdirs = ["shelves", "books", "chapters", "assets", "backups"]
        for sub in subdirs {
            let subURL = url.appendingPathComponent(sub)
            if !fm.fileExists(atPath: subURL.path) {
                try? fm.createDirectory(at: subURL, withIntermediateDirectories: true)
            }
        }
        // 3. Create initial Info.plist inside package (Apple HIG pattern for
        // custom bundles; declares what package type this is)
        let infoPlistURL = url.appendingPathComponent("Info.plist")
        if !fm.fileExists(atPath: infoPlistURL.path) {
            let plist: [String: Any] = [
                "CFBundleIdentifier": "com.wenshu.\(url.deletingPathExtension().lastPathComponent)",
                "CFBundleName": url.deletingPathExtension().lastPathComponent,
                "CFBundlePackageType": "WSPC",
                "CFBundleShortVersionString": "0.24.0",
                "CFBundleVersion": "1",
                "WSPCreatedAt": ISO8601DateFormatter().string(from: Date()),
            ]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? data.write(to: infoPlistURL)
            }
        }
        // v0.24 boss验收fix (Boss 8/24 OOB '这个文件没有自己的图标, 可以用文枢的 LOGO 不'):
        // Set the wenshu LOGO PNG as the Finder icon for the .ws package.
        // Apple HIG: NSWorkspace.shared.setIcon(_:forFile:options:) writes
        // icon into the file's resource fork / icon services metadata.
        // v0.24 boss验收fix (Boss 8/24 OOB '换一个吧, 用 SF 里的实心的书吧, 先用着, 回头再设计'):
        // Use SF Symbol fill book icon (= book.fill) instead of wenshu LOGO PNG.
        // Per Apple HIG: SF Symbol fill variant for package icon.
        // Render SF Symbol to NSImage at 1024x1024, then setIcon.
        if let symbolImage = renderSFSymbol("book.fill", size: 1024) {
            let workspace = NSWorkspace.shared
            let success = workspace.setIcon(symbolImage, forFile: url.path, options: [])
            NSLog("[wenshu.library] icon set=%@ for: %@", success ? "yes" : "no", url.path)
        } else if let logoImage = loadWenshuLogoForIcon() {
            // Fallback to wenshu LOGO if SF Symbol render fails
            logoImage.size = NSSize(width: 1024, height: 1024)
            let workspace = NSWorkspace.shared
            let success = workspace.setIcon(logoImage, forFile: url.path, options: [])
            NSLog("[wenshu.library] icon set=%@ (fallback LOGO) for: %@", success ? "yes" : "no", url.path)
        }
        NSLog("[wenshu.library] created package: %@", url.path)
    }

    /// v0.24 boss验收fix: render an SF Symbol to NSImage at given size.
    /// Used for setting Finder icons on .ws packages (per Boss 8/24 OOB).
    /// Apple HIG: SF Symbol fill variant for package icons.
    static func renderSFSymbol(_ name: String, size: CGFloat) -> NSImage? {
        // Use NSImage(systemSymbolName:) for SF Symbol loading.
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: name) else {
            NSLog("[wenshu.library] SF Symbol not found: %@", name)
            return nil
        }
        image.size = NSSize(width: size, height: size)
        return image
    }

    /// v0.24 boss验收fix: load the wenshu LOGO PNG for use as Finder icon.
    /// Searches multiple paths in priority order (Bundle.main → absolute path).
    static func loadWenshuLogoForIcon() -> NSImage? {
        let paths = [
            Bundle.main.url(forResource: "wenshu-original-fanbai", withExtension: "png",
                            subdirectory: "AppIcon.icon/Assets"),
            Bundle.main.url(forResource: "wenshu-original-fanbai", withExtension: "png"),
            URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Resources/AppIcon.icon/Assets/wenshu-original-fanbai.png"),
        ]
        for path in paths {
            if let url = path, let nsImage = NSImage(contentsOf: url) {
                return nsImage
            }
        }
        return nil
    }
}

