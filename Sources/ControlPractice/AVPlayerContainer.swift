import AVKit
import SwiftUI

struct AVPlayerContainer: NSViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        // AVPlayerView単体の全画面はSwiftUIのフローティングUIを隠すため使わない。
        view.showsFullScreenToggleButton = false
        view.videoGravity = videoGravity
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
        view.videoGravity = videoGravity
    }
}
