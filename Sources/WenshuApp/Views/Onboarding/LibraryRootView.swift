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

            VStack(spacing: 8) {
                Button {
                    showOpenPanel()
                } label: {
                    Label("选择 .ws 库...", systemImage: "folder.badge.plus")
                        .frame(width: 240, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("可以选择现有 .ws 文件, 或新建一个")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColor.zoneSurface)
    }

    /// showOpenPanel: NSOpenPanel for selecting .ws file location.
    /// Allows both selecting existing .ws files AND creating new ones
    /// (via canChooseFiles + canCreateDirectories = true).
    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "选择 .ws 库文件"
        panel.message = "选择一个现有的 .ws 库文件, 或创建一个新的"
        panel.prompt = "选择"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false  // .ws is a file, not dir
        panel.canChooseFiles = true
        panel.canCreateDirectories = true
        panel.showsHiddenFiles = false
        // Filter to .ws files (with 'All files' fallback)
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = []
        }
        // Default save name for new .ws
        panel.nameFieldStringValue = "wenshu.ws"

        // Present as sheet on the main window
        if let window = NSApp.mainWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    onLibraryPicked(url)
                }
            }
        } else {
            // Fallback: modal
            if panel.runModal() == .OK, let url = panel.url {
                onLibraryPicked(url)
            }
        }
    }
}