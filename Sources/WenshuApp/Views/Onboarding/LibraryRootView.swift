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
//  .photoslibrary (Photos) / .fcpbundle (FCP). Wenshu uses 'repository'.
//  Selected path stored in UserDefaults 'wenshu.libraryPath'.
//
//  LibraryRootView behavior:
//  1. If 'wenshu.libraryPath' NOT set → show LibraryOnboardingView (NSOpenPanel)
//  2. If 'wenshu.libraryPath' set → show AppRootScene (main app)
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
import os
import AppKit
import UniformTypeIdentifiers

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "libraryrootview")

/// LibraryRootView: Routes between onboarding (first launch) and main app.
///
/// Trigger condition ((see OOB.md #2026-08-24) — 'if persistent
/// info has no library file info, need to go to library-creation/
/// library-selection page'):
/// - if UserDefaults 'wenshu.libraryPath' empty → onboarding
/// - if UserDefaults 'wenshu.libraryPath' set but path doesn't exist
///   on disk (= the user deleted the repository externally, or the
///   repository was on a now-disconnected drive) → onboarding (re-pick)
/// - else (= path set + path exists) → main app AppRootScene
struct LibraryRootView: View {
    // LibraryRootView now owns the library + appearance
    // bindings (= were previously held by the now-removed
    // SettingsEnvironmentCapturer wrapper). The root view
    // receives them as constructor parameters from the App's
    // WindowGroup (= single source of truth = AppRootScene).
    let library: WenshuLibrary
    let appearanceMode: AppearanceMode

