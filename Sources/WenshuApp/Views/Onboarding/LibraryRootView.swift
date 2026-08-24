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
        // v0.24 boss验收fix (Boss 8/24 OOB): trigger condition.
        // 1. If libraryPath empty → onboarding (first launch).
        if libraryPath.isEmpty { return true }
        // 2. If libraryPath set but path doesn't exist on disk → onboarding
        // (boss deleted folder externally, or path invalid).
        // FileManager.default.fileExists(atPath:isDirectory:) = 0 if missing.
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: libraryPath, isDirectory: &isDir)
        if !exists { return true }
        return false
    }

    public var body: some View {
        Group {
            if shouldShowOnboarding {
                LibraryOnboardingView(onLibraryPicked: { url in
                    libraryPath = url.path
                })
            } else {
                LayoutShellView()
            }
        }
    }
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
// .colorInvert() + .colorMultiply(.white) converts 灰-blue ink to white
// text. .resizable + .aspectRatio keeps aspect ratio. No background/border
// added by SwiftUI (PNG's yellow bg is part of asset, not added by view).
Image("wenshu-original-fanbai")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 192, height: 192)
    .colorInvert()

            VStack(spacing: 12) {
                Text("欢迎使用文枢")
                    .font(.system(size: 28, weight: .semibold))
                Text("请指定文枢仓库的位置")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                Text("文枢会把你的书架、聊天记录、看板、任务、资产都保存在这个仓库里。")
                    .font(.system(size: 13))
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
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColor.zoneSurface)
    }

    /// showOpenPanel: NSOpenPanel for selecting existing 仓库 (folder).
    /// Apple HIG 'open existing directory' pattern. Boss 8/24 拍 '让客户指定
    /// 一个文枢仓库' = 仓库 is a directory (not .ws file). All chat/books/
    /// kanban/todo subdirs live under this folder.
    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "打开已有文枢仓库"
        panel.message = "选择一个现有的文枢仓库文件夹"
        panel.prompt = "打开"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = []
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

    /// showSavePanel: NSOpenPanel with canCreateDirectories for new 仓库.
    /// Boss 8/24 拍 '文枢仓库' = folder. Apple HIG 'create new directory'
    /// pattern (NSOpenPanel with canCreateDirectories = true behaves like
    /// Finder's 'New Folder' button — user types folder name, click 'Create',
    /// folder is created + selected).
    private func showSavePanel() {
        let panel = NSOpenPanel()
        panel.title = "新建文枢仓库"
        panel.message = "选择或新建一个文枢仓库文件夹"
        panel.prompt = "创建"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.showsHiddenFiles = false
        // Boss 拍 '让客户指定一个文枢仓库' (no .ws file). Just create directory
        // with name "文枢仓库" or user-chosen name. WenshuWorkspace will
        // initialize subdirs (shelves/ books/ chat.sqlite etc.) on first use.
        panel.nameFieldStringValue = "文枢仓库"
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = []
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
}