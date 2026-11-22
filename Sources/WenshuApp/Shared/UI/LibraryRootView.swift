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

    // Active library path (= canonical single source of truth via
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // replaced it with the canonical accessor.
    private var activeLibraryPath: String? {
        activeLibrarySelection ?? ActiveLibrary.path
    }

    init(library: WenshuLibrary) {
        self.library = library
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
            // Craft audit B4 (2026-11-21): the app-level appearance picker
            // (= system/dark/light) and the color-scheme override it drove
            // are gone. The override repainted the whole window behind the
            // materials: when it disagreed with the OS appearance, every vibrancy
            // layer (the window containerBackground, the toolbar material,
            // the sidebar) read a backing that did not match the desktop
            // (= the "dirty gray" drift ruled out on 2026-11-12). Following
            // the system appearance is the only mode that keeps the chrome
            // materials honest; macOS itself offers no per-app override.
            // macOS 27 doc-alignment for the window's chrome: the material comes
            // from the window itself (see the pattern note in
            // `pane-chrome-canonic-pattern.md`).
            .containerBackground(.regularMaterial, for: .window)
            // s filename shouldn't be shown either':
            // … (= 55 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // 'where is the title bar / toolbar?' = open ChromeMainToolbar.swift.
            // The toolbar rides on the library pages only (= the welcome
            // page has no library, so the kanban and export buttons have
            // nothing to act on). The window keeps its traffic lights.
            .modifier(OnboardingAwareToolbar(
                isOnboarding: shouldShowOnboarding,
                openWindow: openWindow,
                sheetRequests: sheetRequests
            ))
            .task(id: activeLibraryPath) { await runLaunch() }
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
            .environment(bookStore)
            // The book the format page edits is the book of the
            // document the user puts in front of him. Opening a
            // book's manuscript from the card grid therefore names
            // that book (= before this, ONLY an outline click in the
            // sidebar ever did, so after a relaunch the page showed a
            // document, had no target, and its switcher rebound to the
            // set it was already showing). `initial: true` is the
            // launch case: the restored tabs are already there and no
            // later change to `activeTabId` follows them.
            .onChange(of: appState.activeTabId, initial: true) { _, _ in
                bookStore.adoptActiveBook(appState.activeBookId)
            }
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
        // the product sandbox persistence: when the App
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
            // The material column answers a card's cover from memory, so
            // the covers folder is read ONCE here, before a single card
            // asks (= `CoverIndex`). What a frame then pays for a cover
            // is nothing, and the ask that does happen in the column's
            // own path is a background one.
            await CoverIndex.shared.prefillAndWait()
        } catch {
            // A launch failure must not leave the app spinning: the error is logged
            // here so a stalled UI is attributable to the step that failed, not to
            // the view that never appeared.
            wenshuLogger.info("[wenshu.library.lifecycle] runLaunch failed: \(String(describing: error))")
        }
    }
}

// / ', shouldchat zonedialog.
// … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / The wordmark artwork the welcome page shows = the effective color
// / scheme picks the file. The light theme carries the gold calligraphy
// / (= a white brush stroke on a cream background reads as a watermark,
// / not as the product's name); the dark theme keeps the white one.
enum WenshuWordmark {
    /// The white calligraphy (= the app icon's own source artwork).
    static let whiteAssetName = "wenshu-original-fanbai"
    /// The gold calligraphy (= the light theme's wordmark).
    static let goldAssetName = "wenshu-gold-v3-warm"

    /// The asset the scheme the page renders in asks for.
    static func assetName(for colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? whiteAssetName : goldAssetName
    }
}

// / Searches multiple paths in .app bundle for the named wordmark PNG.
private func loadWenshuLogo(named assetName: String) -> NSImage? {
    // Build process: Package.swift copies AppIcon.icon/ → Wenshu.app/Contents/Resources/AppIcon.icon/
    // AppIcon.icon contains icon.json (Apple Icon Composer format) and Assets/ subdir.
    let paths = [
        // 1. Subdirectory: Resources/AppIcon.icon/Assets/<assetName>.png
        Bundle.main.url(forResource: assetName, withExtension: "png",
                        subdirectory: "AppIcon.icon/Assets"),
        // 2. Root of bundle: Resources/<assetName>.png
        Bundle.main.url(forResource: assetName, withExtension: "png"),
        // 3. Source path (for swift run debug): Sources/WenshuApp/Resources/AppIcon.icon/Assets/
        URL(fileURLWithPath: "/Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Resources/AppIcon.icon/Assets/\(assetName).png"),
    ]
    for path in paths {
        if let url = path, let nsImage = NSImage(contentsOf: url) {
            return nsImage
        }
    }
    return nil
}

// / The window toolbar = the library pages only. The welcome page has
// / no library, so the kanban and export buttons have nothing to act on.
private struct OnboardingAwareToolbar: ViewModifier {
    let isOnboarding: Bool
    let openWindow: OpenWindowAction
    let sheetRequests: SheetRequestState

