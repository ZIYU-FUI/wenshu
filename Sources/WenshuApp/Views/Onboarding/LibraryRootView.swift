//
//  LibraryRootView.swift · Wenshu
//
//  First-run library picker (= the onboarding flow).
//
//  User-facing text: no decision words (like FCP, better than X,
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
// 3. User can change library via Settings → ' button (future)
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
struct LibraryRootView: View {
    // LibraryRootView now owns the library + appearance
    // bindings (= were previously held by the now-removed
    // SettingsEnvironmentCapturer wrapper). The root view
    // receives them as constructor parameters from the App's
    // WindowGroup (= single source of truth = AppRootScene).
    let library: WenshuLibrary
    let appearanceMode: AppearanceMode
    @AppStorage("wenshu.libraryPath") private var libraryPath: String = ""

    init(library: WenshuLibrary, appearanceMode: AppearanceMode) {
        self.library = library
        self.appearanceMode = appearanceMode
    }

    private var shouldShowOnboarding: Bool {
        // boss acceptance fix (Boss 8/24 OOB): trigger condition strict.
        //
        // Boss said 'anbaiqiang.ws' = wenshu repository = .ws directory (= per v0.26 spec ticket 015,
        // .ws is now a macOS-style package directory, NOT a single file;
        // LibraryRootView.swift:296-309 creates Info.plist inside it).
        //
        // Trigger = libraryPath empty OR path doesn't end with '.ws' OR
        // .ws directory doesn't exist on disk.
        //
        // bossverificationfix #2 (Boss 8/24 OOB follow-up): trigger only
        // checked path existence, too lax. Boss saved '/Users/anbaiqiang/Documents'
        // (= parent folder, not anbaiqiang.ws file) → existed on disk → trigger
        // passed → main UI shown, even though no .ws file created.
        // amendment: .ws is a DIRECTORY (not file); require path ends
        // with '.ws' AND directory exists AND Info.plist is readable.
        if libraryPath.isEmpty { return true }
        // bossverificationfix: must end with .ws extension
        if !libraryPath.hasSuffix(".ws") { return true }
        // Directory must exist (v0.26: .ws is a directory, not a file)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: libraryPath, isDirectory: &isDir)
        if !exists { return true }
        if !isDir.boolValue { return true }
        // Info.plist must be readable (= WSSchemaVersion check)
        let infoPlistURL = URL(fileURLWithPath: libraryPath).appendingPathComponent("Info.plist")
        if !FileManager.default.isReadableFile(atPath: infoPlistURL.path) { return true }
        return false
    }

