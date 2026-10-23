//
//  Features/Cover/Service/CoverPaneServices.swift
//
//   : CoverPaneServices.
//  The ONE set of cover services the material zone uses.
//
//  The per-card lock lives in CoverGenerationService, and the lock is
//  per INSTANCE. Two instances are two lock sets, so a batch run and a
//  manual click on the same card would each spend an image call, which
//  is exactly the allowance waste the cover feature exists to avoid.
//
//  So there is ONE holder, and every path that can start a generation
//  goes through it:
//
//    the card menu   -> services.generation
//    the batch       -> services.batch      (same generation service)
//    the automatic  -> services.autoTrigger (same generation service)
//
//  The holder is the single place where the shared instance is built.
//  A path that builds its own service is a path with its own lock.
//
//

import Foundation
import Observation
import SwiftData
import WenshuData

/// The cover services one material zone shares.
@MainActor
@Observable
final class CoverPaneServices {

    /// The service that draws a card's cover.
    ///
    /// One instance for the whole pane, so the per-card lock is
    /// shared: two requests for the same card make ONE image call.
    let generation: CoverGenerationService

    /// The batch, over the SAME generation service.
    let batch: CoverBatchService

    /// The automatic pass, over the SAME generation service.
    let autoTrigger: CoverAutoTrigger

    init(
        imageClient: CoverImageClient = CoverImageGenerator()
    ) {
        let generation = CoverGenerationService(imageClient: imageClient)
        self.generation = generation
        self.batch = CoverBatchService(generationService: generation)
        self.autoTrigger = CoverAutoTrigger(generationService: generation)
    }

    /// The services over the library the app is running on.
    static func live() -> CoverPaneServices {
        CoverPaneServices()
    }
}
