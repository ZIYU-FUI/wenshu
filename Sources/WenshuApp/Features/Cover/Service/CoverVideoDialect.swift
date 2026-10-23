//
//  Features/Cover/Service/CoverVideoDialect.swift
//
//   : CoverVideoDialect.
//  One service's way of making a clip.
//
//  The app used to speak ONE cover protocol: MiniMax's. That was
//  fine while MiniMax was the only service with a key, and it is not
//  fine for the feature as a whole (= the feature is aimed at the
//  users who will use Wenshu, and they will bring their own API).
//
//  So the protocol became a thing the app LOOKS UP instead of a
//  thing it hard-codes. A dialect knows one service's way of doing
//  the six things a clip takes:
//
//    - how to ask for the clip (= the endpoint, the headers, the
//      body, and where the first and the last frame go);
//    - how to read the answer (= the job's own id, and the failure
//      the service reports INSIDE a 200 body);
//    - how to ask about the job;
//    - how to read the job's state;
//    - how to get at the finished clip (= some services answer with
//      the bytes, some with an address, some with a handle that
//      answers with an address);
//    - whether THAT service, with THAT model, serves the
//      first-and-last-frame mode.
//
//  The last one is the one that is a fact about a (service, model)
//  PAIR and not about a service: MiniMax serves the mode for one
//  model, OpenRouter publishes the fact per model in its model list,
//  and Veo publishes it as a first-class capability. A hard-coded
//  model string cannot carry that.
//
//  The generators speak no service's protocol themselves: they ask
//  the registry for the dialect of the route and drive it.
//

import Foundation

/// A job that is being made.
struct CoverVideoJob: Equatable, Sendable {

    /// The service's own id for the job (= the task id, the operation
    /// name, the job id).
    var id: String

    /// The service's own handle for the finished clip, when it gives
    /// one (= MiniMax answers with a file id and then with a
    /// download address; a service that answers with bytes gives
    /// none).
    var fileHandle: String?
}

/// What a service says about a job.
enum CoverVideoJobState: Equatable, Sendable {

    /// Not finished yet.
    case pending

    /// Finished, and the clip is at the job's handle (= the service's
    /// own handle for it, when it gives one).
    case succeeded(fileHandle: String?)

    /// Finished, and it failed. The message is the service's own.
    case failed(String)
}

/// One service's way of making a clip.
protocol CoverVideoDialect: Sendable {

    /// The endpoint this service is reached at, when the route names
    /// none.
    ///
    /// It belongs to the dialect (= to the service), not to the
    /// kind: the video endpoints of two services are two different
    /// URLs, and a route that names a provider must reach that
    /// provider's own endpoint.
    var defaultEndpoint: String { get }

    /// The request that starts the job.
    ///
    /// - Parameters:
    ///   - prompt: what the clip should show.
    ///   - firstFrameDataURL: the still cover, as the service wants
    ///     it (= a base64 data URL for the services that take one).
    ///   - lastFrameDataURL: the same picture again, when the service
    ///     serves the first-and-last-frame mode.
    ///   - service: where the clip is made (= the endpoint, the
    ///     model and the key all come from the route).
    func createRequest(
        prompt: String,
        firstFrameDataURL: String,
        lastFrameDataURL: String?,
        service: ResolvedCoverService
    ) throws -> URLRequest

    /// The answer to the create call.
    ///
    /// A service can report its own failure INSIDE a 200 body, so
    /// the answer is read before the job's id is: without that, a
    /// spent account reads as "the service did not return a task",
    /// which tells the user nothing.
    func parseCreate(_ data: Data, status: Int) throws -> CoverVideoJob

    /// The request that asks about the job.
    func pollRequest(job: CoverVideoJob, service: ResolvedCoverService) throws -> URLRequest

    /// The answer to the poll.
    func parsePoll(_ data: Data) throws -> CoverVideoJobState

    /// The request that gets at the finished clip's address, when the
    /// service answers with a handle rather than with the bytes.
    ///
    /// It is nil for a service that answers with the bytes.
    func fileRequest(job: CoverVideoJob, service: ResolvedCoverService) throws -> URLRequest?

    /// The address of the finished clip, when the service answers
    /// with one.
    func parseFile(_ data: Data) throws -> URL?

    /// The clip's bytes, when the service answers with them.
    func videoBytes(from data: Data) throws -> Data?

    /// The failure, in that service's own words.
    ///
    /// It reads the HTTP status AND the body, because the status
    /// alone cannot tell an empty account from a rate limit (= both
    /// are 429).
    func failure(from data: Data, status: Int) -> CoverProviderFailure?

    /// Whether this service, with this model, serves the
    /// first-and-last-frame mode.
    ///
    /// The mode is what makes the clip's loop seamless: the clip ends
    /// on the picture it started from. A service that does not serve
    /// it loses it silently (= the request simply drops the last
    /// frame), so the settings ask this question.
    func servesSeamlessLoop(model: String) -> Bool
}

/// Which dialect a route speaks to.
enum CoverVideoDialectRegistry {

    /// The dialect for a resolved service.
    ///
    /// The provider decides when the app knows that provider. A route
    /// that names an endpoint of its own is decided by that endpoint's
    /// host, because a proxy of the user's own can sit on any host.
    /// An endpoint the app has never seen falls back to the app's
    /// own dialect (= the shape the app speaks), and the settings say
    /// so when the endpoint does not look like a cover endpoint.
    static func dialect(for route: CoverServiceRoute) -> any CoverVideoDialect {
        // The route decides by its provider slug, and by the host of
        // an endpoint of its own (= a proxy of the user's own can sit
        // on any host). The endpoint itself is not read here: the
        // dialect decides where it lives.
        let slug = (route.providerSlug ?? "").lowercased()
        if CoverProviderCapability.coverProtocolProviders.contains(slug) {
            return CoverMiniMaxVideoDialect()
        }
        if let baseURL = route.baseURL,
           let host = URL(string: baseURL)?.host?.lowercased(),
           CoverProviderCapability.coverProtocolHosts.contains(host) {
            return CoverMiniMaxVideoDialect()
        }
        return CoverMiniMaxVideoDialect()
    }

    static func dialect(for service: ResolvedCoverService) -> any CoverVideoDialect {
        switch service.providerSlug.lowercased() {
        case "minimax", "minimax-cn":
            return CoverMiniMaxVideoDialect()
        default:
            break
        }
        if let host = URL(string: service.baseURL)?.host?.lowercased(),
           CoverProviderCapability.coverProtocolHosts.contains(host) {
            return CoverMiniMaxVideoDialect()
        }
        return CoverMiniMaxVideoDialect()
    }
}
