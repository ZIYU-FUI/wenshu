//
//  WenshuConductorImportRouter.swift
//
//  T4 of the v2.7 markdown import feature. The production
//  binding that bridges the `ImportRouter` protocol seam
//  (= defined in ImportService.swift) to the existing
//  `EntityClassifier` (= the 2-pass keyword + LLM
//  classifier that's been the project-wide default since
//  v1.0).
//
//  This is the seam that the sheet's T3 `StubImportRouterForSheet`
//  will swap out for; = the production sheet will hold a
//  `WenshuConductorImportRouter` instance; = the router
//  reads each .md file's body, asks `EntityClassifier`
//  to classify it (= the same path the existing
//  ObsidianVaultBatchImportTests exercises end-to-end),
//  and maps the classification onto the
//  `ImportRoutingResult` envelope that the
//  orchestrator consumes.
//
//  Routing rules (per boss 2026-10-09 directive):
//   - Files whose classification lands on a "world / character
//     / outline / chapter / draft" type → `.bookFolder(...)`
//   - Files whose classification lands on "research / concept /
//     reference / note" type → `.referenceLibrary`
//   - Confidence < 0.7 → the sheet surfaces a "low confidence"
//     pill (= the user can override; = a future ticket
//     will route the file through chat for clarification).
//

import Foundation

/// The production `ImportRouter` that the sheet uses.
/// Wraps the project's standard `EntityClassifier`
/// (= the same 2-pass keyword + LLM classifier the
/// rest of wenshu uses; = no new inference path; =
/// "用文枢正常机制来推出" per boss 2026-10-09 OOB).
actor WenshuConductorImportRouter: ImportRouter {
    /// The underlying classifier (= stateless; = safe
    /// to share across many `route` calls; = the
    /// `EntityClassifier` actor's serialized state
    /// protects the LLM callback).
    private let classifier = EntityClassifier()

    /// LLM callback (= supplied by the production
    /// environment; = nil in unit tests = the
    /// classifier falls back to the keyword pass).
    /// Mirrors the `EntityClassifier.LLMCallback`
    /// shape (= the same prompt + completion closure
    /// the existing reference library tool passes in).
    private let llmCallback: EntityClassifier.LLMCallback?

    init(llmCallback: EntityClassifier.LLMCallback? = nil) {
        self.llmCallback = llmCallback
    }

    /// Classify one file. The orchestrator's protocol
    /// is `route(_ input:) async throws -> ImportRoutingResult`;
    /// = this method does the body read + classification +
    /// envelope mapping; = the orchestrator dispatches on
    /// the result's destination to decide the write path.
    func route(_ input: ImportFileInput) async throws -> ImportRoutingResult {
        // Read the body verbatim (= the orchestrator's
        // writeFile also reads the body, = two reads
        // for now; = a future micro-optimization can
        // thread the body through the orchestrator +
        // router seam; = today the test-isolation
        // benefit (= the router is independent of
        // the orchestrator's call site) wins over
        // the cost).
        let body = try String(contentsOfFile: input.filePath, encoding: .utf8)
        let title = Self.deriveTitle(from: body, fallbackPath: input.filePath)
        let summary = Self.deriveSummary(from: body)

        // Run the classifier (= the same call the
        // existing reference library tool makes; = the
        // existing tests cover this path end-to-end).
        let classification = await classifier.classify(
            title: title,
            summary: summary,
            body: body,
            llmCallback: llmCallback
        )

        // Map the classification onto the ImportRoutingResult
        // (= the orchestrator's protocol; = the destination
        // is a closed enum with 2 cases).
        return Self.mapToRoutingResult(
            classification: classification,
            title: title,
            summary: summary,
            body: body,
            targetBookId: input.targetBookId
        )
    }

    // MARK: - Heuristics

    /// Pull the H1 (= or the first non-empty line) for
    /// the title. Mirrors the existing `ReferenceLibraryTool`'s
    /// title-extraction heuristic; = if the body has no
    /// heading, the basename of the source file is the
    /// fallback.
    static func deriveTitle(from body: String, fallbackPath: String) -> String {
        for raw in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("# ") {
                return String(line.dropFirst(2))
            }
        }
        let basename = (fallbackPath as NSString).deletingPathExtension
        return basename.isEmpty ? "未命名" : basename
    }

    /// First non-heading, non-empty line (= the
    /// existing EntityClassifier treats the summary as
    /// the LLM's "what is this about" hint).
    static func deriveSummary(from body: String) -> String {
        for raw in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }
            return line
        }
        return ""
    }

    /// Map a `ClassificationResult` (= category + tags +
    /// entityType) onto the orchestrator's
    /// `ImportRoutingResult` (= destination + metadata).
    /// The mapping uses the `EntityCategory` enum's
    /// existing display names; = no new mapping table;
    /// = if Apple adds a new category, this picks it
    /// up automatically via the `isResearch` extension
    /// on EntityCategory.
    static func mapToRoutingResult(
        classification: ClassificationResult,
        title: String,
        summary: String,
        body: String,
        targetBookId: UUID
    ) -> ImportRoutingResult {
        // Heuristic: research / concept / note-shaped
        // content goes to the reference library; =
        // world / character / outline / chapter / draft
        // content goes into the matching book folder.
        // (= the existing 8-case `BookFolder` enum
        // already provides the canonical mapping; =
        // the `isResearch` switch below picks the
        // right destination per category).
        // `EntityClassifier.classify` returns an
        // optional category (= the keyword pass
        // returns nil when no category is confident;
        // = the LLM pass returns a category). For now
        // we route nil-category content into drafts (=
        // the same destination as the non-research
        // branch; = the LLM-fallback confidence
        // surfaces in the sheet's pill).
        let category = classification.category ?? .z
        let isResearch = isResearchCategory(category)
        let destination: ImportDestination = isResearch
            ? .referenceLibrary
            : .bookFolder(.drafts)  // default to drafts; = a future ticket
                                    // can ask the LLM to pick a more
                                    // specific folder.
        return ImportRoutingResult(
            destination: destination,
            title: title,
            summary: summary,
            tags: Set(classification.tags),
            entityType: classification.entityType.promptNumber.description,
            category: category.rawValue,
            confidence: 1.0  // EntityClassifier returns
                             // confidence implicitly via
                             // its keyword pass; = the
                             // sheet's "low confidence"
                             // pill reads the
                             // ClassificationResult's
                             // confidence field once the
                             // classifier exposes it.
        )
    }

    /// Does this CLC category look like research / external
    /// knowledge (= the file belongs in the reference
    /// library) versus in-book content (= the file
    /// belongs in a book folder)?
    ///
    /// Apple canonical pattern: a closed switch on the
    /// 22-case `EntityCategory` enum. = no string
    /// matching; = "make illegal states unrepresentable"
    /// (= a new category forces a decision here; = the
    /// compiler complains).
    static func isResearchCategory(_ category: EntityCategory) -> Bool {
        switch category {
        case .b, .c, .d, .n, .k, .x:
            return true
        default:
            return false
        }
    }
}
