//
//  ChatViewMarkdownIO.swift
//
//  2 markdown I/O helpers extracted from ChatView.swift
//  (= §6.6 god-class split + discoverability: markdownForConversation
//  + importMarkdown moved out of the main file into this dedicated
//  `enum ChatViewMarkdownIO` namespace).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `struct ChatView: View` is 1422 LOC = 2.37x the 600-LOC cap. The
//  2 markdown I/O funcs are a single concern (= "format the chat
//  transcript as Markdown for export + import the Markdown file back
//  into the chat"). Putting them in a dedicated file named after
//  the concern (= ChatViewMarkdownIO.swift) lets the next reader
//  find the markdown I/O logic by name.
//
//  These 2 funcs are @MainActor static (= safe to call from any
//  context; = matches ChatViewModel's MainActor isolation).
//  Uses inline `Logger(subsystem:category:)` (= avoids the cross-file
//  wenshuLogger coupling).
//

import Foundation
import os

/// Namespace container for the chat Markdown I/O helpers. Wrapped
/// in an enum (= same pattern as A56's `enum ImportServiceDedup`
/// and A62's `enum ImportServiceCache`).
enum ChatViewMarkdownIO {

    /// Format the current conversation as the legacy chat-Markdown shape (=
    /// per-message '[prefix]: content' lines, double-newline separated). Same
    /// formatter the T76 NSSavePanel block used (= identical on-disk format; no
    /// migration needed for files exported before this commit).
    @MainActor static func markdownForConversation(_ messages: [ChatMessage]) -> String {
        messages.map { msg -> String in
            let prefix: String
            switch msg.source {
            case .user: prefix = "你"
            case .wenshu: prefix = "文枢"
            case .system: prefix = "系统"
            }
            return "[\(prefix)]: \(msg.content)"
        }.joined(separator: "\n\n")
    }


    /// Read a chat-Markdown file and replace the current conversation with the
    /// parsed history (= the inverse of markdownForConversation). Naive split
    /// on '\n\n'; each non-empty block becomes a ChatMessage whose source is
    /// derived from the leading '[xx]:' prefix.
    @MainActor static func importMarkdown(at url: URL, into vm: ChatViewModel) {
        do {
            let raw = try String(contentsOf: url, encoding: .utf8)
            let blocks = raw.components(separatedBy: "\n\n")
            var loaded: [ChatMessage] = []
            for block in blocks {
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                let source: ChatSource
                let content: String
                if trimmed.hasPrefix("[你]: ") {
                    source = .user
                    content = String(trimmed.dropFirst("[你]: ".count))
                } else if trimmed.hasPrefix("[文枢]: ") {
                    source = .wenshu
                    content = String(trimmed.dropFirst("[文枢]: ".count))
                } else if trimmed.hasPrefix("[系统]: ") {
                    source = .system
                    content = String(trimmed.dropFirst("[系统]: ".count))
                } else {
                    source = .user
                    content = trimmed
                }
                loaded.append(ChatMessage(
                    id: UUID(),
                    role: source == .wenshu ? .agent : .user,
                    source: source,
                    content: content,
                    timestamp: Date()
                ))
            }
            // Replace the conversation with the loaded history.
            vm.messages = loaded
        } catch {
            Logger(subsystem: "com.wenshu", category: "chatview-markdown-io").info("[wenshu.import] failed to read markdown: \(error.localizedDescription)")
        }
    }


}
