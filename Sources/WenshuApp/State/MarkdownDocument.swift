//
//  MarkdownDocument.swift · Wenshu
//
//  Apple SwiftUI FileDocument (= developer.apple.com/documentation/
//  swiftui/filedocument) used by .fileExporter to save the current
//  conversation as a .md file. Read support (= the `init(...)
//  throws` initializer that parses an existing .md) lets a future
//  FileDocument-based open path reuse the same Codable shape;
//  today's .fileImporter path in ChatView is text-only and parses
//  the message blocks inline (= see Self.importMarkdown(at:into:) in
//  ChatView.swift).
//
//  Why a dedicated FileDocument type (= vs. an inline generic over
//  Data): the .fileExporter modifier requires a concrete FileDocument-
//  conforming type as its `document:` argument (= macOS 11+ API
//  contract). MarkdownDocument is the canonical entry point.
//

import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}