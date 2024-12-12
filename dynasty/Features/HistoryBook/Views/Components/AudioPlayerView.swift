import SwiftUI
import AVKit
import OSLog

struct AudioPlayerView: View {
    let audioURL: URL
    @State private var player: AVPlayer
    @State private var isPlaying = false
    private let logger = Logger(subsystem: "com.mydynasty.AudioPlayerView", category: "AudioPlayerView")
    private let playerObserver = PlayerObserver()

    init(audioURL: URL) {
        self.audioURL = audioURL
        self._player = State(initialValue: AVPlayer(url: audioURL))
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    if isPlaying {
                        player.pause()
                        logger.info("Audio playback paused")
                    } else {
                        player.play()
                        logger.info("Audio playback started")
                    }
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
            }
        }
        .onAppear {
            playerObserver.setPlayer(player)
            playerObserver.observePlayerStatus { status in
                handlePlayerStatusChange(status: status)
            }
            playerObserver.observeItemStatus { status in
                handleItemStatusChange(status: status)
            }
            playerObserver.observeItemDidPlayToEnd {
                playerItemDidReachEnd()
            }
        }
        .onDisappear {
            player.pause()
            playerObserver.removeObservers()
            logger.info("Audio playback stopped and observers removed")
        }
    }

    private func handlePlayerStatusChange(status: AVPlayer.TimeControlStatus) {
        DispatchQueue.main.async {
            switch status {
            case .paused:
                isPlaying = false
                logger.info("AVPlayer status changed to paused")
            case .waitingToPlayAtSpecifiedRate:
                logger.info("AVPlayer status changed to waitingToPlayAtSpecifiedRate")
            case .playing:
                isPlaying = true
                logger.info("AVPlayer status changed to playing")
            @unknown default:
                logger.warning("AVPlayer status changed to an unknown state")
            }
        }
    }

    private func handleItemStatusChange(status: AVPlayerItem.Status) {
        DispatchQueue.main.async {
            switch status {
            case .readyToPlay:
                logger.info("AVPlayerItem status changed to readyToPlay")
            case .failed:
                logger.error("AVPlayerItem status changed to failed: \(String(describing: player.currentItem?.error))")
            case .unknown:
                logger.info("AVPlayerItem status changed to unknown")
            @unknown default:
                logger.warning("AVPlayerItem status changed to unknown state")
            }
        }
    }

    private func playerItemDidReachEnd() {
        player.seek(to: .zero)
        isPlaying = false
        logger.info("Audio playback reached end, resetting to start")
    }
}

class PlayerObserver: NSObject {
    private var player: AVPlayer?
    private var playerStatusObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var endTimeObserver: NSObjectProtocol?
    private var timeControlStatusHandler: ((AVPlayer.TimeControlStatus) -> Void)?
    private var itemStatusHandler: ((AVPlayerItem.Status) -> Void)?
    private var endTimeHandler: (() -> Void)?

    func setPlayer(_ player: AVPlayer) {
        self.player = player
    }

    func observePlayerStatus(statusHandler: @escaping (AVPlayer.TimeControlStatus) -> Void) {
        self.timeControlStatusHandler = statusHandler
        playerStatusObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, change in
            if let newStatus = change.newValue {
                self?.timeControlStatusHandler?(newStatus)
            }
        }
    }

    func observeItemStatus(statusHandler: @escaping (AVPlayerItem.Status) -> Void) {
        self.itemStatusHandler = statusHandler
        itemStatusObserver = player?.currentItem?.observe(\.status, options: [.new]) { [weak self] item, change in
            if let newStatus = change.newValue {
                self?.itemStatusHandler?(newStatus)
            }
        }
    }

    func observeItemDidPlayToEnd(handler: @escaping () -> Void) {
        self.endTimeHandler = handler
        endTimeObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.endTimeHandler?()
        }
    }

    func removeObservers() {
        playerStatusObserver?.invalidate()
        itemStatusObserver?.invalidate()
        if let endTimeObserver = endTimeObserver {
            NotificationCenter.default.removeObserver(endTimeObserver)
        }
        self.playerStatusObserver = nil
        self.itemStatusObserver = nil
        self.endTimeObserver = nil
        self.timeControlStatusHandler = nil
        self.itemStatusHandler = nil
        self.endTimeHandler = nil
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        endTimeHandler?()
    }
}
