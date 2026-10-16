// LogDetailSheet.swift · Wenshu
//
// Sheet shown when the user taps "查看详细 LOG" in the
// chat input bar's error banner (= surfaced after a
// failed send). Displays the raw underlying error
// (= e.g. "Error Domain=SSEClient Code=400 HTTP 400")
// alongside the user-facing translation, with
// affordances to:
//
// 1. Copy the raw description to the clipboard (= for
//    bug reports / provider escalation).
// 2. Open Console.app pre-filtered to the wenshu
//    subsystem (= the dev surface for the same error;
//    = via `open console://...` Apple URL scheme).
//
// Per boss 2026-10-16 OOB "开可以查看详细的 LOG, 错在
// 哪": the user wants to see WHERE the error came from
// without leaving the chat. The raw description is the
// canonical source; the user can paste it into a bug
// report or search the wenshu logs in Console.

import SwiftUI
import AppKit

struct LogDetailSheet: View {
    let userMessage: String
    let rawErrorDescription: String?

    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("详细错误日志")
                        .font(.headline)
                    Text("这里显示的是技术层面的真实错误信息。复制后可贴到 bug 报告里。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // User-facing translation
            VStack(alignment: .leading, spacing: 4) {
                Text("用户提示")
                    .font(.subheadline.weight(.semibold))
                Text(userMessage)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }

            // Raw error description (= the real cause)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("底层错误")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        copyRawToClipboard()
                    } label: {
                        Label(
                            didCopy ? "已复制" : "复制",
                            systemImage: didCopy ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                ScrollView {
                    Text(rawErrorDescription ?? "（无原始错误描述 — 错误来自 wenshu 内部逻辑，未附带技术细节）")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 180)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
            }

            // Open Console.app affordance
            VStack(alignment: .leading, spacing: 4) {
                Text("开发者日志")
                    .font(.subheadline.weight(.semibold))
                Text("完整的 os_log 输出在 Console.app 里（subsystem = com.wenshu.app）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    openConsoleApp()
                } label: {
                    Label("在 Console.app 中打开", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 540, height: 480)
    }

    /// Copy the raw description to the macOS pasteboard
    /// (= `NSPasteboard.general`). The "已复制" badge
    /// shows for the next 2 seconds.
    private func copyRawToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let raw = rawErrorDescription, !raw.isEmpty {
            pb.setString(raw, forType: .string)
        } else {
            pb.setString("（无原始错误描述）", forType: .string)
        }
        didCopy = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            didCopy = false
        }
    }

    /// Open Console.app via the `console://` URL scheme (= Apple
    /// canonical; = works on macOS 12+). Pre-filtered to the
    /// wenshu subsystem so the user lands on the right logs.
    /// Falls back to opening Console.app without a filter if
    /// the URL scheme is unavailable (= very old macOS).
    private func openConsoleApp() {
        // Console.app URL scheme takes a query that pre-filters
        // the log stream. `subsystem` filter limits to wenshu's
        // log subsystem; = the user lands on the chat error
        // immediately.
        let urlString = "console://?subsystem=com.wenshu.app"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: open Console.app without filter.
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
        }
    }
}
