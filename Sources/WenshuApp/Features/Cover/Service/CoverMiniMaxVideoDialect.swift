//
//  Features/Cover/Service/CoverMiniMaxVideoDialect.swift
//
//   : CoverMiniMaxVideoDialect.
//  MiniMax's way of making a clip.
//
//  This is the code that used to live inside the generator, moved
//  out unchanged in behaviour: the same request goes out, the same
//  answer comes back, and the same failure is classified. The
//  generator drives it through the dialect protocol.
//
//  The shape, from MiniMax's own documentation:
//
//    - POST /v1/video_generation with the model, the prompt, the
//      first frame (a base64 data URL) and, for the
//      first-and-last-frame mode, the last frame;
//    - the answer carries a task id, and its own failure inside a
//      200 body (`base_resp.status_code`);
//    - GET /v1/query/video_generation?task_id=... until the status
//      says Success (with a file id) or Failed (with a reason);
//    - GET /v1/files/retrieve?file_id=... for the download address,
//      which expires in about nine hours (= why the bytes are
//      downloaded immediately and the address is never stored).
//

import Foundation

/// MiniMax's way of making a clip.
struct CoverMiniMaxVideoDialect: CoverVideoDialect {

    /// The clip's resolution.
    static let resolution = "768P"

    /// The clip's length in seconds.
    static let duration = 6

    /// The endpoint that starts the job.
    static let createEndpoint = "https://api.minimaxi.com/v1/video_generation"

    /// The endpoint that asks about the job.
    static let queryEndpoint = "https://api.minimaxi.com/v1/query/video_generation"

    /// The endpoint that answers with the download address.
    static let filesEndpoint = "https://api.minimaxi.com/v1/files/retrieve"

    /// The model that serves the first-and-last-frame mode.
    ///
    /// The endpoint's own specification of that mode lists one model
    /// (`MiniMax-Hailuo-02`), and it does not serve the mode at
    /// 512P.
    static let seamlessLoopModel = "MiniMax-Hailuo-02"

    /// The prompt's character limit.
    static let promptCharacterLimit = 2000

    /// The prompt, within the endpoint's limit.
    static func cappedPrompt(_ prompt: String) -> String {
        guard prompt.count > promptCharacterLimit else { return prompt }
        return String(prompt.prefix(promptCharacterLimit))
    }

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
    static func supportsFirstAndLastFrame(model: String) -> Bool {
        model == seamlessLoopModel
    }

    // MARK: - The dialect

    var defaultEndpoint: String { Self.createEndpoint }

    func createRequest(
        prompt: String,
        firstFrameDataURL: String,
        lastFrameDataURL: String?,
        service: ResolvedCoverService
    ) throws -> URLRequest {
        var body = Self.requestBody(
            firstFrameDataURL: firstFrameDataURL,
            prompt: prompt,
            model: service.model
        )
        // A service can serve the mode for a model the caller knows
        // about, so the last frame is taken from the caller when the
        // dialect says the mode is served.
        if let lastFrameDataURL, servesSeamlessLoop(model: service.model) {
            body["last_frame_image"] = lastFrameDataURL
        }

        var request = URLRequest(url: URL(string: service.baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(service.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func parseCreate(_ data: Data, status: Int) throws -> CoverVideoJob {
        // The provider reports its own failure INSIDE a 200 body, so
        // the answer is read before the task id is.
        if let failure = failure(from: data, status: status) {
            throw CoverVideoError.providerFailure(failure)
        }
        let payload = try JSONDecoder().decode(CoverMiniMaxCreateResponse.self, from: data)
        if let code = payload.baseResp?.statusCode, code != 0 {
            let detail = payload.baseResp?.statusMessage
            if let failure = CoverProviderFailure.classify(
                providerSlug: "minimax-cn",
                providerCode: code,
                detail: detail,
                model: nil
            ) {
                throw CoverVideoError.providerFailure(failure)
            }
            throw CoverVideoError.taskFailed(
                detail ?? "the service refused the request (\(code))"
            )
        }
        guard let taskID = payload.taskId, !taskID.isEmpty else {
            throw CoverVideoError.noTask
        }
        return CoverVideoJob(id: taskID, fileHandle: nil)
    }

    func pollRequest(job: CoverVideoJob, service: ResolvedCoverService) throws -> URLRequest {
        var components = URLComponents(string: Self.queryEndpoint)!
        components.queryItems = [URLQueryItem(name: "task_id", value: job.id)]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(service.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        return request
    }

    func parsePoll(_ data: Data) throws -> CoverVideoJobState {
        // The endpoint intermittently answers with an empty or a
        // non-JSON body mid-poll. That is not a failure: it means
        // "not ready yet".
        guard let payload = try? JSONDecoder().decode(CoverMiniMaxQueryResponse.self, from: data) else {
            return .pending
        }
        switch payload.status {
        case "Success":
            return .succeeded(fileHandle: payload.fileId)
        case "Failed":
            return .failed(payload.taskStatus ?? "no reason given")
        default:
            return .pending
        }
    }

    func fileRequest(job: CoverVideoJob, service: ResolvedCoverService) throws -> URLRequest? {
        guard let fileID = job.fileHandle, !fileID.isEmpty else { return nil }
        var components = URLComponents(string: Self.filesEndpoint)!
        components.queryItems = [URLQueryItem(name: "file_id", value: fileID)]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(service.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        return request
    }

    func parseFile(_ data: Data) throws -> URL? {
        let payload = try JSONDecoder().decode(CoverMiniMaxFilesResponse.self, from: data)
        guard let urlString = payload.file?.downloadUrl,
              let url = URL(string: urlString) else {
            throw CoverVideoError.noDownloadURL
        }
        return url
    }

    func videoBytes(from data: Data) throws -> Data? {
        // MiniMax answers with an address, not with the bytes.
        nil
    }

    func failure(from data: Data, status: Int) -> CoverProviderFailure? {
        let bodyText = String(data: data, encoding: .utf8)
        return CoverProviderFailure.classify(
            providerSlug: "minimax-cn",
            httpStatus: status,
            body: bodyText,
            model: nil
        )
    }

    func servesSeamlessLoop(model: String) -> Bool {
        Self.supportsFirstAndLastFrame(model: model)
    }
}

// MARK: - Response shapes

/// The task-creation response.
struct CoverMiniMaxCreateResponse: Decodable {
    struct BaseResp: Decodable {
        let statusCode: Int?
        let statusMessage: String?

        enum CodingKeys: String, CodingKey {
            case statusCode = "status_code"
            case statusMessage = "status_msg"
        }
    }

    let taskId: String?
    let baseResp: BaseResp?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case baseResp = "base_resp"
    }
}

/// The query response.
struct CoverMiniMaxQueryResponse: Decodable {
    let status: String?
    let fileId: String?
    let taskStatus: String?

    enum CodingKeys: String, CodingKey {
        case status
        case fileId = "file_id"
        case taskStatus = "task_status"
    }
}

/// The files response.
struct CoverMiniMaxFilesResponse: Decodable {
    struct FilePayload: Decodable {
        let downloadUrl: String?

        enum CodingKeys: String, CodingKey {
            case downloadUrl = "download_url"
        }
    }

    let file: FilePayload?
}
