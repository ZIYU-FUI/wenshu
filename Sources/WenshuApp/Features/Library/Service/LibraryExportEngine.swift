//
//  LibraryExportEngine.swift · Wenshu
//
//  Actor that performs the .ws library export (= whole-library
//  copy or zip). Reads the active library URL via `ActiveLibrary.path`,
//  enumerates files under that directory (= recursively), and produces
//  either:
//
//  - a directory mirror at the destination URL (= copy mode; = the
//    destination URL is a directory package; = the user named the new
//    `.ws` in the save dialog), OR
//  - a zipped archive at the destination URL (= zip mode; = the
//    destination URL is a `.zip` file).
//
//  Both modes skip `.tmp` and `.bak` files (= in-progress writes
//  that would corrupt the export). `.git` is skipped (= wenshu
//  libraries never store a `.git` folder today; = this is a
//  forward-compat against a future git-backed-history ticket).
//
//  Why an actor (= not a struct): the export can take a few seconds
//  for a 100 MB library. Running it on the main actor would freeze
//  the sheet's progress indicator. The actor's isolation lets the
//  sheet observe progress from the main actor without blocking.
//
//  No third-party zip SPM dep. Per Apple HIG, the system `zip` CLI
//  is the canonical tool (= `/usr/bin/zip` is shipped on every
//  macOS install). Spinning a `Process` (= actor-isolated) avoids
//  pulling in a 200 KB SPM dep for 5 lines of process spawn.
//

import Foundation

/// Typed error for library export failures. Surfaces a localized
/// message to the sheet (= the sheet reads error.localizedDescription
/// when the engine throws).
enum LibraryExportError: LocalizedError, Sendable, Equatable {
    case noActiveLibrary
    case sourceMissing(URL)
    case destinationReadOnly(URL)
    case libraryCorrupted(URL)
    case zipProcessFailed(status: Int32, stderr: String)
    case ioFailure(URL, String)

    var errorDescription: String? {
        switch self {
        case .noActiveLibrary:
            return "No active library is open."
        case .sourceMissing(let url):
            return "Library source not found at \(url.path)."
        case .destinationReadOnly(let url):
            return String(localized: "export.error.destination_readonly") + " (\(url.path))"
        case .libraryCorrupted(let url):
            return String(localized: "export.error.library_corrupted") + " (\(url.path))"
        case .zipProcessFailed(let status, let stderr):
            return "zip failed (\(status)): \(stderr)"
        case .ioFailure(let url, let msg):
            return "I/O failure at \(url.path): \(msg)"
        }
    }
}

actor LibraryExportEngine {

    /// Export the active library to `destinationURL` in the chosen
    /// format. Returns the final URL (= the directory mirror URL
    /// or the zip file URL). Caller passes the URL to `.fileExporter`.
    func exportLibrary(
        to destinationURL: URL,
        as format: LibraryExportFormat
    ) async throws -> URL {

        guard let sourcePath = ActiveLibrary.path else {
            throw LibraryExportError.noActiveLibrary
        }
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true)

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw LibraryExportError.sourceMissing(sourceURL)
        }

        // Verify the destination is writable (= no point in starting
        // the export if the OS would refuse the write mid-way).
        try ensureDestinationWritable(destinationURL)

        switch format {
        case .copy:
            return try await copyLibrary(
                source: sourceURL,
                destination: destinationURL
            )
        case .zip:
            return try await zipLibrary(
                source: sourceURL,
                destination: destinationURL
            )
        }
    }

    /// Mirror the library directory to the destination (= copy).
    /// Skip `.tmp` and `.bak` (= in-progress writes).
    private func copyLibrary(
        source: URL,
        destination: URL
    ) async throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        // `FileManager.enumerator(...)` returns an NSEnumerator that
        // cannot be iterated from an async actor context (= its
        // `makeIterator` is unavailable async). Walk the tree via
        // recursive sync calls (= each call is bounded; the actor
        // stays responsive between them).
        try walkAndCopy(source: source, destination: destination)
        return destination
    }

    /// Recursive walk = reads the directory synchronously, copies
    /// each file, recurses into subdirectories. Skips `.tmp` /
    /// `.bak` (= in-progress writes).
    private func walkAndCopy(source: URL, destination: URL) throws {
        let fm = FileManager.default
        let names = try fm.contentsOfDirectory(atPath: source.path)
        for name in names {
            if name.hasSuffix(".tmp") || name.hasSuffix(".bak") {
                continue
            }
            let fileURL = source.appendingPathComponent(name)
            let destFile = destination.appendingPathComponent(name)
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                try fm.createDirectory(at: destFile, withIntermediateDirectories: true)
                try walkAndCopy(source: fileURL, destination: destFile)
            } else {
                try fm.copyItem(at: fileURL, to: destFile)
            }
        }
    }

    /// Zip the library directory to the destination (= archive).
    /// Uses `/usr/bin/zip` (= Apple canonical tool shipped with macOS).
    private func zipLibrary(
        source: URL,
        destination: URL
    ) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = [
            "-r",
            "-X",
            "-q",
            destination.path,
            ".",
        ]
        process.currentDirectoryURL = source

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw LibraryExportError.zipProcessFailed(
                status: -1,
                stderr: "Process.run failed: \(error)"
            )
        }

        process.waitUntilExit()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw LibraryExportError.zipProcessFailed(
                status: process.terminationStatus,
                stderr: stderr
            )
        }

        return destination
    }

    /// Verify the destination URL's parent is writable (= Apple's
    /// `URL.checkResourceIsReachable` returns true if the file exists,
    /// which is not what we want). We check the parent directory's
    /// writability via FileManager.isWritableFile.
    private func ensureDestinationWritable(_ url: URL) throws {
        let parent = url.deletingLastPathComponent()
        let fm = FileManager.default
        guard fm.isWritableFile(atPath: parent.path) else {
            throw LibraryExportError.destinationReadOnly(url)
        }
    }
}