    // 
    // the state below was owned by the WiredShell wrapper struct, which
    // sat between LibraryRootView and NavigationSplitShell. That wrapper
    // is gone; its state and its launch task live here now, so the view
    // hierarchy is WindowGroup -> LibraryRootView -> NavigationSplitView
    // -> column body = the Apple canonical 4 layers.
    @Environment(AppState.self) private var appState
    // 2026-10-03 overabstraction cleanup: ShellState removed (= all
    // 4 fields migrated to WorkspaceUIState + NavigationSplitShell
    // @State; = LibraryRootView no longer threads ShellState).
    @Environment(WorkspaceUIState.self) private var workspaceUI
    @State private var bookStore: BookStore?
    @State private var commandPaletteModel = CommandPaletteModel()
    @State private var commandPaletteVisible: Bool = false
    // v2.8a (boss 2026-09-28 OOB B2): Spotlight search sheet
    // visibility (= driven by the Cmd-F ⌘F keyboard binding).
    @State private var spotlightVisible: Bool = false
    @State private var editMode = LayoutEditMode()
    /// Apple HIG inspector visibility. Per WWDC23-10161,
    /// `.inspector(isPresented:)` takes a `Binding<Bool>` that
    /// the OS reads to drive the right-column drag-collapse and
    /// the toolbar toggle button. Apple recommends @State here
    /// (= the inspector is view-local chrome; = no cross-view
    /// sharing required; = matches the Pages / Numbers / Keynote
    /// pattern where the inspector state lives in the owning
    /// split view, not in a shared environment class).
    ///
    /// Owner moved here in commit 6b (= the NavigationSplitShell
    /// wrapper layer was removed; = LibraryRootView is now the
    /// owning split view, so the inspector state lives on it).
    @State private var inspectorVisible: Bool = true
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // No Group wrapper: a @ViewBuilder computed property is inlined
        // by the result builder, so `content` costs zero view layers,
        // while `Group { ... }` is a real View in the hierarchy.
        content
            .environment(library)
            .preferredColorScheme(appearanceMode.colorScheme)
            // macOS 27 doc-alignment (boss 9/18 OOB '全都改一下',
            // audit ticket 1): the canonical macOS 27 SwiftUI window
            // background is the `.containerBackground(for: .window)`
            // modifier applied at the root view inside WindowGroup.
            // Per developer.apple.com/documentation/swiftui/view/
            // containerbackground(_:for:) = the API that sets the
            // window's container background. Without this modifier,
            // macOS 27 SwiftUI leaves the window background empty
            // (= NSScreen wallpaper shows through = desktop icons
            // visible behind the SwiftUI control surface = the entire
            // standard-control surface is missing Apple's Liquid
            // Glass tonal layer). Setting it to
            // `.windowBackground` (= Apple-managed
            // NSColor, NOT a custom RGB; per boss 9/2 OOB '你所有用的
            // 颜色，都是 API 给的, 不要自定义') gives the window its
            // canonical Apple HIG background tone (= the 1 NSColor
            // pane content fills, paired with `.controlBackgroundColor`
            // for chrome, where the Apple-managed ~10% brightness
            // delta between the two IS the visible boundary between
            // pane content and chrome = the canonical 2-layer pattern
            // from `pane-chrome-canonic-pattern.md`).
            .containerBackground(.windowBackground, for: .window)
            // s filename shouldn't be shown either':
            // drop the `.navigationSubtitle(libraryPath.lastPathComponent)`.
            // It was originally added (= ticket 008, commit a0e9b509d) to
            // match Apple's Pages / Numbers 'document basename in the
            // window subtitle' pattern, but per the boss's most recent
            // visual iteration the column-top subtitle (= 'anbaiqiang.ws'
            // in the screenshot) is noise on a single-library app (= the
            // user knows which library they opened = the .ws picker is
            // onboarding-only = no per-document title bar is needed).
            // Per Apple HIG Inventory 2026-09-06 the API is still
            // available for future use (= .navigationSubtitle remains
            // imported at the call site below via SwiftUI re-export;
            // = we just don't call it from this root view anymore).
            // 
            // REMOVED. Per boss 2026-09-10 OOB 'Apple Pages/Numbers/
            // Keynote doesn't hide the right column' + 'Apple doesn't provide a default collapse button for the right column',
            // inspector is permanently visible (= no toggle, no
            // hide affordance). NavigationSplitShell wires
            // `.inspector(isPresented: .constant(true))`; this
            // toolbar toggle was the wrong abstraction (= it tried
            // to expose a feature Apple does not expose in office
            // apps). The toolbar now hosts only wenshu's own
            // chrome (= no NSV-default buttons added).
            .task(id: libraryPath) { await runLaunch() }
            .sheet(isPresented: $commandPaletteVisible) {
                CommandPaletteView(model: commandPaletteModel)
                    .navigationTitle(WenshuI18n.t("command_palette.title"))
            }
            // v2.8a (boss 2026-09-28 OOB B2): Cmd-F ⌘F triggers the
            // Spotlight search sheet (= Apple HIG hidden-button +
            // keyboardShortcut pattern; = the binding lives here so
            // the sheet is available regardless of which zone is
            // focused).
            .sheet(isPresented: $spotlightVisible) {
                    SpotlightSearchSheet(onPick: handleSpotlightPick)
                }
                .background(
                    // Hidden activation button (= .frame(width: 0, height: 0) +
                    // .opacity(0) + .accessibilityHidden(true) = the canonical
                    // Apple HIG pattern for routing keyboard shortcuts through
                    // a SwiftUI view without a visible chrome element).
                    Button("") { spotlightVisible = true }
                        .keyboardShortcut("f", modifiers: .command)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        .accessibilityHidden(true)
                )
            .onReceive(NotificationCenter.default.publisher(for: .wenshuShowCommandPalette)) { _ in
                commandPaletteVisible = true
                commandPaletteModel.show()
            }
            .layoutEditHotkey(editMode)
            .onReceive(NotificationCenter.default.publisher(for: .wenshuToggleEditMode)) { _ in
                editMode.toggle()
            }
            .onAppear {
                WenshuAppDelegate.openSettings = openSettings
            }
    }

    @ViewBuilder
    private var content: some View {
        if shouldShowOnboarding {
            LibraryOnboardingView(onLibraryPicked: { url in
                libraryPath = url.path
            })
        } else if let bookStore {
            // LibraryRootView is the NavigationSplitView. Nothing
            // wraps it: it is the direct child of the root view, which is
            // what Apple's NavigationSplitView documentation asks for
            // ("typically use it as the root view in a Scene").
            //
            // Commit 6b removed the NavigationSplitShell wrapper layer
            // (= the wenshu-summary abstraction that conflated wenshu-
            // specific column-binding plumbing with Apple's
            // NavigationSplitView). Per boss 2026-10-03 OOB '清多余的
            // 层' = strip wenshu-summary layers that conflate with the
            // Apple-canonical shape.
            //
            // Column bodies are still wrapped by ShellMiddleColumn /
            // ShellContentColumn / ShellDetailColumn (= the per-column
            // wenshu-summary wrappers; = commits 6c/6d/6e strip those
            // next). For this commit, the NavigationSplitShell wrapper
            // is removed and the body is inlined here (= the closure
            // shapes match Apple's documented NavigationSplitView init
            // exactly; = no init signature changes).
            NavigationSplitView {
                AppleSidebarView()
            } content: {
                AssetsPane(
                    envAppState: appState,
                    appState: appState,
                    workspaceUI: workspaceUI
                )
            } detail: {
                ShellContentColumn(
                    appState: appState,
                    bookStore: bookStore,
                    library: library
                )
                .inspector(isPresented: $inspectorVisible) {
                    InspectorView(
                        appState: appState,
                        workspaceUI: workspaceUI,
                        inspectorVisibleBinding: $inspectorVisible
                    )
                }
            }
        } else {
            // BookStore is built asynchronously by LibraryLifecycleHook.
            // Column bodies read it as a non-optional @Environment value,
            // so the shell cannot render before it exists.
            ProgressView()
        }
    }

    @MainActor
    private func runLaunch() async {
        guard !shouldShowOnboarding, bookStore == nil else { return }
        let wsRoot = URL(fileURLWithPath: libraryPath)
        let hook = LibraryLifecycleHook(wsRoot: wsRoot)
        do {
            let result = try hook.runLaunch()
            self.bookStore = result.makeBookStore()
            // Populate the reactive `books` mirror at launch so
            // bookStore.books.count is correct on the first render.
            self.bookStore?.reloadAllBooks()
        } catch {
            // -m1-shell boss 2026-09-10 OOB 'UI doesn't load, just spins forever':
            // the previous `#if DEBUG print` was suppressed in
            // release builds (= the boss is running a release .app
            // bundle). NSLog works in both DEBUG and RELEASE so the
            // user can see the actual lifecycle error from
            // Console.app (= the standard macOS log viewer; = the
            // same path the previous `[wenshu.library]` and
            // `[wenshu.chatStore]` NSLog lines use for diagnostics).
            // Without this, a silent failure here (= e.g. a missing
            // shelves root, or a thrown error inside
            // LibraryBootstrapper.ensureValidStructure) would
            // leave bookStore = nil forever and the window stuck
            // on the loading spinner (= exactly what boss saw).
            NSLog("[wenshu.library.lifecycle] runLaunch failed: %@", String(describing: error))
        }
    }

    /// v2.8a (boss 2026-09-28 OOB B2): handle a Spotlight result
    /// pick. Currently the dispatcher is a stub (= logs the docId
    /// + dismisses the sheet); = future tickets can wire this to
    /// chapter / reference / outline navigation once the
    /// search-index pipeline is feeding real docs into the
    /// CSSearchableIndexSearch actor (= §11.7 LLM Wiki pipeline;
    /// = see v2.8d ticket cluster).
    private func handleSpotlightPick(docId: String) {
        NSLog("[wenshu.spotlight] pick docId=%@", docId)

        // v2.9d T35 (boss 2026-09-28 OOB A8 polish): the
        // editor tab title now uses the mirror entry's title
        // (= falls back to the docId when the mirror has no
        // entry); = the canonical user-facing label per
        // AGENTS.md §11 baseline.
        //
        // Pattern mirrors the v2.9a jump-to-source path
        // (= openTabs.append + activeTabId), = now uses
        // CSSearchableIndexSearch.shared.title(forDocId:)
        // instead of the raw docId.
        Task {
            let title = await CSSearchableIndexSearch.shared.title(forDocId: docId)
            await MainActor.run {
                if !appState.openTabs.contains(where: { $0.documentPath == docId }) {
                    let newTab = EditorTab(
                        id: UUID(),
                        documentPath: docId,
                        draft: "",
                        originalBody: "",
                        mode: .preview,
                        title: title
                    )
                    appState.openTabs.append(newTab)
                    appState.activeTabId = newTab.id
                } else if let existing = appState.openTabs.first(where: { $0.documentPath == docId }) {
                    appState.activeTabId = existing.id
                }
            }
        }
    }
}

