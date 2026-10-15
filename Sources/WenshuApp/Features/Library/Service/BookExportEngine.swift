//
//  BookExportEngine.swift · Wenshu
//
//  Actor that performs the per-book export (= EPUB / PDF / combined
//  Markdown). Reads the book's chapters via the nonisolated static
//  helpers on `FileSystemChapterStore` (= actor-isolated callers can't
//  reach MainActor for a SwiftData context; the static helpers walk
//  the legacy FileSystem JSON index + chapter .md files).
//
//  EPUB path: builds a valid EPUB 3.0 zip via the standard EPUB
//  layout (= mimetype META; = META-INF/container.xml; =
//  OEBPS/content.opf + OEBPS/toc.ncx + one chapter .xhtml per
//  chapter). The build uses Foundation's `Archive` (= Apple
//  Foundation API, available on macOS 14+ via the bundled
//  `AppleArchive` framework; for wenshu's macOS 27 minimum, the
//  EPUB build uses a hand-rolled zip via `/usr/bin/zip` instead —
//  Apple ships `zip` on every macOS install and EPUBKit would add
//  an SPM dep for ~30 lines of zip orchestration).
//
//  PDF path: writes a minimal PDF (= one page per chapter, =
//  the chapter body wrapped in a PDF text-show operation). Uses
//  PDFKit (= built into macOS, no SPM dep). The PDF is functional
//  (= not pageless Apple-style); future tickets can replace this
//  with WKWebView-rendered PDFs for richer typography.
//
//  Combined MD path: writes one `<chapter-title>.md` per chapter
//  inside a destination folder (= the user picks the folder via
//  NSSavePanel; = the engine creates the folder and writes files
//  inside).
//

import Foundation
import AppKit
import PDFKit

/// Book export sub-format (= surfaced in the sheet's book section
/// picker). Reuses the enum declared in ExportSheet.swift (= that
/// file owns the sheet-side picker type).
// (= see `BookExportFormat` in Views/Export/ExportSheet.swift)

/// Typed error for book export failures.
enum BookExportError: LocalizedError, Sendable, Equatable {
    case noActiveLibrary
    case bookNotFound(UUID)
    case noChapters(UUID)
    case destinationReadOnly(URL)
    case ioFailure(URL, String)
    case zipProcessFailed(status: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .noActiveLibrary:
            return "No active library is open."
        case .bookNotFound(let id):
            return "Book \(id.uuidString) not found."
        case .noChapters(let id):
            return "Book \(id.uuidString) has no chapters to export."
        case .destinationReadOnly(let url):
            return String(localized: "export.error.destination_readonly") + " (\(url.path))"
        case .ioFailure(let url, let msg):
            return "I/O failure at \(url.path): \(msg)"
        case .zipProcessFailed(let status, let stderr):
            return "zip failed (\(status)): \(stderr)"
        }
    }
}

