// LibraryPropertiesView.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// FCP-style "Library Properties" panel (= boss 8/26 Q1=c, "用户体
// 验最完整"). Modal sheet triggered from Settings menu (= 库属性...).
// Shows the .ws library's current state + management actions.
//
// v0.26 boss 8/26 OOB (per spec v5 ticket 014):
// - Current .ws path (= readonly display + Reveal in Finder button)
// - Disk usage (= recursive size of .ws)
// - Schema version (= from Info.plist WSSchemaVersion)
// - Move Warehouse button (= FileManager.moveItem + atomic UserDefaults update)
// - Reset Library button (= clears UserDefaults + returns to onboarding)
//
// No zip export button (= boss vetoed per OOB item 8 + Q13; user moves
// the .ws via Finder).
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 014.

import SwiftUI

struct LibraryPropertiesView: View {
    /// Current .ws library URL.
    let libraryPath: String

    /// Schema version (= from Info.plist WSSchemaVersion).
    let schemaVersion: Int

    /// Callback to close the sheet.
    let onClose: () -> Void

    /// Callback to reveal the .ws in Finder (= triggers NSWorkspace).
    let onRevealInFinder: () -> Void

    /// Callback to move the .ws to a new location.
    let onMoveWarehouse: () -> Void

    /// Callback to reset the library (= clears UserDefaults + returns
    /// to onboarding on next launch).
    let onResetLibrary: () -> Void

    @State private var diskUsageBytes: Int64 = 0
    @State private var showResetConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("库属性")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                Section("基本信息") {
                    LabeledContent("当前路径") {
                        Text(libraryPath)
                            .font(.callout)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    HStack {
                        LabeledContent("磁盘占用") {
                            Text(formatBytes(diskUsageBytes))
                                .font(.callout.monospacedDigit())
                        }
                        Spacer()
                        Button("刷新") {
                            refreshDiskUsage()
                        }
                        .controlSize(.small)
                    }
                    LabeledContent("Schema 版本") {
                        Text("v\(schemaVersion)")
                            .font(.callout.monospacedDigit())
                    }
                }
                Section("操作") {
                    Button {
                        onRevealInFinder()
                    } label: {
                        Label("在 Finder 中显示", systemImage: "folder")
                    }
                    Button {
                        onMoveWarehouse()
                    } label: {
                        Label("移动仓库到...", systemImage: "arrow.right.square")
                    }
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("重置库", systemImage: "arrow.uturn.backward")
                    }
                }
                Section {
                    Text("如需在其他位置打开本库，请直接在 Finder 中移动整个 .ws 文件夹。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("关闭") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 460, idealHeight: 520)
        .onAppear { refreshDiskUsage() }
        .confirmationDialog(
            "确认重置库?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置 (清空设置，下次启动重新选库)", role: .destructive) {
                onResetLibrary()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("重置不会删除 .ws 目录中的数据。\n仅清空 wenshu.libraryPath 设置，下次启动会回到 onboarding。")
        }
    }

    // MARK: - Helpers

    private func refreshDiskUsage() {
        let url = URL(fileURLWithPath: libraryPath)
        let bytes = Self.recursiveDirectorySize(at: url)
        diskUsageBytes = bytes
    }

    private static func recursiveDirectorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}