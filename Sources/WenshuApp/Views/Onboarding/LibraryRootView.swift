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
public struct LibraryRootView: View {
    @AppStorage("wenshu.libraryPath") private var libraryPath: String = ""

    public var body: some View {
        Group {
            if libraryPath.isEmpty {
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

            // Welcome icon (large SF Symbol)
            Image(systemName: "books.vertical")
                .font(.system(size: 96))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

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

    /// showOpenPanel: NSOpenPanel for selecting existing .ws file.
    /// Apple HIG 'open existing file' pattern. Allows user to browse
    /// and select an already-existing .ws library file.
    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "打开现有 .ws 库"
        panel.message = "选择一个现有的 .ws 库文件"
        panel.prompt = "打开"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
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

    /// showSavePanel: NSSavePanel for creating new .ws file.
    /// Apple HIG 'create new file' pattern. Default nameFieldStringValue
    /// = "wenshu.ws" (or "untitled.ws" fallback). User picks folder + filename
    /// inline. This is the FCP-style 'create new event library' UX.
    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.title = "新建 .ws 库"
        panel.message = "选择 .ws 库文件的保存位置"
        panel.prompt = "创建"
        panel.nameFieldStringValue = "wenshu.ws"
        panel.nameFieldLabel = "库文件名"
        panel.showsTagField = false
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = []
        if #available(macOS 11.0, *) {
            // Allow .ws extension to be added automatically
            panel.canSelectHiddenExtension = true
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