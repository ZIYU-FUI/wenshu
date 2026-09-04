//
//  FileSystemLibraryStoreForceUnwrapFixTests.swift · Wenshu · v0.23 audit #014
//
//  Boss 2026-08-23 拍: '重点是你如何规避风险'.
//  Standards audit found FileSystemLibraryStore.swift:514 had force unwrap
//  `categoryDirectory(...)!` which would crash on corrupted library state.
//  Fix: documentPath now throws LibraryStoringError.parentBookNotFound.
//  Tests verify the fix doesn't crash and throws proper error.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("FileSystemLibraryStore force-unwrap fix (audit #014)")
struct FileSystemLibraryStoreForceUnwrapFixTests {

    @Test("documentPath throws parentBookNotFound when book dir missing (not crash)")
    func testDocumentPathThrowsOnMissingBook() throws {
        let fm = FileManager.default
        let tempRoot = NSTemporaryDirectory() + "wenshu-lib-fix-\(UUID().uuidString)"
        try fm.createDirectory(atPath: tempRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: tempRoot) }

        let store = FileSystemLibraryStore(rootURL: URL(fileURLWithPath: tempRoot))
        let shelfId = UUID()
        let bookId = UUID()  // Book does NOT exist on disk
        let docId = UUID()

        // Try to load document for non-existent book → should throw, NOT crash.
        do {
            _ = try store.loadDocumentContent(id: docId, bookId: bookId, category: .chapter)
            Issue.record("expected throw, got success")
        } catch let error as LibraryStoringError {
            // Expected: parentBookNotFound(bookId)
            if case .parentBookNotFound(let errorBookId) = error.kind {
                #expect(errorBookId == bookId)
            } else {
                Issue.record("expected parentBookNotFound, got \(error.kind)")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("deleteDocument throws parentBookNotFound when book dir missing")
    func testDeleteDocumentThrowsOnMissingBook() throws {
        let fm = FileManager.default
        let tempRoot = NSTemporaryDirectory() + "wenshu-lib-fix-delete-\(UUID().uuidString)"
        try fm.createDirectory(atPath: tempRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: tempRoot) }

        let store = FileSystemLibraryStore(rootURL: URL(fileURLWithPath: tempRoot))
        let bookId = UUID()
        let docId = UUID()

        do {
            try store.deleteDocument(id: docId, bookId: bookId, category: .chapter)
            Issue.record("expected throw")
        } catch let error as LibraryStoringError {
            if case .parentBookNotFound(let errorBookId) = error.kind {
                #expect(errorBookId == bookId)
            } else {
                Issue.record("expected parentBookNotFound, got \(error.kind)")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("saveDocument throws parentBookNotFound when book dir missing")
    func testSaveDocumentThrowsOnMissingBook() throws {
        let fm = FileManager.default
        let tempRoot = NSTemporaryDirectory() + "wenshu-lib-fix-save-\(UUID().uuidString)"
        try fm.createDirectory(atPath: tempRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: tempRoot) }

        let store = FileSystemLibraryStore(rootURL: URL(fileURLWithPath: tempRoot))
        let bookId = UUID()
        let docId = UUID()

        do {
            try store.saveDocument(id: docId, bookId: bookId, category: .chapter, content: "test")
            Issue.record("expected throw")
        } catch let error as LibraryStoringError {
            if case .parentBookNotFound(let errorBookId) = error.kind {
                #expect(errorBookId == bookId)
            } else {
                Issue.record("expected parentBookNotFound, got \(error.kind)")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}