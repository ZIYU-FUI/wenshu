//
//  LibraryRootView.swift · Wenshu · v0.24 boss验收
//
//  Boss 2026-08-24 OOB 拍: '和 FCP 一样, 首次运行, 无论是否要建书架,
//  都要先指定一个 .ws 文件的库文件位置' (tactical UX 拍板).
//  Boss 8/24 follow-up: '文字不要带有我们的决策, 什么和 FCP 一样.
//  就直接说, 这个库文件的做用. 也不用说库用件叫 .ws.
//  就说让客户指定一个文枢仓库'.
//
//  User-facing text (per boss 拍): no decision words (和 FCP 一样, 比 X 好,
//  etc.), no .ws 库 件术语, just describe the purpose. Use '文枢仓库'
//  terminology.
//
//  Apple HIG 参考: 1 个 library file = 1 个 .lrlibrary (Lightroom) /
//  .photoslibrary (Photos) / .fcpbundle (FCP). Boss 拍 wenshu 用 '仓库'.
//  Selected path stored in UserDefaults 'wenshu.libraryPath'.
//
//  LibraryRootView behavior:
//  1. If 'wenshu.libraryPath' NOT set → show LibraryOnboardingView (NSOpenPanel)
//  2. If 'wenshu.libraryPath' set → show LayoutShellView (main app)
//  3. User can change library via Settings → '更换仓库' button (future)
//
//  文枢仓库 folder structure (planned for ticket 5):
//  - 仓库根/             = the 仓库 (selected location)
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
/// Trigger condition (Boss 8/24 OOB 拍: '如果持久化信息没有库文件信息,
/// 就需要进到建库选库页面'):
/// - if UserDefaults 'wenshu.libraryPath' empty → onboarding
/// - if UserDefaults 'wenshu.libraryPath' set but path doesn't exist
///   on disk (= 老板 deleted 仓库 externally, or 仓库 was on a now-disconnected
///   drive) → onboarding (re-pick)
/// - else (= path set + path exists) → main app LayoutShellView
public struct LibraryRootView: View {
    @AppStorage("wenshu.libraryPath") private var libraryPath: String = ""

    private var shouldShowOnboarding: Bool {
        // v0.24 boss验收fix (Boss 8/24 OOB): trigger condition strict.
        //
        // Boss 拍 'anbaiqiang.ws' = wenshu 仓库 = .ws directory (= per v0.26 spec ticket 015,
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
            }
        }
    }
}

/// v0.27 wiring wrapper (= isolated to keep LibraryRootView's body
/// simple). Constructs the BookStore via LibraryLifecycleHook and
/// provides it via @Environment.
private struct WiredShell: View {
    let libraryPath: String
    @State private var bookStore: BookStore?
    // v0.27 ticket 027-34 (= boss 8/27 grill D1 'Xcode paradigm +
    // user-customizable layout'): feature flag toggles between the
    // legacy LayoutShellView and the new WorkspaceView (= wraps the
    // WorkspaceStore).
    // v0.30 boss 8/30 OOB: '我看截图, 你把库管理顶栏右边的新建和导入按钮
    // 改掉了' = trailing 新建/导入 buttons were MISSING in LayoutShellView
    // path's screenshots because LayoutShellView uses ZoneModule (=
    // no ZoneContentView trailingButton slot). Flipping default to
    // true = WorkspaceView path (= has ZoneContentView trailingButton
    // wiring per App.swift:2626 + v0.27 commit bca226704) = trailing
    // buttons render correctly.
    // v0.30 boss 8/31 OOB: removed the legacy useWorkspace toggle
    // (= no Settings/View writes to the AppStorage flag, so it was
    // always-true dead code). WorkspaceStore is constructed once
    // per WiredShell lifetime; its UserDefaults round-trip preserves
    // state across launches.
    @State private var workspaceStore: WorkspaceStore? = nil
    // v0.28 followup Boss UX round 4: zone visibility flags (= for the
    // macOS native toolbar zone toggle buttons). Mirrors LayoutShellView's
    // @AppStorage declarations (= same UserDefaults keys so state is
    // shared across paths).
    @AppStorage("wenshu.zoneVisible.projectSidebar") private var showProjectSidebar: Bool = true
    @AppStorage("wenshu.zoneVisible.projectPreview") private var showProjectPreview: Bool = true
    @AppStorage("wenshu.zoneVisible.specializedTools") private var showSpecializedTools: Bool = true
    @AppStorage("wenshu.zoneVisible.aiChat") private var showAIChat: Bool = true
    @AppStorage("wenshu.zoneVisible.aiDynamic") private var showAIDynamic: Bool = true
    // v0.28 followup Boss UX round 4: model name (= for the model picker
    // icon in the macOS native toolbar). Mirrors SettingsEnvironmentCapturer's
    // modelName definition (= same UserDefaults key "wenshu.llm.model").
    @AppStorage("wenshu.llm.model") private var modelName: String = "MiniMax-M3"

