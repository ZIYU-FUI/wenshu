//
//  CoverVideoDialectTests.swift · Wenshu
//
//  Proves that a dialect is where a service's protocol lives, and
//  that the registry picks the right one.
//
//  The point of the layer: the app used to speak ONE cover protocol
//  (= MiniMax's), and the feature is aimed at the users who will use
//  Wenshu, so the protocol became something the app LOOKS UP. The
//  "does this service serve the first-and-last-frame mode" question
//  is a fact about a (service, model) PAIR, and OpenRouter publishes
//  it per model in its model list, so a hard-coded model string
//  cannot carry it.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover video dialect")
struct CoverVideoDialectTests {

    /// A resolved service on MiniMax's own endpoint.
    private func minimaxService(model: String = "MiniMax-Hailuo-02") -> ResolvedCoverService {
        ResolvedCoverService(
            providerSlug: "minimax-cn",
            model: model,
            baseURL: "https://api.minimaxi.com/v1/video_generation",
            apiKey: "a-key"
        )
    }

    @Test("The MiniMax provider gets MiniMax's dialect")
    func theMiniMaxProviderGetsMiniMaxsDialect() {
        #expect(
            CoverVideoDialectRegistry.dialect(for: minimaxService())
                is CoverMiniMaxVideoDialect
        )
        #expect(
            CoverVideoDialectRegistry.dialect(
                for: minimaxService().replacingProvider(slug: "minimax")
            ) is CoverMiniMaxVideoDialect
        )
    }

    @Test("An endpoint of the user's own on a cover host gets MiniMax's dialect")
    func anEndpointOnACoverHostGetsMiniMaxsDialect() {
        let service = ResolvedCoverService(
            providerSlug: "custom",
            model: "MiniMax-Hailuo-02",
            baseURL: "https://api.minimaxi.com/v1/video_generation",
            apiKey: "a-key"
        )

        #expect(CoverVideoDialectRegistry.dialect(for: service) is CoverMiniMaxVideoDialect)
    }

    @Test("The create request carries the prompt and the frames")
    func theCreateRequestCarriesThePromptAndTheFrames() throws {
        let dialect = CoverMiniMaxVideoDialect()

        let request = try dialect.createRequest(
            prompt: "a light breeze",
            firstFrameDataURL: "data:image/jpeg;base64,AAAA",
            lastFrameDataURL: "data:image/jpeg;base64,AAAA",
            service: minimaxService()
        )

        let body = try #require(
            JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        )
        #expect(body["model"] as? String == "MiniMax-Hailuo-02")
        #expect(body["prompt"] as? String == "a light breeze")
        #expect(body["first_frame_image"] as? String == "data:image/jpeg;base64,AAAA")
        // The mode: the same picture as the last frame.
        #expect(body["last_frame_image"] as? String == "data:image/jpeg;base64,AAAA")
        #expect(request.httpMethod == "POST")
    }

    @Test("A model that does not serve the mode gets no last frame")
    func aModelThatDoesNotServeTheModeGetsNoLastFrame() throws {
        let dialect = CoverMiniMaxVideoDialect()

        let request = try dialect.createRequest(
            prompt: "a light breeze",
            firstFrameDataURL: "data:image/jpeg;base64,AAAA",
            lastFrameDataURL: "data:image/jpeg;base64,AAAA",
            service: minimaxService(model: "some-other-model")
        )

        let body = try #require(
            JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        )
        #expect(body["last_frame_image"] == nil)
    }

    @Test("The create answer carries the job's id")
    func theCreateAnswerCarriesTheJobsId() throws {
        let dialect = CoverMiniMaxVideoDialect()
        let answer = Data(#"{"task_id":"abc123","base_resp":{"status_code":0}}"#.utf8)

        let job = try dialect.parseCreate(answer, status: 200)

        #expect(job.id == "abc123")
    }

    @Test("A failure inside a 200 body is a failure, not a missing task")
    func aFailureInsideA200BodyIsAFailure() {
        let dialect = CoverMiniMaxVideoDialect()
        let answer = Data(
            #"{"base_resp":{"status_code":2056,"status_msg":"the plan's allowance is used up"}}"#.utf8
        )

        #expect(throws: CoverVideoError.self) {
            try dialect.parseCreate(answer, status: 200)
        }
    }

    @Test("The poll reads the service's own states")
    func thePollReadsTheServicesOwnStates() throws {
        let dialect = CoverMiniMaxVideoDialect()

        let succeeded = try dialect.parsePoll(
            Data(#"{"status":"Success","file_id":"file-1"}"#.utf8)
        )
        #expect(succeeded == .succeeded(fileHandle: "file-1"))

        let failed = try dialect.parsePoll(
            Data(#"{"status":"Failed","task_status":"the model is not available"}"#.utf8)
        )
        #expect(failed == .failed("the model is not available"))

        // An empty or non-JSON body mid-poll means "not ready yet".
        let pending = try dialect.parsePoll(Data())
        #expect(pending == .pending)
    }

    @Test("The seamless-loop rule comes from the dialect")
    func theSeamlessLoopRuleComesFromTheDialect() {
        let dialect = CoverMiniMaxVideoDialect()

        #expect(dialect.servesSeamlessLoop(model: "MiniMax-Hailuo-02"))
        #expect(dialect.servesSeamlessLoop(model: "some-other-model") == false)
    }
}

private extension ResolvedCoverService {
    /// The same service on another provider slug.
    func replacingProvider(slug: String) -> ResolvedCoverService {
        ResolvedCoverService(
            providerSlug: slug,
            model: model,
            baseURL: baseURL,
            apiKey: apiKey
        )
    }
}
