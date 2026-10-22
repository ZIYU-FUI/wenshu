// 
// … (= 27 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WenshuData
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "libraryrootview")

// / LibraryRootView: Routes between onboarding (first launch) and main app.
// … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / - else (= path set + path exists) → main app AppRootScene
struct LibraryRootView: View {
    // LibraryRootView now owns the library + appearance
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // WindowGroup (= single source of truth = AppRootScene).
    let library: WenshuLibrary
    let appearanceMode: AppearanceMode

    // Active library path (= canonical single source of truth via
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // replaced it with the canonical accessor.
    private var activeLibraryPath: String? {
        activeLibrarySelection ?? ActiveLibrary.path
    }

    init(library: WenshuLibrary, appearanceMode: AppearanceMode) {
        self.library = library
        self.appearanceMode = appearanceMode
    }

    private var shouldShowOnboarding: Bool {
        // wenshu-acceptance-fix: trigger condition strict.
        // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // with '.ws' AND directory exists AND Info.plist is readable.
        if (activeLibraryPath ?? "").isEmpty { return true }
        // bossverificationfix: must end with .ws extension
        if !(activeLibraryPath ?? "").hasSuffix(".ws") { return true }
        // Directory must exist (v0.26: .ws is a directory, not a file)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: activeLibraryPath ?? "", isDirectory: &isDir)
        if !exists { return true }
        if !isDir.boolValue { return true }
        // Info.plist must be readable (= WSSchemaVersion check)
        let infoPlistURL = URL(fileURLWithPath: activeLibraryPath ?? "").appendingPathComponent("Info.plist")
        if !FileManager.default.isReadableFile(atPath: infoPlistURL.path) { return true }
        return false
    }

