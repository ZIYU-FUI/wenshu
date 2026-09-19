//
//  ChatMessageViewAttachmentFooterTests.swift · Wenshu · T54-ATTACHMENT-FOOTER-ICON (2026-09-18)
//
//  Verifies the paperclip SF Symbol rendered in the sealed
//  message footer when the message has an image attachment.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView attachment footer icon (T54)")
struct ChatMessageViewAttachmentFooterTests {

    /// T54 contract: source uses Image(systemName: "paperclip") in the footer.
    @Test func source_uses_paperclip() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"paperclip\")"))
    }

    /// T54 contract: footer icon is gated by message.imagePath != nil.
    @Test func source_gates_on_imagePath() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if message.imagePath != nil {"))
    }

    /// T54 contract: icon uses .caption2 + .tertiary tone (= the
    /// Apple HIG secondary metadata style; = matches T25 token footer).
    @Test func icon_uses_caption2_tertiary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let iconBlockStart = src.range(of: "Image(systemName: \"paperclip\")")!
        // Find the closing `}` of the icon block (= the next `}` after the icon).
        let iconBlockEnd = src.range(of: "}", range: iconBlockStart.upperBound..<src.endIndex)!.lowerBound
        let iconBlock = src[iconBlockStart.lowerBound..<iconBlockEnd]
        #expect(iconBlock.contains(".font(.caption2)"))
        #expect(iconBlock.contains(".foregroundStyle(.tertiary)"))
    }

    /// T54 contract: icon has a .help() tooltip with WenshuI18n.t
    /// (= i18n parity).
    @Test func icon_uses_localized_help() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(WenshuI18n.t(\"chatview.message.has_attachment\"))"))
    }

    /// T54 contract: chatview.message.has_attachment key exists
    /// in BOTH en + zh-Hans.
    @Test func i18n_keys_in_both_locales() throws {
        let en = try runPlutil("Sources/WenshuApp/Resources/en.lproj/Localizable.strings")
        let zh = try runPlutil("Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings")
        #expect(en.contains("\"chatview.message.has_attachment\""))
        #expect(zh.contains("\"chatview.message.has_attachment\""))
    }

    private func runPlutil(_ path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        process.arguments = ["-p", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Plutil", code: Int(process.terminationStatus))
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}