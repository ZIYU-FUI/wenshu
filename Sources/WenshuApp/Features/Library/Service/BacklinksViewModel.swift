// BacklinksViewModel.swift
//
// @MainActor Observable for the Backlinks panel (= SwiftUI-free:
// the SwiftUI surface lives in `BacklinksPanel`).

import Foundation

/// BacklinksViewModel: @MainActor Observable (= no SwiftUI import; SwiftUI-free per A1.1)
@MainActor
@Observable
final class BacklinksViewModel {
    private(set) var docId: String = ""
    private(set) var backlinks: [Link] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String? = nil

    private let resolver: BacklinkResolver?
    private let documentIndex: DocumentIndexing?

    init(resolver: BacklinkResolver? = nil, documentIndex: DocumentIndexing? = nil) {
        self.resolver = resolver
        self.documentIndex = documentIndex
    }

    /// load docId backlinks
    func load(docId: String) async {
        self.docId = docId
        self.isLoading = true
        self.error = nil
        defer { self.isLoading = false }

        guard let resolver else {
            // macOS resolver. group
            self.backlinks = []
            return
        }
        do {
            let result = try await resolver.backlinks(forDocId: docId)
            self.backlinks = result
        } catch {
            self.error = "\(error)"
            self.backlinks = []
        }
    }
}