    func body(content: Content) -> some View {
        if isOnboarding {
            content
        } else {
            content.toolbar {
                ChromeMainToolbar(openWindow: openWindow, sheetRequests: sheetRequests)
            }
            // / The window toolbar's background is one material for the whole
            // / window (= the window's titlebar strip).
            // / Without it, each split column paints its own flat fill into
            // / the strip (= a per-column band with a step at every column
            // / boundary, and a flat plate over the main content column).
            // / The material is the window chrome's own (= it reads what is
            // / behind the strip, so the strip carries the window's depth
            // / instead of a painted band).
            //
            // B6 CLOSURE (craft audit 2026-11-21, closed by the ruling
            // of (see OOB.md #2026-11-22) = keep the material fill,
            // open no real-glass layout ticket). The audit asked for
            // Liquid Glass in this strip; the ruling stands because the
            // strip CANNOT be glass through any published API:
            //   * `Glass` is NOT a ShapeStyle (reprintable compile probe:
            //     a minimal file with `func check<S: ShapeStyle>(_: S.Type)`
            //     called as `check(Glass.self)` fails typecheck with
            //     'Glass' does not conform to ShapeStyle), and
            //     `toolbarBackground(_:for:)` only takes a ShapeStyle.
            //   * The system paints no glass here either, measured on
            //     windowserver-composited captures of this exact window
            //     (five arms, strip band rows 0-110, sampled every 3 px,
            //     difference threshold 8/765 — reprint with measure.py in
            //     the craft-audit scratch dir, strip-ab/):
            //       light, fill removed vs `.toolbarBackground(.automatic)`
            //       → 0/106480 px differ (max 0); dark → 0/106480. The
            //       "drop it and the system gives glass" hypothesis is
            //       dead: `.automatic` IS the flat per-column composite.
            //       The material fill vs removed: light 97923/106480 px
            //       differ (the fill is load-bearing), dark 2565/106480
            //       (max 88). Colour share 0.7% light / 0.6% dark in
            //       every arm (= the pre-fix per-column plates state
            //       3682f88ed3 measured, unchanged by dropping a fill
            //       that was never there).
            //   * The glass the ruling asks for IS in this chrome where
            //     Apple exposes it: the toolbar's own buttons run on
            //     NSButton bezelStyle `.glass` (NSButtonCell.h:67,
            //     macos 26.0; see GlassIconButton.swift).
            // So the strip stays the one-material surface and the
            // controls stay glass bezels; a live-glass strip would mean
            // content under the titlebar (= a layout redesign, which the
            // boss declined).
            .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
            // The window's titlebar strip closes with the SHARED hairline,
            // = so the strip reads as chrome above the columns and not as
            // the top of one undifferentiated plane.
            //
            // The hairline rides the CONTENT (= the view that starts
            // where the toolbar strip ends), = so its top edge IS the
            // strip's lower edge, = and the welcome page (= which has no
            // toolbar) carries no line at its top edge.
            //
            // The hairline is the APP'S OWN (= Apple's own parameter for
            // this edge, `NSWindow.titlebarSeparatorStyle`, = MEASURED on
            // this window: the property sets and reads back as `.line`,
            // = and PAINTS NOTHING, = because the window paints its
            // toolbar background itself, = so the system edge is not drawn
            // there. = the product design rules names the other candidate, = the scroll
            // edge effect, = and its precondition (= a scroll view behind
            // floating interface elements) is not met here, = because the
            // content starts BELOW the toolbar strip. = The mark is the
            // same `Divider()` every other edge in the app uses.)
            .windowToolbarBottomHairline()
        }
    }
}

// / LibraryOnboardingView: First-launch .ws file picker (NSOpenPanel).
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / .ws file location (FCP-style event library UX).
struct LibraryOnboardingView: View {
    let onLibraryPicked: (URL) -> Void

    /// / product Inventory 2026-09-06 listed `.fileImporter` as a
    /// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / standard sheet UX; macOS 14+).
    @State private var isImporterPresented: Bool = false

    /// The scheme the page renders in (= the boss's pick, or the
    /// system's when he follows the system).
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: DesignTokens.spacingSection) {
            Spacer()

            // wenshu-verification-fix:
// … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
// to load PNG from absolute path inside .app bundle.
Group {
    if let nsImage = loadWenshuLogo(named: WenshuWordmark.assetName(for: colorScheme)) {
                    // wenshu-verification-fix:
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // (consistent across light/dark mode).
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: DesignTokens.coverThumbnailSize, height: DesignTokens.coverThumbnailSize)
    } else {
        // Fallback: SF Symbols 6 canonical 'text.book.closed' if PNG load fails
                    // (: SF Symbol fully replaced).
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
                // product standard: the primary 'New' action (= create
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
        //  — `.windowResizability(.contentSize)`
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

    // MARK: - Bundle creation helper ( fix)

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
        // 3. Create initial Info.plist inside package (product pattern for
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
        // wenshu-verification-fix (=
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

    /// / Render an SF Symbol to NSImage at given size.
    /// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / product: SF Symbol fill variant for package icons.
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
