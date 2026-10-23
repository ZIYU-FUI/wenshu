//
//  Features/Cover/Service/CoverVideoGenerator.swift
//
//   : CoverVideoGenerator.
//  Turns a card's still cover into a short looping clip.
//
//  The endpoint and its contract, all verified against the live
//  MiniMax API on 2026-10-22:
//
//  - POST https://api.minimaxi.com/v1/video_generation creates the
//    task. The body is {model, first_frame_image, duration,
//    resolution, prompt_optimizer} and the answer carries a task_id.
//  - GET /v1/query/video_generation?task_id=... polls it. The status
//    goes Processing and then Success, and a Success carries a
//    file_id.
//  - GET /v1/files/retrieve?file_id=... turns the file id into a
//    download URL. That URL EXPIRES IN ABOUT NINE HOURS, so the file
//    is downloaded immediately and the URL is never stored.
//
//  The first frame is the card's still cover, converted from the
//  stored HEIC to a JPEG in memory (the endpoint takes JPG, JPEG, PNG
//  and WebP, and NOT HEIC). That is what makes the moving cover and
//  the still cover the same scene, so switching between them on hover
//  does not jump.
//
//  The poller treats an empty or non-JSON answer as "not ready yet" and
//  retries: the endpoint does that intermittently mid-poll, and it is
//  not a failure.
//

import Foundation
import WenshuAgent

/// The video call, behind a protocol so the service can be tested
/// without a network call.
protocol CoverVideoClient: Sendable {
    /// Makes a clip from a first frame and returns the clip's bytes.
    ///
    /// - Parameters:
    ///   - firstFrameJPEG: the still cover, as a JPEG.
    ///   - prompt: what the clip should show.
    ///   - service: where the clip is made (= the endpoint, the
    ///     model and the key). It comes from the route, so the
    ///     user's own video service is the one that answers.
    func makeVideo(
        firstFrameJPEG: Data,
        prompt: String,
        service: ResolvedCoverService
    ) async throws -> Data
}

/// Makes a clip from a still cover.
struct CoverVideoGenerator: CoverVideoClient {

    /// The task-creation endpoint.
    static let createEndpoint = "https://api.minimaxi.com/v1/video_generation"
    /// The task-query endpoint.
    static let queryEndpoint = "https://api.minimaxi.com/v1/query/video_generation"
    /// The file-retrieval endpoint.
    static let filesEndpoint = "https://api.minimaxi.com/v1/files/retrieve"

    /// The model that was verified against the live endpoint.
    static let model = "MiniMax-Hailuo-02"

    /// The clip length in seconds.
    static let duration = CoverMiniMaxVideoDialect.duration
    /// The clip resolution.
    static let resolution = CoverMiniMaxVideoDialect.resolution

    /// The provider whose key and quota pay for a clip.
    static let providerSlug = "minimax-cn"

    /// The provider profile for the video service.
    static var provider: Provider {
        Provider.by(slug: providerSlug) ?? .minimaxCn
    }

    /// How long to wait between polls.
    static let pollInterval = Duration.seconds(3)

    /// How many times to poll before giving up.
    ///
    /// The task QUEUES before it runs, and the queue can hold a
    /// request for minutes: measured 2026-10-23, one clip was ready
    /// in 45 s and the next one was still queued after two minutes.
    /// A budget of 120 s gave up on a task that was about to succeed
    /// and threw the day's clip away.
    ///
    /// At the poll interval below this is ten minutes, which is long
    /// enough for a queue and short enough that a task that will
    /// never arrive does not hang the card for ever.
    static let maxPolls = 200

    /// The endpoint's limit on the prompt, in characters.
    ///
    /// From the endpoint's own documentation of the i2v body: the
    /// prompt is "the text description of the video, max 2000
    /// characters". A longer one is refused, so the body carries a
    /// capped prompt rather than one the endpoint will reject.
    static let promptCharacterLimit = 2000