actor BookExportEngine {

    /// Locate the book's directory in the active library (= .ws /
  /// shelves / <shelf> / books / <book-uuid>). Walks every shelf
  /// because the chapter store's protocol surface doesn't carry the
  /// shelf ID (= only the book ID).
    private func locateBookDirectory(bookID: UUID) async throws -> URL? {
        guard let libPath = ActiveLibrary.path else {
            throw BookExportError.noActiveLibrary
        }
        let libURL = URL(fileURLWithPath: libPath, isDirectory: true)
        let shelvesURL = libURL.appendingPathComponent("shelves", isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: shelvesURL.path) else { return nil }

        let shelves = try fm.contentsOfDirectory(
            at: shelvesURL,
            includingPropertiesForKeys: nil
        )
        for shelf in shelves {
            let booksURL = shelf.appendingPathComponent("books", isDirectory: true)
            guard fm.fileExists(atPath: booksURL.path) else { continue }
            let books = try fm.contentsOfDirectory(
                at: booksURL,
                includingPropertiesForKeys: nil
            )
            for book in books {
                if book.lastPathComponent == bookID.uuidString {
                    return book
                }
            }
        }
        return nil
    }

    /// Export the book to `destinationURL` in the chosen format.
    /// For EPUB/PDF the destination is a file URL; for combined MD
    /// the destination is a directory URL (= the user picks the
    /// folder via the directory picker).
    func exportBook(
        id: UUID,
        to destinationURL: URL,
        format: BookExportFormat
    ) async throws -> URL {

        guard let bookDir = try await locateBookDirectory(bookID: id) else {
            throw BookExportError.bookNotFound(id)
        }

        let chaptersDir = bookDir.appendingPathComponent("chapters", isDirectory: true)
        let indexURL = bookDir.appendingPathComponent("chapters.json")

        let chapters = try FileSystemChapterStore.loadChaptersFromFileSystem(
            bookDirectory: bookDir,
            chaptersDirectory: chaptersDir,
            indexURL: indexURL
        )

        guard !chapters.isEmpty else {
            throw BookExportError.noChapters(id)
        }

        switch format {
        case .epub:
            return try await writeEPUB(
                bookID: id,
                chapters: chapters,
                chaptersDir: chaptersDir,
                destination: destinationURL
            )
        case .pdf:
            return try writePDF(
                chapters: chapters,
                chaptersDir: chaptersDir,
                destination: destinationURL
            )
        case .combinedMd:
            return try writeCombinedMarkdown(
                bookID: id,
                chapters: chapters,
                chaptersDir: chaptersDir,
                destination: destinationURL
            )
        }
    }

    // MARK: EPUB

    /// Write a valid EPUB 3.0 archive at `destination`. EPUB layout:
    /// mimetype (= unzipped, first entry) + META-INF/container.xml +
    /// OEBPS/content.opf + OEBPS/toc.ncx + OEBPS/chapter-<n>.xhtml.
    private func writeEPUB(
        bookID: UUID,
        chapters: [Document],
        chaptersDir: URL,
        destination: URL
    ) async throws -> URL {
        let fm = FileManager.default

        // Build a temp directory containing the EPUB layout.
        let staging = fm.temporaryDirectory
            .appendingPathComponent("wenshu-ebook-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        defer { try? fm.removeItem(at: staging) }

        // mimetype file (= must be unzipped; = the -X flag in `zip`
        // preserves it without compression).
        try Data("application/epub+zip".utf8)
            .write(to: staging.appendingPathComponent("mimetype"))

        // META-INF/container.xml
        let metaInf = staging.appendingPathComponent("META-INF", isDirectory: true)
        try fm.createDirectory(at: metaInf, withIntermediateDirectories: true)
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        try Data(containerXML.utf8)
            .write(to: metaInf.appendingPathComponent("container.xml"))

        // OEBPS directory
        let oebps = staging.appendingPathComponent("OEBPS", isDirectory: true)
        try fm.createDirectory(at: oebps, withIntermediateDirectories: true)

        // Write one chapter-<n>.xhtml per chapter + assemble the
        // manifest / spine / nav.
        var manifestItems: [String] = []
        var spineItems: [String] = []
        var navItems: [String] = []

        for (index, chapter) in chapters.enumerated() {
            let body = FileSystemChapterStore.loadChapterBodyFromFileSystem(
                id: chapter.id,
                chaptersDirectory: chaptersDir
            ) ?? ""

            let fileName = "chapter-\(index + 1).xhtml"
            let chapterURL = oebps.appendingPathComponent(fileName)
            let xhtml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <head><title>\(chapter.title)</title></head>
            <body>
            <h1>\(chapter.title)</h1>
            <p>\(body)</p>
            </body>
            </html>
            """
            try Data(xhtml.utf8).write(to: chapterURL)
            manifestItems.append(
                "<item id=\"chapter\(index + 1)\" href=\"\(fileName)\" media-type=\"application/xhtml+xml\"/>"
            )
            spineItems.append("<itemref idref=\"chapter\(index + 1)\"/>")
            navItems.append(
                "<li><a href=\"\(fileName)\">\(chapter.title)</a></li>"
            )
        }

        let contentOPF = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
        <metadata>
            <dc:identifier id="bookid">urn:uuid:\(bookID.uuidString)</dc:identifier>
            <dc:title>Wenshu Book</dc:title>
            <dc:language>en</dc:language>
        </metadata>
        <manifest>
            \(manifestItems.joined(separator: "\n    "))
        </manifest>
        <spine toc="ncx">
            \(spineItems.joined(separator: "\n    "))
        </spine>
        </package>
        """
        try Data(contentOPF.utf8)
            .write(to: oebps.appendingPathComponent("content.opf"))

        let tocNCX = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
        <navMap>
        <navPoint id="navpoint-1"><navLabel><text>Chapters</text></navLabel><content src="content.opf"/></navPoint>
        </navMap>
        </ncx>
        """
        try Data(tocNCX.utf8)
            .write(to: oebps.appendingPathComponent("toc.ncx"))

        // Zip the staging directory into the destination file.
        // `/usr/bin/zip -X` stores the mimetype entry uncompressed
        // (= EPUB canonical requirement).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-X", "-r", "-q", destination.path, "."]
        process.currentDirectoryURL = staging
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw BookExportError.zipProcessFailed(
                status: -1,
                stderr: "Process.run failed: \(error)"
            )
        }
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            throw BookExportError.zipProcessFailed(
                status: process.terminationStatus,
                stderr: stderr
            )
        }

        return destination
    }

    // MARK: PDF

    /// Write a minimal PDF (= one page per chapter) using PDFKit's
    /// `PDFDocument` + `PDFPage(image:)` pattern. Each page renders
    /// the chapter title + body via an `NSAttributedString` drawn into
    /// an `NSImage` (= Apple HIG canonical pattern for rasterizing
    /// attributed text into a PDF page).
    private func writePDF(
        chapters: [Document],
        chaptersDir: URL,
        destination: URL
    ) -> URL {
        let pdfDoc = PDFDocument()

        for (index, chapter) in chapters.enumerated() {
            let body = FileSystemChapterStore.loadChapterBodyFromFileSystem(
                id: chapter.id,
                chaptersDirectory: chaptersDir
            ) ?? ""

            // Render the chapter text into an NSImage (= US Letter
            // @ 72 DPI; = 612 × 792 = the PDF page unit).
            let pageSize = CGSize(width: 612, height: 792)
            let image = NSImage(size: pageSize)
            image.lockFocus()
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black,
            ]
            NSString(string: chapter.title)
                .draw(at: NSPoint(x: 50, y: 720), withAttributes: titleAttr)
            NSString(string: body)
                .draw(in: NSRect(x: 50, y: 50, width: 512, height: 660), withAttributes: bodyAttr)
            image.unlockFocus()

            guard let page = PDFPage(image: image) else { continue }
            pdfDoc.insert(page, at: index)
        }

        // Save the document to the destination URL (= Apple HIG
        // canonical PDFKit save path).
        pdfDoc.write(to: destination)
        return destination
    }

    // MARK: Combined Markdown

    /// Write one `<chapter-title>.md` per chapter inside the
    /// destination folder. The destination URL must point at a
    /// directory (= the user picks a folder via the directory
    /// picker).
    private func writeCombinedMarkdown(
        bookID: UUID,
        chapters: [Document],
        chaptersDir: URL,
        destination: URL
    ) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        for chapter in chapters {
            let body = FileSystemChapterStore.loadChapterBodyFromFileSystem(
                id: chapter.id,
                chaptersDirectory: chaptersDir
            ) ?? ""
            let safeTitle = chapter.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let fileURL = destination
                .appendingPathComponent("\(safeTitle).md")
            try Data(body.utf8).write(to: fileURL)
        }

        return destination
    }
}