    // 
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // -> column body = the Apple canonical 4 layers.
    @Environment(AppState.self) private var appState
    // 2026-10-03 overabstraction cleanup: ShellState removed (= all
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // @State; = LibraryRootView no longer threads ShellState).
    @Environment(WorkspaceUIState.self) private var workspaceUI
    @Environment(SheetRequestState.self) private var sheetRequests
    @State private var bookStore: BookStore?
    @State private var activeLibrarySelection: String?
    @State private var commandPaletteModel = CommandPaletteModel()
    @State private var commandPaletteVisible: Bool = false
    /// Whether the trailing inspector column is visible. The column
    /// owns its own toggle, so the shell holds the visibility flag
    /// and hands the column a binding.
    @State private var inspectorVisible: Bool = true
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // No Group wrapper: a @ViewBuilder computed property is inlined
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // while `Group { ... }` is a real View in the hierarchy.
        content
            .environment(library)
            .preferredColorScheme(appearanceMode.colorScheme)
            // macOS 27 doc-alignment (see OOB.md #2026-09-18) OOB '',
            // … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // `pane-chrome-canonic-pattern.md`).
            .containerBackground(.windowBackground, for: .window)
            // s filename shouldn't be shown either':
            // … (= 55 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // 'where is the title bar / toolbar?' = open ChromeMainToolbar.swift.
            .toolbar {
                ChromeMainToolbar(openWindow: openWindow, sheetRequests: sheetRequests)
            }            .task(id: activeLibraryPath) { await runLaunch() }
            .sheet(isPresented: $commandPaletteVisible) {
                CommandPaletteView(model: commandPaletteModel)
                    .navigationTitle(String(localized: "command_palette.title"))
            }
            .onAppear {
                WenshuAppDelegate.openSettings = openSettings
                // SwiftData library upgrade wiring (= boss OOB
                // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // one assignment.
                WenshuAppDelegate.sharedAppState = appState
                WenshuAppDelegate.openWindowAction = openWindow
            }
            .background(WindowFirstResponderSuppressor())
    }

    @ViewBuilder
    private var content: some View {
        if appState.migrationInFlight {
            // SwiftData library upgrade in progress (= boss OOB
            // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // chrome (= must walk through 重试 or 退出).
            EmptyView()
        } else if shouldShowOnboarding {
            LibraryOnboardingView(onLibraryPicked: { url in
                // Persist the user's selection in two parts:
                // … (= 26 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // bookmark) and persists it via LibraryBookmark.save.
                try? ActiveLibrary.setActiveLibrary(at: url)
                activeLibrarySelection = url.path
            })
        } else if let bookStore {
            // LibraryRootView is the NavigationSplitView. Nothing
            // … (= 45 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // values are therefore a crash guardrail, not cosmetic sizing.
            NavigationSplitView {
                AppleSidebarView()
                    .navigationSplitViewColumnWidth(
                        min: 200,
                        ideal: 240,
                        max: 320
                    )
            } content: {
                AssetsPane(
                    envAppState: appState,
                    workspaceUI: workspaceUI
                )
                .navigationSplitViewColumnWidth(
                    // (= the
                    // … (= 32 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // bound, not a fixed width).
                    min: 240,
                    ideal: 300,
                    max: 340
                )
            } detail: {
                EditorChatSplitHost(
                    conductor: WenshuAppDelegate.sharedConductor
                )
                .environment(appState)
                .inspector(isPresented: $inspectorVisible) {
                    InspectorView(
                        appState: appState,
                        workspaceUI: workspaceUI,
                        inspectorVisibleBinding: $inspectorVisible
                    )
                }
            }
            // Apple HIG canonical toolbar placement for the
            // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // appear everywhere = synced').
            .toolbar {
                    ToolbarItem(
                        id: "wenshu-export",
                        placement: .automatic
                    ) {
                        Button {
                            sheetRequests.exportSheet += 1
                        } label: {
                            Label(
                                String(localized: "export.toolbar.label"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .help(String(localized: "export.toolbar.label"))
                    }
                }
                .environment(bookStore)
        } else {
            // BookStore is built asynchronously by LibraryLifecycleHook.
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // so the shell cannot render before it exists.
            ProgressView()
        }
    }

    @MainActor
    private func runLaunch() async {
        guard !shouldShowOnboarding, bookStore == nil else { return }
        let wsRoot = URL(fileURLWithPath: activeLibraryPath ?? "")
        // Apple HIG canonical sandbox persistence: when the App
        // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // flow continues unchanged.
        let bookmarkURL = LibraryBookmark.resolve()
        let accessed = bookmarkURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessed { bookmarkURL?.stopAccessingSecurityScopedResource() }
        }
        let hook = LibraryLifecycleHook(wsRoot: wsRoot)
        do {
            let result = try hook.runLaunch()
            self.bookStore = result.makeBookStore()
            // Populate the reactive `books` mirror at launch so
            // bookStore.books.count is correct on the first render.
            self.bookStore?.reloadAllBooks()
        } catch {
            // -m1-shell (see OOB.md #2026-09-10) OOB 'UI doesn't load, just spins forever':
            // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // the 2026-09-10 audit).
            wenshuLogger.info("[wenshu.library.lifecycle] runLaunch failed: \(String(describing: error))")
        }
    }
}

// / ', shouldchat zonedialog.
// … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / Searches multiple paths in .app bundle for wenshu-original-fanbai.png.
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

// / LibraryOnboardingView: First-launch .ws file picker (NSOpenPanel).
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / .ws file location (FCP-style event library UX).
struct LibraryOnboardingView: View {
    let onLibraryPicked: (URL) -> Void

    // / Apple HIG Inventory 2026-09-06 listed `.fileImporter` as a
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / standard sheet UX; macOS 14+).
    @State private var isImporterPresented: Bool = false

    var body: some View {
        VStack(spacing: DesignTokens.spacingSection) {
            Spacer()

// wenshu-verification-fix ((see OOB.md #2026-08-24)):
// … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
// to load PNG from absolute path inside .app bundle.
Group {
    if let nsImage = loadWenshuLogo() {
        // wenshu-verification-fix ((see OOB.md #2026-08-24)):
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // (consistent across light/dark mode).
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: DesignTokens.coverThumbnailSize, height: DesignTokens.coverThumbnailSize)
    } else {
        // Fallback: SF Symbols 6 canonical 'text.book.closed' if PNG load fails
        // ((see OOB.md #2026-09-02): SF Symbol fully replaced).
        SFIcon("text.book.closed", style: .inlineSmall, color: .white)
    }
}

            VStack(spacing: DesignTokens.spacingModerate) {
                Text(String(localized: "auto.libraryrootview.l366.h45346224"))
                    .font(.title.weight(.semibold))
                Text(String(localized: "onboarding.library.choose_location"))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(String(localized: "onboarding.library.welcome_blurb"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: DesignTokens.onboardingWelcomeMaxWidth)
                    .padding(.horizontal, DesignTokens.spacingSection)
            }

            VStack(spacing: DesignTokens.spacingModerate) {
                // macOS HIG standard: the primary 'New' action (= create
                // … (= 37 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // glass; = no manual color tuning needed).
                Button {
                    isImporterPresented = true
                } label: {
                    Label(
                        String(localized: "auto2.libraryrootview.l387.h40947105"),
                        systemImage: "document.badge.plus"
                    )
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button {
                    isImporterPresented = true
                } label: {
                    Label(
                        String(localized: "auto2.libraryrootview.l396.h53178210"),
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.glass)
                .controlSize(.large)

                Text(String(localized: "onboarding.library.new_vs_open"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            }

            Spacer()
        }
        // (see OOB.md #2026-09-10) — `.windowResizability(.contentSize)`
        // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // maxHeight:) is just a starting size, not a hard cap).
        .frame(minWidth: 640, idealWidth: DesignTokens.onboardingWindowSize.width, maxWidth: 800, minHeight: 720, idealHeight: DesignTokens.onboardingWindowSize.height, maxHeight: 900)
        .background(Color.clear)
        // RATIONALE: A `.ws` library is a custom package type, not a
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // aligned with the same custom package declared in Info.plist.
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType(exportedAs: "com.wenshu.workspace")]
        ) { result in
            switch result {
            case .success(let url):
                // Existing libraries open as-is. A custom package without its
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // accepts only the declared `.ws` type.
                let infoPlist = url.appendingPathComponent("Info.plist")
                if !FileManager.default.fileExists(atPath: infoPlist.path) {
                    LibraryOnboardingView.createWenshuWorkspace(at: url)
                }
                onLibraryPicked(url)
            case .failure:
                // User cancelled (= no action). Apple-standard UX:
                // cancel silently closes the sheet.
                break
            }
        }
    }

    // MARK: - Bundle creation helper ((see OOB.md #2026-08-24) fix)

}  // close LibraryOnboardingView struct

extension LibraryOnboardingView {
    // / createWenshuWorkspace: explicitly create the package directory at url
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / (= shelves/ books/ chat.sqlite kanban.sqlite todo.sqlite).
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
                "WSPCreatedAt": Date().formatted(.iso8601),
            ]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? data.write(to: infoPlistURL)
            }
        }
        // wenshu-verification-fix ((see OOB.md #2026-08-24) —
        // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // Render SF Symbol to NSImage at 1024x1024, then setIcon.
        if let symbolImage = renderSFSymbol("book", size: 1024) {
            let workspace = NSWorkspace.shared
            let success = workspace.setIcon(symbolImage, forFile: url.path, options: [])
            wenshuLogger.info("[wenshu.library] icon set=\(success ? "yes" : "no") for: \(url.path)")
        } else if let logoImage = loadWenshuLogoForIcon() {
            // Fallback to wenshu LOGO if SF Symbol render fails
            logoImage.size = NSSize(width: 1024, height: 1024)
            let workspace = NSWorkspace.shared
            let success = workspace.setIcon(logoImage, forFile: url.path, options: [])
            wenshuLogger.info("[wenshu.library] icon set=\(success ? "yes" : "no") (fallback LOGO) for: \(url.path)")
        }
        wenshuLogger.info("[wenshu.library] created package: \(url.path)")
    }

    // / Render an SF Symbol to NSImage at given size.
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Apple HIG: SF Symbol fill variant for package icons.
    static func renderSFSymbol(_ name: String, size: CGFloat) -> NSImage? {
        // Use NSImage(systemSymbolName:) for SF Symbol loading.
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: name) else {
            wenshuLogger.info("[wenshu.library] SF Symbol not found: \(name)")
            return nil
        }
        image.size = NSSize(width: size, height: size)
        return image
    }

    /// Load the wenshu LOGO PNG for use as Finder icon.
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
