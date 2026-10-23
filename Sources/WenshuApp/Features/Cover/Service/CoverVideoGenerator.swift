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
    static let duration = 6
    /// The clip resolution.
    static let resolution = "768P"

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
        model == "MiniMax-Hailuo-02"
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
        return supportsFirstAndLastFrame(model: model)
    }

    /// The prompt, within the endpoint's limit.
    static func cappedPrompt(_ prompt: String) -> String {
        guard prompt.count > promptCharacterLimit else { return prompt }
        return String(prompt.prefix(promptCharacterLimit))
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

        let dataURL = "data:image/jpeg;base64,\(firstFrameJPEG.base64EncodedString())"
        let body = Self.requestBody(
            firstFrameDataURL: dataURL,
            prompt: prompt,
            model: service.model
        )
        let created = try await post(
            endpoint: service.baseURL,
            key: key,
            body: body,
            as: CoverVideoCreateResponse.self,
            providerSlug: service.providerSlug,
            model: service.model
        )
        // The provider reports its own failure INSIDE a 200 body, so
        // the answer is read before the task id is. Without this a
        // spent account reads as "the video service did not return a
        // task", which tells the user nothing at all.
        if let code = created.baseResp?.statusCode, code != 0 {
            let detail = created.baseResp?.statusMessage
            if let failure = CoverProviderFailure.classify(
                providerSlug: service.providerSlug,
                providerCode: code,
                detail: detail,
                model: service.model
            ) {
                throw CoverVideoError.providerFailure(failure)
            }
            throw CoverVideoError.taskFailed(detail ?? "the service refused the request (\(code))")
        }
        guard let taskId = created.taskId, !taskId.isEmpty else {
            throw CoverVideoError.noTask
        }

        let fileId = try await pollForFile(taskId: taskId, key: key, service: service)
        let url = try await downloadURL(fileId: fileId, key: key, service: service)
        return try await download(url: url, service: service)
    }

    // MARK: - The three calls

    /// Creates the task.
    private func post<Response: Decodable>(
        endpoint: String,
        key: String,
        body: [String: Any],
        as: Response.Type,
        providerSlug: String,
        model: String
    ) async throws -> Response {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkStatus(
            response,
            body: data,
            providerSlug: providerSlug,
            model: model
        )
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Polls the task until it succeeds.
    private func pollForFile(
        taskId: String,
        key: String,
        service: ResolvedCoverService
    ) async throws -> String {
        var urlComponents = URLComponents(string: Self.queryEndpoint)!
        urlComponents.queryItems = [URLQueryItem(name: "task_id", value: taskId)]
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        for _ in 0..<Self.maxPolls {
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.checkStatus(
                response,
                providerSlug: service.providerSlug,
                model: service.model
            )

            // The endpoint intermittently answers with an empty or a
            // non-JSON body mid-poll. That is not a failure: it means
            // "not ready yet", so the poll continues.
            guard let payload = try? JSONDecoder().decode(CoverVideoQueryResponse.self, from: data) else {
                try await Task.sleep(for: Self.pollInterval)
                continue
            }
            switch payload.status {
            case "Success":
                guard let fileId = payload.fileId, !fileId.isEmpty else {
                    throw CoverVideoError.noFile
                }
                return fileId
            case "Failed":
                throw CoverVideoError.taskFailed(payload.taskStatus ?? "no reason given")
            default:
                try await Task.sleep(for: Self.pollInterval)
            }
        }
        throw CoverVideoError.timedOut
    }

    /// Turns the file id into a download URL.
    ///
    /// The URL expires in about nine hours, which is why the caller
    /// downloads the file immediately and never stores the URL.
    private func downloadURL(
        fileId: String,
        key: String,
        service: ResolvedCoverService
    ) async throws -> URL {
        var urlComponents = URLComponents(string: Self.filesEndpoint)!
        urlComponents.queryItems = [URLQueryItem(name: "file_id", value: fileId)]
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkStatus(
            response,
            providerSlug: service.providerSlug,
            model: service.model
        )
        let payload = try JSONDecoder().decode(CoverVideoFilesResponse.self, from: data)
        guard let urlString = payload.file?.downloadUrl,
              let url = URL(string: urlString) else {
            throw CoverVideoError.noDownloadURL
        }
        return url
    }

    /// Downloads the clip.
    private func download(url: URL, service: ResolvedCoverService) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.checkStatus(
            response,
            providerSlug: service.providerSlug,
            model: service.model
        )
        return data
    }

    /// Checks the HTTP status.
    ///
    /// A failed call is classified before it is reported, so the
    /// message says what the user has to do. The body carries the
    /// provider's own words (= "insufficient balance"), and the
    /// status alone cannot tell an empty account from a rate limit:
    /// both are 429.
    private static func checkStatus(
        _ response: URLResponse,
        body: Data? = nil,
        providerSlug: String,
        model: String
    ) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = body.flatMap { String(data: $0, encoding: .utf8) }
            if let failure = CoverProviderFailure.classify(
                providerSlug: providerSlug,
                httpStatus: http.statusCode,
                body: bodyText,
                model: model
            ) {
                throw CoverVideoError.providerFailure(failure)
            }
            throw CoverVideoError.httpStatus(http.statusCode)
        }
    }
}

// MARK: - Response shapes

/// The task-creation response.
private struct CoverVideoCreateResponse: Decodable {
    struct BaseResp: Decodable {
        let statusCode: Int?
        let statusMessage: String?

        enum CodingKeys: String, CodingKey {
            case statusCode = "status_code"
            case statusMessage = "status_msg"
        }
    }

    let taskId: String?

    /// The provider's own report, which carries a refusal inside a
    /// 200 body (= a spent account, a plan that does not cover the
    /// model, a key the service will not take).
    let baseResp: BaseResp?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case baseResp = "base_resp"
    }
}

/// The task-query response.
private struct CoverVideoQueryResponse: Decodable {
    let status: String?
    let fileId: String?
    let taskStatus: String?

    enum CodingKeys: String, CodingKey {
        case status
        case fileId = "file_id"
        case taskStatus = "task_status"
    }
}

/// The file-retrieval response.
private struct CoverVideoFilesResponse: Decodable {
    struct FilePayload: Decodable {
        let downloadUrl: String?

        enum CodingKeys: String, CodingKey {
            case downloadUrl = "download_url"
        }
    }
    let file: FilePayload?
}

/// The failures the video call can raise.
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
