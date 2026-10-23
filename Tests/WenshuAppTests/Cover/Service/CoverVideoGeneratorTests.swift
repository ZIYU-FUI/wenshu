//
//  CoverVideoGeneratorTests.swift · Wenshu
//
//  Proves the request the video endpoint receives, WITHOUT a network
//  call.
//
//  The bug these tests are here for: the generator took a prompt and
//  built a request body without it, so the endpoint was given a
//  picture and NO instruction, and it invented whatever motion it
//  liked. On a still life that means a slow push across the frame.
//
//  So the body is a pure function of its own, and the test reads it.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover video request")
struct CoverVideoGeneratorTests {

    /// The body the generator sends.
    private func body(prompt: String) -> [String: Any] {
        CoverVideoGenerator.requestBody(
            firstFrameDataURL: "data:image/jpeg;base64,AAAA",
            prompt: prompt
        )
    }

    @Test("The request body carries the prompt")
    func theBodyCarriesThePrompt() {
        let sent = body(prompt: "a light breeze")

        // This is the regression: before the fix the body had no
        // "prompt" key at all, and the model never saw an
        // instruction.
        #expect(sent["prompt"] as? String == "a light breeze")
    }

    @Test("The body keeps the settings the endpoint was measured with")
    func theBodyKeepsTheMeasuredSettings() {
        let sent = body(prompt: "a light breeze")

        #expect(sent["model"] as? String == CoverVideoGenerator.model)
        #expect(sent["duration"] as? Int == CoverVideoGenerator.duration)
        #expect(sent["resolution"] as? String == CoverVideoGenerator.resolution)
        #expect(sent["first_frame_image"] as? String
                == "data:image/jpeg;base64,AAAA")

        // The endpoint's own note: false is what gives precise
        // control. Left at its default the endpoint rewrites the
        // prompt, and what it adds is camera movement of its own.
        #expect(sent["prompt_optimizer"] as? Bool == false)
    }

    @Test("A prompt longer than the endpoint allows is capped")
    func aLongPromptIsCapped() {
        let long = String(repeating: "x", count: CoverVideoGenerator.promptCharacterLimit + 500)
        let sent = body(prompt: long)

        let carried = sent["prompt"] as? String ?? ""
        #expect(carried.count == CoverVideoGenerator.promptCharacterLimit)
    }

    @Test("A prompt within the limit is carried whole")
    func aShortPromptIsCarriedWhole() {
        let sent = body(prompt: "a light breeze through the branches")

        #expect(sent["prompt"] as? String == "a light breeze through the branches")
    }

    @Test("The motion prompt asks for a breeze and locks the camera")
    @MainActor
    func theMotionPromptIsABreezeAndNotACameraMove() {
        let prompt = CoverVideoService.motionPrompt
        let lower = prompt.lowercased()

        // The subject is a still life. The instruction has to say
        // what moves, or the model invents a camera move.
        #expect(lower.contains("breeze"))
        #expect(lower.contains("camera is completely locked"))

        // The endpoint's camera instructions are bracketed tokens, so
        // the prompt may carry the fixed-camera one and nothing else.
        // It cannot then ask for a move.
        #expect(bracketedTokens(in: prompt) == ["固定"])
    }

    /// The bracketed tokens in a string, in order.
    private func bracketedTokens(in text: String) -> [String] {
        var tokens: [String] = []
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "["),
              let close = rest[open...].firstIndex(of: "]") {
            tokens.append(String(rest[rest.index(after: open)..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return tokens
    }
}
