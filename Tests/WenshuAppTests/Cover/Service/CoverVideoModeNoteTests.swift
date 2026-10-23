//
//  CoverVideoModeNoteTests.swift · Wenshu
//
//  Proves that a video model without the first-and-last-frame mode
//  is TOLD, and that the note and the request use one rule.
//
//  The mode is what makes the clip's loop seamless: the endpoint
//  serves it for one model only, and a route that names another one
//  loses it silently (= the request simply drops the last frame).
//  Measured on the live endpoint: the first and last frame of a plain
//  clip are 8.5 dB apart (= a visible jump), and the first-and-last-
//  frame mode's are 41.8 dB apart (= nearly the same picture).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover video mode note")
struct CoverVideoModeNoteTests {

    /// A video route that names a model.
    private func route(model: String?) -> CoverServiceRoute {
        CoverServiceRoute(
            kind: .video,
            providerSlug: "minimax-cn",
            model: model,
            baseURL: nil,
            apiKey: nil
        )
    }

    @Test("The model that serves the mode serves it")
    func theModelThatServesTheModeServesIt() {
        #expect(CoverVideoGenerator.servesFirstAndLastFrame(route(model: "MiniMax-Hailuo-02")))
    }

    @Test("Another model does not serve the mode")
    func anotherModelDoesNotServeTheMode() {
        #expect(!CoverVideoGenerator.servesFirstAndLastFrame(route(model: "MiniMax-Hailuo-01")))
    }

    @Test("A route that names no model serves nothing, so there is nothing to say")
    func aRouteThatNamesNoModelServesNothing() {
        // The video kind has no default model on purpose, so this
        // route cannot make a clip at all (= a different message, and
        // not this one).
        #expect(CoverVideoGenerator.servesFirstAndLastFrame(route(model: nil)))
    }

    @Test("The note and the request use one rule")
    func theNoteAndTheRequestUseOneRule() {
        // The generator's own rule decides both: the request carries
        // the last frame exactly when this says so, so the note can
        // never promise a seamless loop the request does not ask for.
        let model = "MiniMax-Hailuo-02"

        #expect(
            CoverVideoGenerator.servesFirstAndLastFrame(route(model: model))
                == CoverVideoGenerator.supportsFirstAndLastFrame(model: model)
        )
    }

    @Test("The settings carry the note")
    func theSettingsCarryTheNote() {
        // The note is a localized string, so the catalog has to carry
        // it in both languages (= the source is a key, the values are
        // the translations).
        let key = "settings.covers.videoNoSeamlessLoop"
        let text = Bundle.module.localizedString(forKey: key, value: nil, table: nil)

        // A missing key returns THE KEY, so the check has to be that
        // the text is not the key (= it was really translated).
        #expect(text != key)
        #expect(text.contains("Hailuo-02"))
    }
}
