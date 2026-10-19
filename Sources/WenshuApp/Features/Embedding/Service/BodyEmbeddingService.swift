//
//  BodyEmbeddingService.swift
//  WenshuApp
//
//  §11.26 弧 ticket A1. Wires WSBody writes (= the on-disk markdown
//  of an entity body) to WSBodyEmbedding rows. Fire-and-forget:
//  callers don't wait. Failures log and drop (= no retry storm;
//  user can manually re-trigger from Settings → 模型 if needed).
//
//  / Pattern (= per wenshu-pocock-workflow B.1 "做完一票拉起 APP 看一眼"
//  / cross-cut: embedding is a side-effect, NOT a hard dependency of
//  / the body write. The body write always succeeds first; the
//  / embedding eventually catches up.
//

import Foundation
import WenshuData

public actor BodyEmbeddingService {
    public static let shared = BodyEmbeddingService()

    private var inFlight: Set<String> = []   // bodyIDs currently being embedded

    /// Public entry point. Schedules an embed in the background. Safe to
    /// call from any thread (= the body write path). Idempotent for
    /// the same bodyID while a previous job is in flight (= second call
    /// is a no-op so we don't pile up requests on a single body).
    public func scheduleEmbedding(bodyID: String, markdown: String) {
        if inFlight.contains(bodyID) { return }
        inFlight.insert(bodyID)
        Task.detached(priority: .utility) { [weak self] in
            await self?.run(bodyID: bodyID, markdown: markdown)
        }
    }

    private func run(bodyID: String, markdown: String) async {
        defer { Task { await self.markDone(bodyID: bodyID) } }
        do {
            let kind = await EmbeddingService.shared.currentKind()
            let floats = try await EmbeddingService.shared.embed(markdown)
            try await persist(bodyID: bodyID, modelKindRaw: kind.rawValue, floats: floats)
        } catch {
            // Failure: log and drop (= the body is still saved; the user
            // can re-trigger via Settings → 模型 → "重试" if needed). We
            // intentionally don't throw to the caller — body writes must
            // not be blocked by embedding API failures.
            NSLog("[WenshuBodyEmbedding] failed bodyID=\(bodyID): \(error.localizedDescription)")
        }
    }

    private func markDone(bodyID: String) {
        inFlight.remove(bodyID)
    }

    @MainActor
    private func persist(bodyID: String, modelKindRaw: String, floats: [Float]) throws {
        let repo = WSBodyEmbeddingRepository()
        try repo.upsert(
            bodyID: bodyID,
            modelKindRaw: modelKindRaw,
            floats: floats,
            dimension: floats.count
        )
    }
}
