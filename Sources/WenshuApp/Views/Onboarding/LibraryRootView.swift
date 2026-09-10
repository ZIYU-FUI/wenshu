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
public struct LibraryRootView: View {
    // v0.44 M8.1: LibraryRootView now owns the library + appearance
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
        // v0.24 boss acceptance fix (Boss 8/24 OOB): trigger condition strict.
        //
        // Boss said 'anbaiqiang.ws' = wenshu repository = .ws directory (= per v0.26 spec ticket 015,
        // .ws is now a macOS-style package directory, NOT a single file;
        // LibraryRootView.swift:296-309 creates Info.plist inside it).
        //
        // Trigger = libraryPath empty OR path doesn't end with '.ws' OR
        // .ws directory doesn't exist on disk.
        //
        // v0.24 bossverificationfix #2 (Boss 8/24 OOB follow-up): trigger only
        // checked path existence, too lax. Boss saved '/Users/anbaiqiang/Documents'
        // (= parent folder, not anbaiqiang.ws file) → existed on disk → trigger
        // passed → main UI shown, even though no .ws file created.
        // v0.26 amendment: .ws is a DIRECTORY (not file); require path ends
        // with '.ws' AND directory exists AND Info.plist is readable.
        if libraryPath.isEmpty { return true }
        // v0.24 bossverificationfix: must end with .ws extension
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

    // v0.47 boss 2026-09-09 OOB 'fix the layer count to Apple canonical':
    // the state below was owned by the WiredShell wrapper struct, which
    // sat between LibraryRootView and NavigationSplitShell. That wrapper
    // is gone; its state and its launch task live here now, so the view
    // hierarchy is WindowGroup -> LibraryRootView -> NavigationSplitView
    // -> column body = the Apple canonical 4 layers.
    @Environment(AppState.self) private var appState
    @State private var bookStore: BookStore?
    @State private var commandPaletteModel = CommandPaletteModel()
    @State private var commandPaletteVisible: Bool = false
    @State private var editMode = LayoutEditMode()
    @Environment(\.openSettings) private var openSettings

    public var body: some View {
        // No Group wrapper: a @ViewBuilder computed property is inlined
        // by the result builder, so `content` costs zero view layers,
        // while `Group { ... }` is a real View in the hierarchy.
        content
            .environment(library)
            .preferredColorScheme(appearanceMode.colorScheme)
            // v0.74 boss 2026-09-10 OOB '这个库文件名也不需要显示':
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
            // v0.81 boss 2026-09-10 OOB: inspector toggle button on
            // the root toolbar (= placement .primaryAction = the
            // macOS 27 trailing toolbar slot = where Apple Notes /
            // Reminders / Xcode place their inspector toggle).
            // Writes AppState.inspectorVisible (= the same property
            // NavigationSplitShell binds into `.inspector(isPresented:)`;
            // = the toggle round-trips through one @Observable
            // property shared between the toolbar View and the NSV
            // View, both reading the AppState injected via
            // .environment(appState) at the WindowGroup level in
            // AppRootScene). Lucide "panel-right" icon is the Apple
            // HIG canonical for an inspector-toggle (= matches what
            // Apple ships in Pages' Format panel toggle).
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    @Bindable var bindableAppState = appState
                    Button {
                        bindableAppState.inspectorVisible.toggle()
                    } label: {
                        LucideLabel("Inspector", icon: "panel-right")
                    }
                    .help(WenshuI18n.t("toolbar.inspector.toggle", defaultValue: "Show or hide the inspector"))
                    .keyboardShortcut("i", modifiers: [.command, .option])
                }
            }
            .task { await runLaunch() }
            .sheet(isPresented: $commandPaletteVisible) {
                CommandPaletteView(model: commandPaletteModel)
                    .navigationTitle(WenshuI18n.t("command_palette.title"))
            }
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
            // NavigationSplitShell is the NavigationSplitView. Nothing
            // wraps it: it is the direct child of the root view, which is
            // what Apple's NavigationSplitView documentation asks for
            // ("typically use it as the root view in a Scene").
            NavigationSplitShell(appState: appState, bookStore: bookStore)
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
            #if DEBUG
            print("LibraryLifecycleHook failed: \(error)")
            #endif
        }
    }
}

/// v0.40 boss 9/7 OOB ', shouldchat zonedialog.
/// hint, should /help ': ChatBookManagerHint deleted (= top
/// banner removed in the same commit). The slash-command hint
/// moves to the .help() modifier on the chat TextField (= macOS
/// NSHelpManager tooltip on hover; = Apple HIG canonical
/// "explainer tooltip" pattern, = non-intrusive but always
/// available on demand).

// v0.47 boss 2026-09-09 OOB 'fix the layer count to Apple canonical':
// the WiredShell wrapper struct is deleted. It existed only to own the
// BookStore construction and the command-palette / edit-mode state, and
// it added a whole view layer between the root view and the
// NavigationSplitView. All of it moved onto LibraryRootView above.