    /// The body of a task-creation request.
    ///
    /// Pure and static so the test can read it without a network
    /// call. It is a function of its own because the prompt has to
    /// be IN the body, and a prompt that a function accepts and then
    /// drops is exactly the bug this fixes: the endpoint was given
    /// a picture and no instruction at all, and it invented whatever
    /// motion it liked.
    static func requestBody(
        firstFrameDataURL: String,
        prompt: String,
        model: String = model
    ) -> [String: Any] {
        CoverMiniMaxVideoDialect.requestBody(
            firstFrameDataURL: firstFrameDataURL,
            prompt: prompt,
            model: model
        )
    }

    /// The body of a task-creation request, as MiniMax wants it.
    ///
    /// The implementation lives in the dialect (= the protocol the
    /// app speaks for this service), and the name above stays for the
    /// tests and the older call sites.
    private static func miniMaxRequestBody(
        firstFrameDataURL: String,
        prompt: String,
        model: String
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "first_frame_image": firstFrameDataURL,
            "prompt": cappedPrompt(prompt),
            "duration": duration,
            "resolution": resolution,
            // The endpoint's own note: false is what gives precise
            // control. Left at its default (true) the endpoint
            // REWRITES the prompt, and what it adds is camera
            // movement of its own.
            "prompt_optimizer": false,
        ]

        // The FIRST-AND-LAST-FRAME mode, which is the same endpoint
        // with one more field: the clip ends on the picture it
        // started from, so the loop has no seam. The app's
        // convention is that the two frames are the SAME picture, so
        // the clip is one small movement that comes back to where it
        // began.
        //
        // The endpoint's spec for this mode names one model, and it
        // is the model the cover's video route uses. A model that is
        // not on the list must not get the field: the endpoint
        // answers "model not available" for a mode it does not
        // serve.
        if supportsFirstAndLastFrame(model: model) {
            body["last_frame_image"] = firstFrameDataURL
        }

