//
//  LibraryRootView.swift · Wenshu · v0.24 boss验收
//
//  Boss 2026-08-24 OOB 拍: '和 FCP 一样, 首次运行, 无论是否要建书架,
//  都要先指定一个 .ws 文件的库文件位置'.
//
//  Apple HIG 参考: FCP / Lightroom / Photos 都要求 first launch 时
//  user 选择 1 个 library file (e.g. .fcpbundle, .lrcat, .photoslibrary),
//  保存 to UserDefaults, 之后所有 data 都进 this library.
//
//  wenshu .ws file = wenshu workspace (per AGENTS.md §11). 用户 selected .ws
//  file path stored in UserDefaults 'wenshu.libraryPath' (bookmark data for
//  sandboxed app, or plain path for non-sandboxed).
//
//  LibraryRootView behavior:
//  1. If 'wenshu.libraryPath' NOT set → show LibraryOnboardingView (NSOpenPanel)
//  2. If 'wenshu.libraryPath' set → show LayoutShellView (main app)
//  3. User can change library via Settings → '更换 .ws 库' button (future)
//
//  .ws folder structure (organize per boss 拍):
//  - workspace.ws       = main workspace database (1 file)
//  - shelves/           = book shelves (sub-libraries, FCP-style)
//  - books/             = individual book content (.md files)
//  - chat.sqlite        = chat history (migrated from chat.sqlite)
//  - kanban.sqlite      = kanban board (migrated from kanban.db)
//  - todo.sqlite        = todo list (migrated from todo.db)
//  - assets/            = images, attachments, other binary files
//  - chapters/          = book chapters (long-form content)
//  - backups/           = auto-generated backups
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
                Text("请选择 .ws 库文件位置")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                Text("和 Final Cut Pro 一样, 你的所有书架 / 聊天记录 / 看板 / 任务 / 资产 都会保存在这个 .ws 库里。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                // v0.24 boss验收fix: use NSSavePanel for new .ws (Apple HIG 'create
                // new file' pattern) + NSOpenPanel for existing .ws (Apple HIG 'open
                // existing file' pattern). FCP-style 2-button UX.
                Button {
                    showSavePanel()
                } label: {
                    Label("新建 .ws 库...", systemImage: "doc.badge.plus")
                        .frame(width: 240, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showOpenPanel()
                } label: {
                    Label("打开现有 .ws 库...", systemImage: "folder")
                        .frame(width: 240, height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text("新建 = 全新库文件, 打开 = 选已有 .ws")
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