    // Active library path (= canonical single source of truth via
    // the security-scoped bookmark; see State/ActiveLibrary.swift).
    // Read-only here; the .task(id:) below watches it to re-run
    // runLaunch when the user picks a new library. Pre-B13 this
    // was @AppStorage("wenshu.libraryPath") (= the UserDefaults
    // string), but the Q2 production refactor removed every read of
    // that string and replaced it with ActiveLibrary. The
    // @AppStorage binding here would have written the legacy string
    // (= deleted by the one-shot migration in
    // WenshuAppDelegate.applicationDidFinishLaunching), = so we
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
        //
        // (see OOB.md #2026-08-24) — wenshu repository = .ws
        // directory (= per v0.26 spec ticket 015,
        // .ws is now a macOS-style package directory, NOT a single file;
        // LibraryRootView.swift:296-309 creates Info.plist inside it).
        //
        // Trigger = activeLibraryPath empty OR path doesn't end with '.ws' OR
        // .ws directory doesn't exist on disk.
        //
        // wenshu-verification-fix #2 ((see OOB.md #2026-08-24)
        // follow-up): trigger only checked path existence, too lax.
        // The user saved '/Users/anbaiqiang/Documents' (= parent
        // folder, not anbaiqiang.ws file) → existed on disk → trigger
        // passed → main UI shown, even though no .ws file created.
        // amendment: .ws is a DIRECTORY (not file); require path ends
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
    @Environment(SheetRequestState.self) private var sheetRequests
    @State private var bookStore: BookStore?
    @State private var activeLibrarySelection: String?
    @State private var commandPaletteModel = CommandPaletteModel()
    @State private var commandPaletteVisible: Bool = false
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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // No Group wrapper: a @ViewBuilder computed property is inlined
        // by the result builder, so `content` costs zero view layers,
        // while `Group { ... }` is a real View in the hierarchy.
        content
            .environment(library)
            .preferredColorScheme(appearanceMode.colorScheme)
            // macOS 27 doc-alignment (see OOB.md #2026-09-18) OOB '',
            // : the canonical macOS 27 SwiftUI window
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
            // NSColor, NOT a custom RGB; per (see OOB.md #2026-09-02)
            // OOB '， API , ')
            // gives the window its canonical Apple HIG background
            // tone (= the 1 NSColor pane content fills, paired with
            // `.controlBackgroundColor` for chrome, where the
            // Apple-managed ~10% brightness delta between the two IS
            // the visible boundary between pane content and chrome =
            // the canonical 2-layer pattern from
            // `pane-chrome-canonic-pattern.md`).
            .containerBackground(.windowBackground, for: .window)
            // s filename shouldn't be shown either':
            // drop the `.navigationSubtitle(activeLibraryPath?.lastPathComponent ?? "")`.
            // It was originally added (= ticket 008, commit a0e9b509d) to
            // match Apple's Pages / Numbers 'document basename in the
            // window subtitle' pattern, but per (see OOB.md #2026-09-19)
            // the column-top subtitle (= 'anbaiqiang.ws' in the
            // screenshot) is noise on a single-library app (= the
            // user knows which library they opened = the .ws picker
            // is onboarding-only = no per-document title bar is
            // needed). Per Apple HIG Inventory 2026-09-06 the API
            // is still available for future use (= .navigationSubtitle remains
            // imported at the call site below via SwiftUI re-export;
            // = we just don't call it from this root view anymore).
            // 
            // REMOVED. Per (see OOB.md #2026-09-10) OOB 'Apple Pages/Numbers/
            // Keynote doesn't hide the right column' + 'Apple doesn't provide a default collapse button for the right column',
            // inspector is permanently visible (= no toggle, no
            // hide affordance). NavigationSplitShell wires
            // `.inspector(isPresented: .constant(true))`; this
            // toolbar toggle was the wrong abstraction (= it tried
            // to expose a feature Apple does not expose in office
            // apps). The toolbar now hosts only wenshu's own
            // chrome (= no NSV-default buttons added).
            .task(id: activeLibraryPath) { await runLaunch() }
            .sheet(isPresented: $commandPaletteVisible) {
                CommandPaletteView(model: commandPaletteModel)
                    .navigationTitle(String(localized: "command_palette.title"))
            }
            .onAppear {
                WenshuAppDelegate.openSettings = openSettings
                // SwiftData library upgrade wiring (= boss OOB
                // 2026-10-06). WenshuAppDelegate owns the static
                // bridge slots for the migration panel (= the
                // AppState reference + the OpenWindow action).
                // AppRootScene has no constructor argument path to
                // AppState (= the App-level body constructs it via
                // @State); = LibraryRootView reads AppState via
                // @Environment and forwards it to the AppDelegate
                // here. Same pattern as openSettings = one bridge,
                // one assignment.
                WenshuAppDelegate.sharedAppState = appState
                WenshuAppDelegate.openWindowAction = openWindow
            }
    }

    @ViewBuilder
    private var content: some View {
        if appState.migrationInFlight {
            // SwiftData library upgrade in progress (= boss OOB
            // 2026-10-06). Render an empty view here so the main
            // window does not mount the NavigationSplitView (= the
            // SwiftData ModelContainer is being migrated by the
            // pipeline running behind the LibraryMigrationPanel).
            // The user sees the panel only (= no main app chrome
            // = no half-migrated state visible in the columns).
            // The panel's Window has .windowStyle(.hiddenTitleBar)
            // so the user cannot close the panel from the system
            // chrome (= must walk through 重试 or 退出).
            EmptyView()
        } else if shouldShowOnboarding {
            LibraryOnboardingView(onLibraryPicked: { url in
                // Persist the user's selection in two parts:
                // 1. 'wenshu.libraryPath' string (= the existing source
                //    of truth for 10+ consumers across
                //    Core/Chat + Core/Agent + App/WenshuAppDelegate).
                //    Non-sandboxed builds use this string verbatim.
                // 2. 'wenshu.libraryBookmark' security-scoped Data (=
                //    Apple HIG canonical for App Sandbox persistence;
                //    developer.apple.com/documentation/foundation/url#
                //    bookmarkdata(options:includingresourcevaluesforkeys:
                //    relativeto:)). Sandboxed builds resolve the bookmark
                //    on next launch to recover the user's grant
                //    (= the user does not have to re-pick the .ws
                //    library after every relaunch).
                //
                // Persist the user's selection as the canonical
                // security-scoped bookmark (= see
                // State/ActiveLibrary.swift = State/LibraryBookmark.swift).
                // Pre-B13 (= before the Q2 production refactor) this
                // closure wrote both the legacy 'wenshu.libraryPath'
                // UserDefaults string (= via @AppStorage, removed in
                // this commit) and the bookmark Data. Post-B13 the
                // bookmark is the sole persistence (= the legacy
                // string is cleared on next launch by
                // WenshuAppDelegate.applicationDidFinishLaunching's
                // one-shot migration). ActiveLibrary.setActiveLibrary
                // is the canonical single writer; = it generates
                // fresh bookmark Data (= rejects any pre-existing
                // bookmark) and persists it via LibraryBookmark.save.
                try? ActiveLibrary.setActiveLibrary(at: url)
                activeLibrarySelection = url.path
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
            // NavigationSplitView). Per (see OOB.md #2026-10-03) OOB '
            // ' = strip wenshu-summary layers that conflate with the
            // Apple-canonical shape.
            //
            // Column bodies are still wrapped by ShellMiddleColumn /
            // ShellContentColumn / ShellDetailColumn (= the per-column
            // wenshu-summary wrappers; = commits 6c/6d/6e strip those
            // next). For this commit, the NavigationSplitShell wrapper
            // is removed and the body is inlined here (= the closure
            // shapes match Apple's documented NavigationSplitView init
            // exactly; = no init signature changes).
            //
            // Inject `BookStore` at the NavigationSplitView root.
            // AppleSidebarView + AssetsPane + PaneView +
            // TabContentDispatcher + PreviewPane + BookmarkView +
            // ChatZoneView + EditorView all declare non-optional
            // `@Environment(BookStore.self)`. Without this explicit
            // `.environment(bookStore)` injection, the first access to
            // `bookStore` from any sidebar / content column body
            // fatal-asserts with "No Observable object of type BookStore
            // found". The detail column's EditorView + ChatZoneView are
            // already covered via EditorChatNSController's
            // NSHostingController `.environment(bookStore)` injection
            // (= the SwiftUI @Environment chain does not propagate
            // across the NSHostingController boundary = the controller
            // must inject manually). Sidebar + content columns are
            // direct SwiftUI rows = a single `.environment(bookStore)`
            // at the NavigationSplitView root suffices.
            //
            // The unwrap is safe: `if let bookStore` already shadowed
            // the optional `self.bookStore` into a non-nil local, so
            // this value is the same one the SwiftUI body just bound
            // (= nil ruled out by the guard above).
            // Apple NavigationSplitView has no automatic maximum-width API for
            // SwiftUI columns. Leaving these widths to the framework allows
            // either column to grow until the NSHostingView constraints
            // become invalid on macOS 27; the verified crash occurs in
            // NSWindow._postWindowNeedsUpdateConstraints. These min/ideal/max
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
                    appState: appState,
                    workspaceUI: workspaceUI
                )
                .navigationSplitViewColumnWidth(
                    min: 280,
                    ideal: 360,
                    max: 520
                )
            } detail: {
                EditorChatSplitHost(
                    conductor: WenshuAppDelegate.sharedConductor,
                    appState: appState,
                    bookStore: bookStore,
                    library: library
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
            // document-menu (= per developer.apple.com/design/
            // human-interface-guidelines/toolbars 'Next to the
            // title, the toolbar can include a document menu that
            // contains standard and app-specific commands that
            // affect the document as a whole, such as Duplicate,
            // Rename, Move, and Export'). We add a single Export
            // button at `.automatic` (= trailing edge) using the
            // SF Symbols 6 share/export glyph (= 'square.and.arrow.
            // up'). Tapping it mirrors the File → Export… menu item:
            // bumps sheetRequests.exportSheet += 1 (= Apple HIG
            // cross-component sync rule = 'a new feature should
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
            // Column bodies read it as a non-optional @Environment value,
            // so the shell cannot render before it exists.
            ProgressView()
        }
    }

    @MainActor
    private func runLaunch() async {
        guard !shouldShowOnboarding, bookStore == nil else { return }
        let wsRoot = URL(fileURLWithPath: activeLibraryPath ?? "")
        // Apple HIG canonical sandbox persistence: when the App
        // Sandbox is enabled, the bare path string cannot recover the
        // user's grant across launches. The security-scoped bookmark
        // (persisted in LibraryBookmark.save on first selection)
        // restores it. The bookmark scope is held for the launch
        // window (= the read-only I/O that LibraryLifecycleHook +
        // SwiftData container init need) and released when finished.
        //
        // Non-sandboxed builds (= today) return nil from
        // LibraryBookmark.resolve(), and the existing path-based
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
            // the previous `#if DEBUG print` was suppressed in
            // release builds (= the canonical macOS distribution channel).
            // NSLog works in both DEBUG and RELEASE so the
            // user can see the actual lifecycle error from
            // Console.app (= the standard macOS log viewer; = the
            // same path the previous `[wenshu.library]` and
            // `[wenshu.chatStore]` NSLog lines use for diagnostics).
            // Without this, a silent failure here (= e.g. a missing
            // shelves root, or a thrown error inside
            // LibraryBootstrapper.ensureValidStructure) would
            // leave bookStore = nil forever and the window stuck
            // on the loading spinner (= the symptom reported during
            // the 2026-09-10 audit).
            wenshuLogger.info("[wenshu.library.lifecycle] runLaunch failed: \(String(describing: error))")
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
    /// missing API (0 hits). Per (see OOB.md #2026-09-10) 'add HIG APIs that
    /// are currently absent', replace the legacy NSOpenPanel call
    /// below with SwiftUI's `.fileImporter` modifier (= Apple-
    /// standard sheet UX; macOS 14+).
    @State private var isImporterPresented: Bool = false

    var body: some View {
        VStack(spacing: DesignTokens.spacingSection) {
            Spacer()

// wenshu-verification-fix ((see OOB.md #2026-08-24)):
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
        // wenshu-verification-fix ((see OOB.md #2026-08-24)):
        // 'yes' = show the PNG as-is (gray-blue calligraphic ink),
        // don't .colorInvert.
        // .colorMultiply(.white) makes the ink truly white
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
                // a new Wenshu library) sits above the secondary 'Open'
                // action. Both buttons render via Apple's
                // `Label(_, systemImage:)` initializer (= .hermes.md
                // exception #4 explicitly permits this site for
                // `.systemName` strings). Using `Label(_, systemImage:)`
                // delegates icon color management to SwiftUI's button
                // styling (= .borderedProminent swaps the foreground
                // to white for contrast against the accent background;
                // = .bordered keeps the tint color visible against
                // the gray background). The earlier `Label { Text }
                // icon: { SFIcon(..., color: IconColor.tint) }` form
                // locked the icon color to the SwiftUI environment
                // tint, which SwiftUI then surfaced as the same accent
                // blue as the prominent button's background (= the
                // icon vanished against its own button).
                //
                // Do NOT wrap the label in a fixed-size
                // .frame(width:height:) — that previously clipped the
                // icon + text out of the prominent button entirely.
                // Per (see OOB.md #2026-10-06) macOS 27 Liquid
                // Glass canonical form: use SwiftUI's `Button` with
                // `.buttonStyle(.glassProminent / .glass)` (= SwiftUI
                // internally wraps NSButton + sets bezelStyle +
                // borderShape = .capsule automatically when
                // .controlSize(.large) is in effect; = the canonical
                // 'large → capsule shape' path documented in
                // WWDC25-310 'Build an AppKit app with the new
                // design'). The wenshu GlassTextButton NSViewRepresentable
                // (= used in earlier commits) bypassed this path and
                // rendered the NSButton's default rectangular border
                // shape; = the SwiftUI wrapper is the right one.
                //
                // The icon is a SF Symbol passed via
                // Label(_, systemImage:) (= .hermes.md exception #4).
                // The system foreground tint = SwiftUI picks the
                // contrast color per button style (= .glassProminent =
                // white on accent; = .glass = tint on transparent
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
            // shrinks the window to the VStack's intrinsic content
            // size (= roughly the cover thumbnail + a few buttons =
            // ~360 PT wide x ~500 PT tall in default layout = the
            // small launcher-sized window observed during the
            // 2026-09-10 audit). Force a canonical onboarding
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
        // RATIONALE: A `.ws` library is a custom package type, not a
        // generic folder. `public.folder` does not include package
        // conformance in the open panel, so existing libraries remain
        // disabled even though LaunchServices identifies their UTI.
        // Registering the exported type at runtime keeps the picker
        // aligned with the same custom package declared in Info.plist.
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType(exportedAs: "com.wenshu.workspace")]
        ) { result in
            switch result {
            case .success(let url):
                // Existing libraries open as-is. A custom package without its
                // manifest is treated as an incomplete library rather
                // than silently initialized, because this picker now
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
                "WSPCreatedAt": Date().formatted(.iso8601),
            ]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? data.write(to: infoPlistURL)
            }
        }
        // wenshu-verification-fix ((see OOB.md #2026-08-24) —
        // 'fileicon, can LOGO'): Set the wenshu LOGO PNG as the
        // Finder icon for the .ws package. Apple HIG:
        // NSWorkspace.shared.setIcon(_:forFile:options:) writes
        // icon into the file's resource fork / icon services metadata.
        // wenshu-verification-fix ((see OOB.md #2026-08-24) — 'use SF
        // Symbol fill book icon'): Use SF Symbol fill book icon
        // (= book.fill) instead of wenshu LOGO PNG. Per Apple HIG:
        // SF Symbol fill variant for package icon.
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

    /// Render an SF Symbol to NSImage at given size.
    /// Used for setting Finder icons on .ws packages.
    /// Apple HIG: SF Symbol fill variant for package icons.
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
