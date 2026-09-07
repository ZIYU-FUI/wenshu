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
                Text(WenshuI18n.t("auto.librarypropertiesview.l48.h38942540"))
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                Section(WenshuI18n.t("auto2.librarypropertiesview.l55.h84342329")) {
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
                        Button(WenshuI18n.t("auto2.librarypropertiesview.l68.h7832952")) {
                            refreshDiskUsage()
                        }
                        .controlSize(.small)
                    }
                    LabeledContent("Schema 版本") {
                        Text("v\(schemaVersion)")
                            .font(.callout.monospacedDigit())
                    }
                }
                Section(WenshuI18n.t("auto2.librarypropertiesview.l78.h53311866")) {
                    Button {
                        onRevealInFinder()
                    } label: {
                        Label(WenshuI18n.t("auto2.librarypropertiesview.l82.h54714643"), systemImage: "folder")
                    }
                    Button {
                        onMoveWarehouse()
                    } label: {
                        Label(WenshuI18n.t("auto2.librarypropertiesview.l87.h35464092"), systemImage: "arrow.right.square")
                    }
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label(WenshuI18n.t("auto2.librarypropertiesview.l92.h43224553"), systemImage: "arrow.uturn.backward")
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
                Button(WenshuI18n.t("auto2.librarypropertiesview.l105.h50336293")) { onClose() }
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
            Button(WenshuI18n.t("auto2.librarypropertiesview.l117.h15214969"), role: .destructive) {
                onResetLibrary()
            }
            Button(WenshuI18n.t("auto2.librarypropertiesview.l120.h99009187"), role: .cancel) {}
        } message: {
            Text(WenshuI18n.t("auto2.librarypropertiesview.l122.h75912153"))
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