        return body
    }

    /// Whether a model serves the first-and-last-frame mode.
    ///
    /// The endpoint's own specification of that mode lists one model
    /// (`MiniMax-Hailuo-02`), and it does not serve the mode at
    /// 512P.
    static func supportsFirstAndLastFrame(model: String) -> Bool {
        CoverMiniMaxVideoDialect.supportsFirstAndLastFrame(model: model)
    }

    /// Whether a route's video model serves the first-and-last-frame
    /// mode.
    ///
    /// The mode is what makes the clip's loop seamless, and the
    /// endpoint serves it for one model only. A route that names
    /// another model loses the mode SILENTLY (= the request simply
    /// drops the last frame), so the settings have to say so: the
    /// measured difference is a first/last frame 8.5 dB apart (= a
    /// visible jump at the seam) against 41.8 dB (= nearly the same
    /// picture).
    ///
    /// A route that names no model serves nothing (= the video kind
    /// has no default on purpose), so it is not a loss and there is
    /// nothing to say.
    static func servesFirstAndLastFrame(_ route: CoverServiceRoute) -> Bool {
        guard let model = route.model ?? route.kind.defaultModel else { return true }
        return CoverVideoDialectRegistry.dialect(for: route)
            .servesSeamlessLoop(model: model)
    }

    /// The prompt, within the endpoint's limit.
    static func cappedPrompt(_ prompt: String) -> String {
        CoverMiniMaxVideoDialect.cappedPrompt(prompt)
    }

    /// Makes a clip from a first frame.
    ///
    /// - Parameters:
    ///   - firstFrameJPEG: the still cover, as a JPEG.
    ///   - prompt: what the clip should show.
    ///   - service: where the clip is made. The endpoint, the model
    ///     and the key all come from the route.
    func makeVideo(
        firstFrameJPEG: Data,
        prompt: String,
        service: ResolvedCoverService
    ) async throws -> Data {
        guard let key = service.apiKey, !key.isEmpty else {
            throw CoverVideoError.missingKey(service.providerSlug)
        }

        // The dialect is the service's own protocol: the endpoint,
        // the body, the answer, the poll and the failure are all its
        // shape, and the generator drives it without knowing any of
        // them.
        let dialect = CoverVideoDialectRegistry.dialect(for: service)
        let dataURL = "data:image/jpeg;base64,\(firstFrameJPEG.base64EncodedString())"
        let request = try dialect.createRequest(
            prompt: prompt,
            firstFrameDataURL: dataURL,
            lastFrameDataURL: dataURL,
            service: service
        )
        let (created, _) = try await send(request, service: service)
        var job = try dialect.parseCreate(created, status: 200)

        let fileHandle = try await pollForFile(job: job, dialect: dialect, service: service)
        job.fileHandle = fileHandle

        // A service that answers with the bytes ends here.
        if let bytes = try dialect.videoBytes(from: created) {
            return bytes
        }
        guard let fileRequest = try dialect.fileRequest(job: job, service: service) else {
            throw CoverVideoError.noFile
        }
        let (fileData, _) = try await send(fileRequest, service: service)
        guard let url = try dialect.parseFile(fileData) else {
            throw CoverVideoError.noDownloadURL
        }
        return try await download(url: url, service: service)
    }

    // MARK: - The three calls

    /// Sends one request and reads the answer.
    ///
    /// The failure is classified before it is reported, so the
    /// message says what the user has to do: the body carries the
    /// service's own words (= "insufficient balance"), and the
    /// status alone cannot tell an empty account from a rate limit
    /// (= both are 429).
    private func send(
        _ request: URLRequest,
        service: ResolvedCoverService
    ) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard (200..<300).contains(status) else {
            let dialect = CoverVideoDialectRegistry.dialect(for: service)
            if let failure = dialect.failure(from: data, status: status) {
                throw CoverVideoError.providerFailure(failure)
            }
            throw CoverVideoError.httpStatus(status)
        }
        return (data, status)
    }

    /// Polls the job until it succeeds.
    private func pollForFile(
        job: CoverVideoJob,
        dialect: any CoverVideoDialect,
        service: ResolvedCoverService
    ) async throws -> String? {
        let request = try dialect.pollRequest(job: job, service: service)

        for _ in 0..<Self.maxPolls {
            let (data, _) = try await send(request, service: service)
            switch try dialect.parsePoll(data) {
            case .pending:
                try await Task.sleep(for: Self.pollInterval)
            case .succeeded(let handle):
                return handle
            case .failed(let message):
                throw CoverVideoError.taskFailed(message)
            }
        }
        throw CoverVideoError.timedOut
    }

    /// Downloads the clip.
    ///
    /// The address is the service's own and it expires (MiniMax's
    /// runs about nine hours), which is why the bytes are downloaded
    /// immediately and the address is never stored.
    private func download(url: URL, service: ResolvedCoverService) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard (200..<300).contains(status) else {
            let dialect = CoverVideoDialectRegistry.dialect(for: service)
            if let failure = dialect.failure(from: data, status: status) {
                throw CoverVideoError.providerFailure(failure)
            }
            throw CoverVideoError.httpStatus(status)
        }
        return data
    }

}

enum CoverVideoError: LocalizedError {
    case missingKey(String)
    case httpStatus(Int)
    case noTask
    case noFile
    case noStillCover
    case noDownloadURL
    case taskFailed(String)
    case timedOut

    /// The provider refused the call for a reason the user has to act
    /// on (= the account has no quota, the plan does not cover the
    /// model, the key is wrong, the service is rate limiting).
    ///
    /// This case exists so the failure says WHAT to do. Before it,
    /// a spent account read as "the video service did not return a
    /// task", which is a description of the app and not of the
    /// account.
    case providerFailure(CoverProviderFailure)

    var errorDescription: String? {
        switch self {
        case .missingKey(let slug):
            return "No API key is configured for \(slug), so a moving cover cannot be made."
        case .httpStatus(let code):
            return "The video service answered with HTTP \(code)."
        case .noTask:
            return "The video service did not return a task."
        case .noFile:
            return "The video service finished without a file."
        case .noStillCover:
            return "This card has no still cover, so there is nothing to make move. Generate a cover first."
        case .noDownloadURL:
            return "The video service did not return a download URL."
        case .taskFailed(let reason):
            return "The video service could not make the clip: \(reason)."
        case .timedOut:
            return "The video service did not finish in time."
        case .providerFailure(let failure):
            return failure.userMessage
        }
    }
}
