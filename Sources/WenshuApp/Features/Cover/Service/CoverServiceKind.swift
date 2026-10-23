//
//  Features/Cover/Service/CoverServiceKind.swift
//
//   : CoverServiceKind.
//  The two services the cover feature talks to.
//
//  The IMAGE service draws the static banner. The VIDEO service turns
//  that banner into a moving clip. They are separate services with
//  separate quotas, separate base URLs and separate auth headers, so
//  they are separate settings.
//
//  The video kind has NO default model, and that asymmetry is
//  deliberate: the video allowance on a token plan runs to a handful
//  of clips a day, so a silent default would spend a scarce quota
//  without the user asking. The image kind DOES have a default,
//  because the image allowance is large and a cover with no service
//  would just mean the feature does nothing.
//
//  A cover service uses its OWN model namespace, and that is the
//  reason the two kinds carry their own default model and their own
//  default endpoint. The provider profiles in the app describe CHAT
//  models ("MiniMax-M3" and friends); those are not image models, and
//  a cover must never be drawn with one. So a cover route inherits
//  the PROVIDER (= the key, the host, the quota) and takes the MODEL
//  from its kind.
//

import Foundation

/// Which service a cover route points at.
enum CoverServiceKind: String, Codable, CaseIterable, Sendable, Identifiable {
    /// The service that draws the static banner.
    case image
    /// The service that animates the static banner.
    case video

    var id: String { rawValue }

    /// The title for the settings row.
    ///
    /// A plain English constant: the settings pane replaces it with a
    /// localized key, because a title the user reads is a string the
    /// app ships in two languages.
    var displayTitle: String {
        switch self {
        case .image: return "Image service"
        case .video: return "Video service"
        }
    }

    /// The default model for this kind, when there is one.
    ///
    /// The image kind defaults to the model that was verified against
    /// the live endpoint. The video kind has NO default: a missing
    /// video route must fail loudly rather than quietly spend the
    /// scarce video quota.
    var defaultModel: String? {
        switch self {
        case .image: return "image-01"
        case .video: return nil
        }
    }

    /// The endpoint for this kind, when the provider's own endpoint
    /// applies.
    ///
    /// These are NOT the provider profile's base URLs: those point at
    /// the Anthropic-compatible CHAT host, and the cover services are
    /// different services on the same domain.
    var defaultEndpoint: String {
        switch self {
        case .image: return "https://api.minimaxi.com/v1/image_generation"
        case .video: return "https://api.minimaxi.com/v1/video_generation"
        }
    }

    /// The provider whose service answers for this kind by default.
    ///
    /// It is the provider that publishes the cover protocol (= the
    /// MiniMax image and video endpoints), and NOT the app's chat
    /// provider: a chat key cannot pay for a picture, and a chat
    /// provider publishes no picture endpoint for the cover protocol
    /// to call.
    var defaultProviderSlug: String {
        "minimax-cn"
    }
}
