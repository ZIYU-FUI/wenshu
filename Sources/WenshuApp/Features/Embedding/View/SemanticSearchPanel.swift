//
//  SemanticSearchPanel.swift
//  WenshuApp
//
//  §11.26 弧 ticket A2. macOS sheet that surfaces semantic search
//  results from SemanticSearchService. Triggered from the chat input
//  bar (= the existing "tools" button row). User types a query, hits
//  return, and the panel shows top-K matching entity body IDs with
//  cosine scores. The user can click a row to insert a citation into
//  the chat (= future ticket: the click currently copies to clipboard).
//

import SwiftUI

public struct SemanticSearchPanel: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [SemanticSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "search.semantic.title"))
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    SFIcon("xmark.circle.fill", style: .inlineSmall, color: IconColor.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Query field
            HStack {
                TextField(String(localized: "search.semantic.placeholder"), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(runSearch)
                Button(String(localized: "search.semantic.run")) { runSearch() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
            }
            .padding()

            if isSearching {
                ProgressView().padding()
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            // Results
            if !results.isEmpty {
                List(results, id: \.bodyID) { r in
                    HStack {
                        SFIcon("doc.text", style: .inlineSmall, color: IconColor.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.bodyID).font(.body)
                            Text(scoreLabel(r.score))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(String(localized: "search.semantic.copy")) {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(r.bodyID, forType: .string)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
                .listStyle(.inset)
            } else if !query.isEmpty && !isSearching && errorMessage == nil {
                Text(String(localized: "search.semantic.empty"))
                    .foregroundStyle(.secondary)
                    .padding()
            }

            Spacer()
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    private func scoreLabel(_ s: Float) -> String {
        let pct = Int((s * 100).rounded())
        return String(format: "%@ (%d%%)", String(localized: "search.semantic.score_label"), pct)
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        results = []
        Task {
            do {
                let r = try await SemanticSearchService.shared.search(query: q)
                await MainActor.run {
                    self.results = r
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
}
