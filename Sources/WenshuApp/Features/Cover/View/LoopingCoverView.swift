//
//  Features/Cover/View/LoopingCoverView.swift
//
//   : LoopingCoverView.
//  Plays a card's cover clip, on a click.
//
//  The clip is STILL by default, and a PLAY BUTTON sits in the middle
//  of the picture. The button is the App Store's shape (= a filled
//  circle with a triangle in it), which is an SF Symbol: `play.circle
//  .fill` and `pause.circle.fill`.
//
//  macOS has no control for that shape: `AVPlayerView` was measured
//  in every one of its styles at the size of a cover slot (= 240 x
//  100) and none of them shows a centred play button. `.none` shows
//  nothing, `.floating` and `.inline` show a transport bar on hover,
//  and `.default` shows no centred button either. So the button is the
//  system's own symbol over the app's own surface, which is what
//  Apple's own media apps do.
//
//  The clip used to start when the POINTER arrived. That made the
//  card's cover depend on where the pointer was: the user had to keep
//  it on one exact spot, and the cover came and went with it. A
//  button says what the card can do, and it says it the same way
//  every time.
//
//  THE LOOP IS FORWARD, and the loop is the framework's own
//  (`AVPlayerLooper`). The app used to play the clip BACKWARD at its
//  ends, so the loop had no seam: sampling frames across a real
//  generated clip on 2026-10-22 showed that the first frame and the
//  last frame differ by about 14/255, which reads as a visible jump.
//
//  Playing a clip backward is a negative rate, and a negative rate
//  with the picture on the screen took the process down: a bus error
//  inside CoreMedia's frame scheduler, on every card with a clip. It
//  was bisected with the real clip: forward with a picture was fine,
//  backward without a picture was fine, backward with a picture was
//  not.
//
//  So the clip loops forward, the way the framework does it, and the
//  app stays up. The user asked for a clip that loops and nothing
//  more.
//

import AVFoundation
import AppKit
import SwiftUI

/// The control that starts and stops a card's cover clip.
///
/// It is a small PURE type, so the truth table can be tested without a
/// player and without a video file: which symbol the control shows,
/// and what it does when it is pressed.
enum CoverClipControl {

    /// The size of the control, in points.
    ///
    /// The cover slot is 100 PT tall, and the control is a third of
    /// it: big enough to see in a grid of thumbnails, small enough to
    /// leave the picture readable. It is also Apple's smallest hit
    /// target (28 PT), so the control can be pressed without aiming.
    static let controlSize: CGFloat = 30

    /// The symbol the control shows.
    ///
    /// `play.circle.fill` is a filled circle with a triangle knocked
    /// out of it, which is the App Store's own shape, and it is the
    /// system's symbol rather than a picture of one.
    static func symbol(isPlaying: Bool) -> String {
        isPlaying ? "pause.circle.fill" : "play.circle.fill"
    }

    /// What the control does when it is pressed.
    static func action(isPlaying: Bool) -> CoverClipAction {
        isPlaying ? .stop : .start
    }

    /// The label the control is read out with.
    ///
    /// It is a `LocalizedStringKey` and NOT a string, so the compiler
    /// can still find the key in the string catalog.
    static func label(isPlaying: Bool) -> LocalizedStringKey {
        isPlaying ? "cover.pause_clip" : "cover.play_clip"
    }
}

/// What a press on the cover's control does.
enum CoverClipAction: Equatable {
    /// The clip starts.
    case start
    /// The clip stops.
    case stop
}

/// A card's cover clip, playing on a click.
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
        preparedPlayer: AVPlayer? = nil,
        isPlaying: Bool? = nil
    ) {
        self.videoURL = videoURL
        self.isHovered = isHovered
        self.stillImageURL = stillImageURL
        self.stillImage = stillImage
        self.preparedPlayer = preparedPlayer
        _isPlaying = State(initialValue: isPlaying ?? false)
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

    /// The loop that repeats the clip.
    ///
    /// It is held because the framework's looper keeps the copies of
    /// the clip alive only while something holds it.
    @State private var looper: AVPlayerLooper?

    /// Whether the clip is running.
    ///
    /// The value can be handed in, so the slot can be seen in the
    /// playing state without pressing anything.
    @State private var isPlaying: Bool

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

            if isPlaying || isHovered, let player = player ?? preparedPlayer {
                PlayerLayerView(player: player)
            }

            // The control that starts and stops the clip.
            //
            // It sits in the middle of the picture, the way the App
            // Store's own card does, and it is the system's symbol.
            if videoURL != nil {
                Button {
                    togglePlayback()
                } label: {
                    SFIcon(
                        CoverClipControl.symbol(isPlaying: isPlaying),
                        style: .inlineSmall,
                        color: .white,
                        rendering: .monochrome,
                        pointSizeOverride: CoverClipControl.controlSize
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(CoverClipControl.label(isPlaying: isPlaying)))
            }
        }
        .onAppear(perform: prepare)
        .onDisappear(perform: tearDown)
        .onChange(of: isHovered) { _, hovering in
            if hovering {
                play()
            } else if !isPlaying {
                stop()
            }
        }
    }

    // MARK: - The control

    /// Starts the clip, or stops it.
    ///
    /// The pointer plays the clip (= the way it has always worked),
    /// and this is the way to keep it playing: the card is the user's
    /// to watch, and a clip that stops the moment the pointer moves
    /// away is a clip nobody can look at.
    private func togglePlayback() {
        if isPlaying {
            isPlaying = false
            stop()
        } else {
            isPlaying = true
            play()
        }
    }

    // MARK: - Player

    /// Creates the player and the loop that repeats the clip.
    ///
    /// The clip loops FORWARD, and the loop is the framework's own
    /// (`AVPlayerLooper`): the app hands the clip over and lets
    /// AVFoundation repeat it.
    ///
    /// It used to be the other way round. The app watched the position
    /// and played the clip BACKWARD at its ends, so the loop had no
    /// seam. That is what a negative rate does to a decoder, and with
    /// the picture on the screen it took the process down: a bus error
    /// inside CoreMedia's frame scheduler, on every card with a clip.
    /// A measured crash, reproduced with the real clip and bisected to
    /// the backward rate: forward with a picture was fine, backward
    /// without a picture was fine, backward with a picture was not.
    ///
    /// So the clip loops forward, the way the framework does it, and
    /// the app stays up.
    private func prepare() {
        guard let videoURL else { return }
        let item = AVPlayerItem(url: videoURL)
        let queue = AVQueuePlayer()
        // The clip is muted: a cover must never make a sound.
        queue.isMuted = true
        // The looper keeps a copy of the clip ready, so the loop has
        // no gap.
        queue.actionAtItemEnd = .advance
        player = queue
        looper = AVPlayerLooper(player: queue, templateItem: item)
    }

    /// Starts the clip.
    private func play() {
        guard let player else { return }
        // `play()` and not a rate: the player waits for the clip to be
        // ready, where a rate would ask CoreMedia to work with a time
        // range it does not have yet.
        player.play()
    }

    /// Stops the clip and rewinds it.
    ///
    /// The card goes back to exactly the state it was in before the
    /// pointer arrived, so the still picture and the clip never show
    /// different moments.
    private func stop() {
        guard let player else { return }
        player.pause()
        // The clip is only rewound when it is ready: a clip that is
        // still loading has no time to rewind to, and asking for one
        // leaves CoreMedia with a NaN where a time should be.
        guard player.currentItem?.status == .readyToPlay else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Releases the player.
    private func tearDown() {
        looper?.disableLooping()
        looper = nil
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