/// ', shouldchat zonedialog.
/// hint, should /help ': ChatBookManagerHint deleted (= top
/// banner removed in the same commit). The slash-command hint
/// moves to the .help() modifier on the chat TextField (= macOS
/// NSHelpManager tooltip on hover; = Apple HIG canonical
/// "explainer tooltip" pattern, = non-intrusive but always
/// available on demand).

// 
// the WiredShell wrapper struct is deleted. It existed only to own the
// BookStore construction and the command-palette / edit-mode state, and
// it added a whole view layer between the root view and the
// NavigationSplitView. All of it moved onto LibraryRootView above.


/// NSImage load helper (for PNG not in .xcassets).
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
/// Shows welcome + ' .ws ' button. User must select or create a
/// .ws file location (FCP-style event library UX).
struct LibraryOnboardingView: View {
    let onLibraryPicked: (URL) -> Void

    /// Apple HIG Inventory 2026-09-06 listed `.fileImporter` as a
    /// missing API (0 hits). Per boss 2026-09-10 'add HIG APIs that
    /// are currently absent', replace the legacy NSOpenPanel call
    /// below with SwiftUI's `.fileImporter` modifier (= Apple-
    /// standard sheet UX; macOS 14+).
    @State private var isImporterPresented: Bool = false

    var body: some View {
        VStack(spacing: DesignTokens.spacingSection) {
            Spacer()

// bossverificationfix (Boss 8/24 OOB): (books.vertical) replace LOGO.
// (= use wenshu-original-fanbai.png directly).
// .colorInvert() converts -blue ink to white text. .resizable +
// .aspectRatio keeps aspect ratio.
//
// Why NSImage(contentsOf:) not Image("wenshu-original-fanbai"):
//   Package.swift copies entire AppIcon.icon/ folder to .app bundle, but
//   SwiftUI Image("person.text.rectangle") only finds images in .xcassets or main bundle
//   root, NOT in subdirectories. So Image("wenshu-original-fanbai")
// returns empty (= "" = no icon visible). Use NSImage(contentsOf:)
//   to load PNG from absolute path inside .app bundle.
Group {
    if let nsImage = loadWenshuLogo() {
        // bossverificationfix (Boss 8/24 OOB): 'yes' = show the
        // PNG as-is (gray-blue calligraphic ink), don't .colorInvert.
        // .colorMultiply(.white) makes the ink truly white
        // (consistent across light/dark mode).
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: DesignTokens.coverThumbnailSize, height: DesignTokens.coverThumbnailSize)
    } else {
        // Fallback: SF Symbols 6 canonical 'text.book.closed' if PNG load fails
        // (boss 2026-09-02: SF Symbol fully replaced).
        SFIcon("text.book.closed", style: .inlineSmall, color: .white)
    }
}

            VStack(spacing: DesignTokens.spacingModerate) {
                Text(WenshuI18n.t("auto.libraryrootview.l366.h45346224"))
                    .font(.title.weight(.semibold))
                Text(WenshuI18n.t("onboarding.library.choose_location"))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(WenshuI18n.t("onboarding.library.welcome_blurb"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: DesignTokens.onboardingWelcomeMaxWidth)
                    .padding(.horizontal, DesignTokens.spacingSection)
            }

            VStack(spacing: DesignTokens.spacingModerate) {
                // bossverificationfix (Boss 8/24: 'don't'):
                // - 2 buttons = / open (macOS, not)
                // - ' / '.ws' / 'Final Cut Pro' (boss don't)
                // - boss ' → primary text = '
                Button {
                    showSavePanel()
                } label: {
                    Label { Text(WenshuI18n.t("auto2.libraryrootview.l387.h40947105")) } icon: { SFIcon("document.badge.plus", style: .inlineSmall, color: IconColor.tint) }
                        .frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    isImporterPresented = true
                } label: {
                    Label { Text(WenshuI18n.t("auto2.libraryrootview.l396.h53178210")) } icon: { SFIcon("folder", style: .inlineSmall, color: IconColor.tint) }
                        .frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text(WenshuI18n.t("onboarding.library.new_vs_open"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.statusForeground)
            }

            Spacer()
        }
        // -m1-shell boss 2026-09-10 OOB 'initial size, too small':
        // the onboarding body has no explicit outer frame, so
        // `.windowResizability(.contentSize)` (= applied at the
        // Scene root in AppRootScene) shrinks the window to the
        // VStack's intrinsic content size (= roughly the cover
        // thumbnail + a few buttons = ~360 PT wide x ~500 PT tall
        // in default layout = the small launcher-sized window
        // boss observed 9/10). Force a canonical onboarding
        // window size = 640 x 720 PT (= Apple HIG installer sheet
        // canonical; = big enough to show the logo + 2-line title +
        // body + 2 buttons + hint at full readability, = small
        // enough to not feel like a modal blocking the user's
        // workspace). The user's macOS still lets them resize
        // from this canonical size (= .contentSize keeps the
        // window resizable; = the .frame(minWidth:idealWidth:
        // maxHeight:) is just a starting size, not a hard cap).
        .frame(minWidth: 640, idealWidth: DesignTokens.onboardingWindowSize.width, maxWidth: 800, minHeight: 720, idealHeight: DesignTokens.onboardingWindowSize.height, maxHeight: 900)
        .background(Color.clear)
        // Apple HIG Inventory 2026-09-06: .fileImporter was 0 hits.
        // Apple-standard sheet for selecting an existing .ws directory.
        // UTType 'com.wenshu.workspace' (= the exported UTI from
        // Info.plist) is the allowed content type; macOS auto-filters
        // Finder to .ws packages in the picker.
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType("com.wenshu.workspace") ?? .folder]
        ) { result in
            switch result {
            case .success(let url):
                onLibraryPicked(url)
            case .failure:
                // User cancelled (= no action). Apple-standard UX:
                // cancel silently closes the sheet.
                break
            }
        }
    }