    var body: some View {
        Group {
            if let bookStore = bookStore {
                // WorkspaceView path (= v0.28 followup).
                // WorkspaceStore is constructed once per
                // WiredShell lifetime (= a new instance per
                // window); its UserDefaults round-trip preserves
                // state across launches.
                if workspaceStore == nil {
                    // Defer to a single task so we don't mutate
                    // @State during view update.
                    Color.clear
                        .task { workspaceStore = WorkspaceStore() }
                } else if let workspaceStore = workspaceStore {
                    WorkspaceView(store: workspaceStore)
                        .environment(bookStore)
                }
            } else {
                ProgressView("正在启动文枢…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
// v0.28 followup Boss UX round 13 (Boss 2026-08-29 OOB '没有
        // 分组, 分好组'): Use ToolbarItemGroup(= segmented Liquid
        // Glass capsule per group, the canonical macOS 26 Tahoe
        // pattern). Each group = 1 visually-grouped capsule with a
        // gap between groups (= matches Apple Pages / Xcode / Finder
        // toolbar style exactly). 3 groups:
        // - Group 1: 5 zone toggles (sidebar/preview/tools/chat/dynamic)
        // - Group 2: model picker (= separate capsule after the zone-toggle group)
        // - Group 3: export (= rightmost, third capsule)
        // v0.30 boss 2026-09-01 OOB (zone toggle fix): the 5 toolbar
        // zone-toggle buttons below were toggling only the @AppStorage
        // booleans (= button tint flipped but the NSSplitView layout
        // never reacted, because nothing read those keys). The actual
        // hide/show is driven by `.wenshuToggleZone` notifications
        // (= PaneNSController.swift:390 handleToggleZone matches the
        // NSSplitViewItem by TabKind and flips `isCollapsed`). The fix
        // = post the notification in addition to toggling the binding,
        // so both the persistent state AND the live layout stay in
        // sync (= button tint = persisted bool = collapsed state).
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showProjectSidebar.toggle()
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.projectSidebar)
                } label: {
                    LucideIconSystemFallback("sidebar.left", size: LayoutTokens.iconSize)
                }
                .foregroundStyle(showProjectSidebar ? Color.accentColor : Color.secondary)
                .help(showProjectSidebar ? "隐藏 项目管理区" : "显示 项目管理区")
                Button {
                    showProjectPreview.toggle()
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.projectPreview)
                } label: {
                    LucideIconSystemFallback("eye.fill", size: LayoutTokens.iconSize)
                }
                .foregroundStyle(showProjectPreview ? Color.accentColor : Color.secondary)
                .help(showProjectPreview ? "隐藏 素材预览区" : "显示 素材预览区")
                Button {
                    showSpecializedTools.toggle()
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.specializedTools)
                } label: {
                    LucideIconSystemFallback("wrench.and.screwdriver", size: LayoutTokens.iconSize)
                }
                .foregroundStyle(showSpecializedTools ? Color.accentColor : Color.secondary)
                .help(showSpecializedTools ? "隐藏 工具区" : "显示 工具区")
                Button {
                    showAIChat.toggle()
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.aiChat)
                } label: {
                    LucideIconSystemFallback("bubble.left", size: LayoutTokens.iconSize)
                }
                .foregroundStyle(showAIChat ? Color.accentColor : Color.secondary)
                .help(showAIChat ? "隐藏 聊天区" : "显示 聊天区")
                Button {
                    showAIDynamic.toggle()
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.aiDynamic)
                } label: {
                    LucideIconSystemFallback("chart.bar", size: LayoutTokens.iconSize)
                }
                .foregroundStyle(showAIDynamic ? Color.accentColor : Color.secondary)
                .help(showAIDynamic ? "隐藏 动态区" : "显示 动态区")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { WenshuAppDelegate.openSettings?() } label: {
                    LucideIconSystemFallback("cpu", size: LayoutTokens.iconSize)
                }
                .help("模型: \(modelName)")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { NotificationCenter.default.post(name: .wenshuExportRequested, object: nil) } label: {
                    LucideIconSystemFallback("square.and.arrow.up", size: LayoutTokens.iconSize)
                }
                .help("导出电子书 (PDF / EPUB / MOBI / TXT)")
            }
        }
        // NOTE: v0.28 followup Boss UX round 11 attempted to remove
        // the Liquid Glass capsule by passing .toolbarBackground(.clear,
        // for: .windowToolbar). Boss round 12 overruled that (= decided
        // to fully adopt Liquid Glass per Apple design language). The
        // default Liquid Glass background now renders behind the
        // toolbar items (= canonical macOS 26 Tahoe look matching
        // Pages / Xcode / Mail / Finder).

        // NOTE: v0.28 followup Boss UX round 11 attempted to remove
        // the Liquid Glass capsule by passing .toolbarBackground(.clear,
        // for: .windowToolbar). Boss round 12 overruled that (= decided
        // to fully adopt Liquid Glass per Apple design language). The
        // default Liquid Glass background now renders behind the
        // toolbar items (= canonical macOS 26 Tahoe look matching
        // Pages / Xcode / Mail / Finder).
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
            .frame(width: 192, height: 192)
    } else {
        // Fallback: SF Symbol if PNG load fails
        Image(systemName: "text.book.closed")
            .font(.system(size: 96))
            .foregroundStyle(.white)
    }
}

            VStack(spacing: 12) {
                Text("欢迎使用文枢")
                    .font(.title.weight(.semibold))
                Text("请指定文枢仓库的位置")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("文枢会把你的书架、聊天记录、看板、任务、资产都保存在这个仓库里。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                // v0.24 boss验收fix (Boss 8/24 反馈: '文字不要带有我们的决策'):
                // - 2 buttons = 新建 / 打开 (标准 macOS 范式, not 决策描述)
                // - 文案 不用 '库' / '.ws' / 'Final Cut Pro' (boss 拍 不要带决策)
                // - boss 拍 '让客户指定一个文枢仓库' → primary text = '新建文枢仓库'
                Button {
                    showSavePanel()
                } label: {
                    Label("新建文枢仓库", systemImage: "doc.badge.plus")
                        .frame(width: 240, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showOpenPanel()
                } label: {
                    Label("打开已有文枢仓库", systemImage: "folder")
                        .frame(width: 240, height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text("新建 = 创建新仓库, 打开 = 选择已有仓库")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // v0.28 followup Boss UX round 21: .background(.regularMaterial)
        // (= Liquid Glass) for the onboarding empty state — matches
        // all other chrome.
        .background(.regularMaterial)
    }

    /// showOpenPanel: NSOpenPanel for selecting existing .ws directory.
    /// v0.26 amendment: .ws is now a DIRECTORY (= macOS-style package;
    /// LibraryRootView.swift:296-309 creates Info.plist inside it).
    /// Boss 8/24 OOB original: .ws file is the 仓库 format.
    /// Boss 8/26 OOB clarification: .ws is the package directory containing
    /// shelves/ + reference-library/ + cache/ + Info.plist + chat.sqlite.
    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "打开已有文枢仓库"
        panel.message = "选择一个现有的文枢仓库目录"
        panel.prompt = "打开"
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
        panel.title = "新建文枢仓库"
        panel.message = "选择一个位置保存你的文枢仓库"
        panel.prompt = "创建"
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

