//
//  Features/Cover/View/LoopingCoverView.swift
//
//   : LoopingCoverView.
//  Plays a card's cover clip on hover.
//
//  The clip is STILL by default. A grid of moving clips is noise, and
//  it costs CPU, so the clip starts when the pointer arrives and
//  stops when it leaves.
//
//  THE LOOP IS FORWARD-THEN-BACKWARD, and that is a measured
//  decision, not a style choice. Sampling frames across a real
//  generated clip on 2026-10-22 showed that consecutive frames differ
//  by about 4/255 (= there IS real motion) but the first frame and
//  the last frame differ by about 14/255, which reads as a visible
//  jump when the clip loops directly. The provider was asked for a
//  seamless loop and did not deliver one.
//
//  So the clip plays forward and then backward. That is guaranteed
//  seamless, and it doubles the apparent length, which suits a
//  six-second clip playing under a pointer.
//
//  The playback rule is a small PURE type, so it can be tested
//  without a player and without a video file.
//

import AVFoundation
import AppKit
import SwiftUI

/// Where the playback goes next.
enum CoverPlaybackState: Equatable {
    /// Playing forward.
    case playingForward
    /// Playing backward (= the clip is running in reverse).
    case playingBackward
    /// Not playing.
    case stopped
}

/// The forward-then-backward rule, as a pure function.
enum CoverPlaybackRule {

    /// The state after the clip reaches its end while playing
    /// forward.
    static func next(afterForwardEnd: Bool) -> CoverPlaybackState {
        afterForwardEnd ? .playingBackward : .playingForward
    }

    /// The state after the clip reaches its start while playing
    /// backward.
    static func next(afterBackwardEnd: Bool) -> CoverPlaybackState {
        afterBackwardEnd ? .playingForward : .playingBackward
    }
}

/// A card's cover clip, playing on hover.
struct LoopingCoverView: View {

    /// The clip's URL, or nil when the card has no clip.
    let videoURL: URL?

    /// Whether the pointer is over the view.
    let isHovered: Bool

    /// The still picture, shown when the clip is not playing.
    let stillImageURL: URL?

    /// The still picture itself, when the caller already holds it.
    ///
    /// The URL is the normal way in. This is the seam that lets the
    /// slot be measured with a real picture and no asynchronous load,
    /// which is the only way to prove that a card with a clip still
    /// still shows its picture.
    let stillImage: NSImage?

    /// The view's values, with the picture as an optional extra.
    init(
        videoURL: URL?,
        isHovered: Bool,
        stillImageURL: URL?,
        stillImage: NSImage? = nil,
        preparedPlayer: AVPlayer? = nil
    ) {
        self.videoURL = videoURL
        self.isHovered = isHovered
        self.stillImageURL = stillImageURL
        self.stillImage = stillImage
        self.preparedPlayer = preparedPlayer
    }

    /// The player, created when the clip is.
    @State private var player: AVPlayer?

    /// A player the caller already made.
    ///
    /// The view makes its own player when it appears, and a view can
    /// only appear in a window. A test cannot put a window on screen,
    /// so this is the way to hand the view a player and see what it
    /// does with one.
    let preparedPlayer: AVPlayer?

    /// The observer that watches the clip's position.
    @State private var timeObserver: Any?

    /// Whether the clip is currently running backward.
    @State private var isBackward = false

    var body: some View {
        ZStack {
            // The picture is ALWAYS mounted.
            //
            // It used to be swapped for the clip: one branch or the
            // other. That tears the picture down and builds it again
            // on every move of the pointer, and the picture is loaded
            // off the main actor, so in the window between the two the
            // card shows what is underneath (= the gradient and the
            // symbol). The user saw a card whose cover came and went
            // with the pointer, and a card that looked like it had no
            // cover at all.
            //
            // So the picture stays where it is, and the clip plays ON
            // TOP of it. The card's cover is then always the picture,
            // and the clip is what moves.
            CardCoverView(imageURL: stillImageURL, image: stillImage)

            if isHovered, let player = player ?? preparedPlayer {
                PlayerLayerView(player: player)
            }
        }
        .onAppear(perform: prepare)
        .onDisappear(perform: tearDown)
        .onChange(of: isHovered) { _, hovering in
            if hovering {
                play()
            } else {
                stop()
            }
        }
    }

    // MARK: - Player

    /// Creates the player and starts watching the position.
    private func prepare() {
        guard let videoURL else { return }
        let item = AVPlayerItem(url: videoURL)
        let created = AVPlayer(playerItem: item)
        // The clip is muted: a cover must never make a sound.
        created.isMuted = true
        created.actionAtItemEnd = .pause
        player = created

        // Watch the position so the clip can be flipped at its ends.
        let observer = created.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak created] time in
            guard let created else { return }
            let duration = created.currentItem?.duration.seconds ?? 0
            guard duration > 0 else { return }
            let position = time.seconds
            // A small epsilon, so the ends are detected without
            // flickering between the two states.
            let epsilon = 0.08
            if position >= duration - epsilon {
                // The forward run finished: play it backward.
                created.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                created.rate = -1
            } else if position <= epsilon {
                // The backward run finished: play it forward.
                created.seek(to: CMTime(seconds: duration, preferredTimescale: 600),
                             toleranceBefore: .zero, toleranceAfter: .zero)
                created.rate = 1
            }
        }
        timeObserver = observer
    }

    /// Starts the clip.
    private func play() {
        guard let player else { return }
        player.rate = isBackward ? -1 : 1
    }

    /// Stops the clip and rewinds it.
    ///
    /// The card goes back to exactly the state it was in before the
    /// pointer arrived, so the still picture and the clip never show
    /// different moments.
    private func stop() {
        guard let player else { return }
        player.pause()
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        isBackward = false
    }

    /// Releases the player.
    private func tearDown() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
    }
}


/// A view that shows an `AVPlayer`'s video.
///
/// `VideoPlayer` is an AVKit view and brings its own controls, which
/// a cover must not have: the clip plays on hover and is driven by
/// the app, not by the user. An `AVPlayerLayer` in a `NSViewRepresentable`
/// shows the video with no chrome at all.
struct PlayerLayerView: NSViewRepresentable {
    /// The player to show.
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerHost {
        let view = PlayerLayerHost()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerLayerHost, context: Context) {
        if nsView.playerLayer.player !== player {
            nsView.playerLayer.player = player
        }
    }
}

/// The host view for the player layer.
final class PlayerLayerHost: NSView {
    /// The layer that shows the video.
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = playerLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layout() {
        super.layout()
        // The layer fills the view, and the video fills the layer
        // without letterboxing: the clip's aspect matches the banner
        // slot, and a letterbox would show the background around it.
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resizeAspectFill
    }
}