    /// showSavePanel: NSSavePanel for new .ws package directory.
    /// The .ws bundle is now a package DIRECTORY (= cross-book shared
    /// model). The NSSavePanel still
    /// takes a "filename" but createWenshuWorkspace creates a directory
    /// at that name (no .ws file inside).
    /// Default name = NSUserName() (Apple API for current Mac username).
    /// Apple HIG 'create new package' pattern (NSSavePanel with default name).
    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.title = WenshuI18n.t("auto2.libraryrootview.l472.h40947105")
        panel.message = WenshuI18n.t("auto2.libraryrootview.l473.h20911334")
        panel.prompt = WenshuI18n.t("auto2.libraryrootview.l474.h92696757")
        // bossverificationfix (Boss 8/24 OOB): default filename = NSUserName() + ".ws"
        // NSUserName() = current Mac username (Apple API, returns "anbaiqiang"
        // on 's machine). Boss 'shouldyes anbaiqiang'.
        let username = NSUserName()
        panel.nameFieldStringValue = "\(username).ws"
        panel.nameFieldLabel = "仓库名"
        panel.showsTagField = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        // (no .ws in user-facing text) but the
        // .ws package IS .ws (technical package format, like .photoslibrary
        // or .fcpbundle). Show extension so user sees what they're creating.
        if #available(macOS 11.0, *) {
            panel.canSelectHiddenExtension = true
            panel.allowedContentTypes = []
        }

        // bossverificationfix (Boss 8/24 OOB 'create, '): NSSavePanel
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
    /// (= shelves/ books/ chat.sqlite kanban.sqlite todo.sqlite).
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
        // bossverificationfix (Boss 8/24 OOB 'fileicon, can LOGO '):
        // Set the wenshu LOGO PNG as the Finder icon for the .ws package.
        // Apple HIG: NSWorkspace.shared.setIcon(_:forFile:options:) writes
        // icon into the file's resource fork / icon services metadata.
        // bossverificationfix (Boss 8/24 OOB ', SF,, '):
        // Use SF Symbol fill book icon (= book.fill) instead of wenshu LOGO PNG.
        // Per Apple HIG: SF Symbol fill variant for package icon.
        // Render SF Symbol to NSImage at 1024x1024, then setIcon.
        if let symbolImage = renderSFSymbol("book", size: 1024) {
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

    /// Render an SF Symbol to NSImage at given size.
    /// Used for setting Finder icons on .ws packages.
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