/// v0.24 bossverificationfix: NSImage load helper (for PNG not in .xcassets).
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
public struct LibraryOnboardingView: View {
    let onLibraryPicked: (URL) -> Void

    /// Apple HIG Inventory 2026-09-06 listed `.fileImporter` as a
    /// missing API (0 hits). Per boss 2026-09-10 'add HIG APIs that
    /// are currently absent', replace the legacy NSOpenPanel call
    /// below with SwiftUI's `.fileImporter` modifier (= Apple-
    /// standard sheet UX; macOS 14+).
    @State private var isImporterPresented: Bool = false

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

// v0.24 bossverificationfix (Boss 8/24 OOB): (books.vertical) replace LOGO.
// Boss 'yesfile' (= use wenshu-original-fanbai.png directly).
// .colorInvert() converts -blue ink to white text. .resizable +
// .aspectRatio keeps aspect ratio.
//
// Why NSImage(contentsOf:) not Image("wenshu-original-fanbai"):
//   Package.swift copies entire AppIcon.icon/ folder to .app bundle, but
//   SwiftUI Image("name") only finds images in .xcassets or main bundle
//   root, NOT in subdirectories. So Image("wenshu-original-fanbai")
// returns empty (= "" = no icon visible). Use NSImage(contentsOf:)
//   to load PNG from absolute path inside .app bundle.
Group {
    if let nsImage = loadWenshuLogo() {
        // v0.24 bossverificationfix (Boss 8/24 OOB): 'yes' = show the
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
                // v0.24 bossverificationfix (Boss 8/24: 'don't'):
                // - 2 buttons = / open (macOS, not)
                // - ' / '.ws' / 'Final Cut Pro' (boss don't)
                // - boss ' → primary text = '
                Button {
                    showSavePanel()
                } label: {
                    Label { Text(WenshuI18n.t("auto2.libraryrootview.l387.h40947105")) } icon: { LucideIcon("file-plus", size: 16) }
                        .frame(width: DesignTokens.bannerInlineSize.width, height: DesignTokens.bannerInlineSize.height)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    isImporterPresented = true
                } label: {
                    Label { Text(WenshuI18n.t("auto2.libraryrootview.l396.h53178210")) } icon: { LucideIcon("folder", size: 16) }
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
        // .regularMaterial (= Liquid Glass onboarding background);
        // now uses Color.clear (= no background).
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

    /// showOpenPanel: NSOpenPanel for selecting existing .ws directory.
    /// v0.26 amendment: .ws is now a DIRECTORY (= macOS-style package;
    /// LibraryRootView.swift:296-309 creates Info.plist inside it).
    /// Boss 8/24 OOB original: .ws file is the format.
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
    /// Boss 8/24 OOB: '.ws defaultfilename, useruser.
    /// shouldyes anbaiqiang. fileshould anbaiqiang.ws'
    /// = default name = NSUserName() (Apple API for current Mac username).
    /// Apple HIG 'create new package' pattern (NSSavePanel with default name).
    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.title = WenshuI18n.t("auto2.libraryrootview.l472.h40947105")
        panel.message = WenshuI18n.t("auto2.libraryrootview.l473.h20911334")
        panel.prompt = WenshuI18n.t("auto2.libraryrootview.l474.h92696757")
        // v0.24 bossverificationfix (Boss 8/24 OOB): default filename = NSUserName() + ".ws"
        // NSUserName() = current Mac username (Apple API, returns "anbaiqiang"
        // on 's machine). Boss 'shouldyes anbaiqiang'.
        let username = NSUserName()
        panel.nameFieldStringValue = "\(username).ws"
        panel.nameFieldLabel = "仓库名"
        panel.showsTagField = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        // Boss ' .ws' (no .ws in user-facing text) but the
        // .ws package IS .ws (technical package format, like .photoslibrary
        // or .fcpbundle). Show extension so user sees what they're creating.
        if #available(macOS 11.0, *) {
            panel.canSelectHiddenExtension = true
            panel.allowedContentTypes = []
        }

        // v0.24 bossverificationfix (Boss 8/24 OOB 'create, '): NSSavePanel
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
        // v0.24 bossverificationfix (Boss 8/24 OOB 'fileicon, can LOGO '):
        // Set the wenshu LOGO PNG as the Finder icon for the .ws package.
        // Apple HIG: NSWorkspace.shared.setIcon(_:forFile:options:) writes
        // icon into the file's resource fork / icon services metadata.
        // v0.24 bossverificationfix (Boss 8/24 OOB ', SF,, '):
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

    /// v0.24 bossverificationfix: render an SF Symbol to NSImage at given size.
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

    /// v0.24 bossverificationfix: load the wenshu LOGO PNG for use as Finder icon.
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

