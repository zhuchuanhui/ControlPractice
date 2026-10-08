import AVKit
import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: TrainingModel
    @EnvironmentObject private var motionReceiver: MacMotionReceiver
    @State private var player = AVPlayer()
    @StateObject private var videoAnalyzer = VideoMotionAnalyzer()
    @State private var showingImporter = false
    @State private var videoStatus = ""
    @State private var videoReady = false
    @State private var videoHeight: CGFloat = 420
    @State private var manualSceneLabel: SceneLabel?
    @State private var focusMode = false
    @State private var appFullScreen = false
    @State private var videoGravity: AVLayerVideoGravity = .resizeAspect
    @State private var showTrainingGuide = false
    @State private var trainingNotice: String?
    @State private var watchAlertActive = false
    @State private var videoAlertActive = false
    @State private var showWatchPrompt = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var mouseActivity = MouseActivityObserver()

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            List {
                Section("トレーニング".localized) { Label("セッション".localized, systemImage: "timer") }
                Section("記録".localized) { Label("履歴".localized, systemImage: "clock.arrow.circlepath") }
            }
            .navigationTitle("Control Practice")
        } detail: {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Group {
                        if model.videoURL != nil && videoReady { AVPlayerContainer(player: player, videoGravity: videoGravity) }
                        else {
                            VStack(spacing: 10) {
                                Image(systemName: "film").font(.largeTitle)
                                Text(videoStatus.isEmpty ? "動画を選択してください".localized : videoStatus).font(.headline)
                                Text("動画の準備が完了してから再生画面を開きます".localized).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .background(.black)
                    FloatingControls(
                        model: model,
                        player: player,
                        showingImporter: $showingImporter,
                        videoGravity: $videoGravity,
                        videoHeight: $videoHeight,
                        focusMode: $focusMode,
                        appFullScreen: $appFullScreen,
                        onPrevious: {
                            if let url = model.restoreLastVideo() { prepareVideo(url) }
                        },
                        onChromeChange: { hidden in
                            if hidden {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    setWindowChrome(hidden: true)
                                }
                            } else {
                                setWindowChrome(hidden: false)
                            }
                        },
                        onTrainingStart: {
                            if motionReceiver.latestSample == nil {
                                showWatchPrompt = true
                            } else {
                                model.startOrResume()
                            }
                        },
                        onFinish: {
                            player.pause()
                            model.reset()
                        }
                    )
                        .padding(12)
                        // 再生中だけ自動非表示。一時停止中・準備中は操作ボタンを常に表示する。
                        .opacity(focusMode && mouseActivity.isIdle ? 0 : 1)
                    VStack {
                        HStack {
                            Spacer()
                            Button(appFullScreen ? "全画面解除".localized : "全画面".localized, systemImage: appFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                                if appFullScreen {
                                    toggleNativeFullScreen()
                                    setWindowChrome(hidden: false)
                                    appFullScreen = false
                                    focusMode = false
                                    videoHeight = 720
                                    return
                                }
                                appFullScreen = true
                                focusMode = true
                                sidebarVisibility = .detailOnly
                                videoHeight = max(900, NSScreen.main?.visibleFrame.height ?? 900)
                                toggleNativeFullScreen()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    if appFullScreen { setWindowChrome(hidden: true) }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        if focusMode {
                            FocusStatusOverlay(model: model, motionReceiver: motionReceiver, videoAnalyzer: videoAnalyzer, manualSceneLabel: manualSceneLabel)
                                .opacity(1)
                                .frame(maxWidth: .infinity, alignment: .topTrailing)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(10)
                    if showTrainingGuide {
                        Text("トレーニング開始\nゆっくり刺激し、強くなったら一時停止または休憩".localized)
                            .font(.system(size: 30, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32).padding(.vertical, 24)
                            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .allowsHitTesting(false)
                    }
                    if let trainingNotice {
                        Text(trainingNotice)
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 36).padding(.vertical, 28)
                            .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: focusMode ? 0 : videoHeight, maxHeight: focusMode ? .infinity : videoHeight)
                .layoutPriority(focusMode ? 1 : 0)

                // 動画を表示している間は、動画以外の通常UIを隠す。
                // 必要な操作は動画上の FloatingControls / オーバーレイから行う。
                if !videoReady {
                HStack {
                    Button("この位置を開始位置に保存".localized, systemImage: "bookmark") {
                        model.savePreferredStartTime(player.currentTime().seconds)
                    }
                    .disabled(!videoReady)
                    if let start = model.preferredStartTime {
                        Button("開始位置へ".localized, systemImage: "arrow.uturn.right") {
                            player.seek(to: CMTime(seconds: start, preferredTimescale: 600))
                        }
                        .disabled(!videoReady)
                    }
                    Spacer()
                    Text("セット (model.currentSet) / (model.totalSets)").monospacedDigit()
                    Text(model.phaseTitle).font(.headline).foregroundStyle(model.phase == .rest ? .blue : .orange)
                    Text(time(model.remaining)).font(.system(.title2, design: .monospaced)).frame(width: 90)
                }.padding()

                ProgressView(value: model.phaseLimit == 0 ? 0 : model.elapsed, total: model.phaseLimit).padding(.horizontal)
                MotionMonitorView(receiver: motionReceiver)
                    .padding(.horizontal)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("動画の動き".localized, systemImage: "waveform.path.ecg")
                        Spacer()
                        Text("\(Int(videoAnalyzer.motionScore * 100))%")
                            .monospacedDigit()
                    }
                    ProgressView(value: videoAnalyzer.motionScore)
                    HStack {
                        Text("区間推定".localized)
                        Text(AppText.value((manualSceneLabel ?? videoAnalyzer.sceneLabel).rawValue)).font(.headline)
                        Spacer()
                        Text("映像の動き量による参考表示".localized).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("フレーム差分による動きの強さ。映像は保存しません".localized)
                        .font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text("現在の区間:".localized).font(.caption)
                        ForEach([SceneLabel.story, .buildup, .intimate, .pause], id: \.self) { label in
                            Button(AppText.value(label.rawValue)) { manualSceneLabel = label }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        if manualSceneLabel != nil {
                            Button("自動に戻す".localized) { manualSceneLabel = nil }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                        }
                    }
                    if !videoStatus.isEmpty { Text(videoStatus).font(.caption2).foregroundStyle(.secondary) }
                }
                .padding(.horizontal)
                HStack {
                    Label("動画サイズ".localized, systemImage: "rectangle.resize.vertical")
                    Slider(value: $videoHeight, in: 240...1600)
                    Text("\(Int(videoHeight))px").monospacedDigit().frame(width: 60)
                }.padding(.horizontal)
                HStack(spacing: 12) {
                    Button(model.isRunning ? "一時停止".localized : "開始".localized, systemImage: model.isRunning ? "pause.fill" : "play.fill") { model.isRunning ? model.pause() : model.startOrResume() }.keyboardShortcut(.space)
                    Button("フェーズを切替".localized, systemImage: "forward.fill") { model.skipPhase() }.disabled(!model.isRunning)
                    Button("リセット".localized, systemImage: "arrow.counterclockwise") { model.reset() }
                }.padding()
                Divider()
                HistoryView().environmentObject(model)
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.movie, .video, .mpeg4Movie]) { result in
            if case .success(let url) = result { model.loadVideo(url); prepareVideo(url) }
        }
        .onChange(of: model.phase) { phase in updateIcon(for: phase) }
        .onChange(of: model.isRunning) { running in if !running { DynamicAppIcon.shared.update(for: .paused) } }
        .onChange(of: model.isRunning) { running in
            guard running else { return }
            showTrainingGuide = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showTrainingGuide = false }
        }
        .onChange(of: motionReceiver.intensity) { intensity in
            let crossed = intensity >= model.automaticThreshold && !watchAlertActive
            watchAlertActive = intensity >= model.automaticThreshold
            if crossed {
                showTrainingNotice("動きを止めてください\n落ち着いたら再開してください".localized)
                model.automaticRest()
            }
        }
        .onChange(of: videoAnalyzer.motionScore) { score in
            let crossed = score >= model.automaticThreshold && !videoAlertActive
            videoAlertActive = score >= model.automaticThreshold
            if crossed {
                showTrainingNotice("刺激が強くなっています\n一時停止または休憩してください".localized)
            }
        }
        .onAppear { mouseActivity.start() }
        .onDisappear { mouseActivity.stop() }
        .alert("Apple Watchが未接続です".localized, isPresented: $showWatchPrompt) {
            Button("Watchを接続する".localized) {
                motionReceiver.requestConnection()
            }
            Button("Watchなしで開始".localized) { model.startOrResume() }
            Button("キャンセル".localized, role: .cancel) {}
        } message: {
            Text("Watchを接続すると手の動きを検知できます。接続せずにトレーニングを開始しますか？".localized)
        }
        .onChange(of: focusMode) { focused in
            sidebarVisibility = focused ? .detailOnly : .all
        }
    }

    private func toggleNativeFullScreen() {
        let window = NSApp.keyWindow ?? NSApp.mainWindow
        guard let window else { return }
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.toggleFullScreen(nil)
    }

    private func setWindowChrome(hidden: Bool) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = hidden
        }
        window.toolbar?.isVisible = !hidden
    }

    private func replacePlayer() {
        if let url = model.videoURL {
            guard url.isFileURL == false || FileManager.default.fileExists(atPath: url.path) else { return }
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            videoAnalyzer.attach(to: item)
            videoAnalyzer.start()
        }
    }

    private func prepareVideo(_ url: URL) {
        videoReady = false
        videoStatus = "動画を確認中…".localized
        let asset = AVURLAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["playable", "tracks"]) {
            var error: NSError?
            let playable = asset.statusOfValue(forKey: "playable", error: &error) == .loaded && asset.isPlayable
            DispatchQueue.main.async {
                guard playable else {
                    videoStatus = "この動画は再生できません。ネットワーク接続と形式を確認してください。".localized
                    return
                }
                let item = AVPlayerItem(asset: asset)
                player.replaceCurrentItem(with: item)
                videoAnalyzer.attach(to: item)
                videoReady = true
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 }
                if let size, size >= 4_000_000_000 {
                    videoAnalyzer.stop()
                    videoStatus = "大容量動画のため、動画解析を停止して再生します。".localized
                } else {
                    videoAnalyzer.start()
                    videoStatus = "再生準備完了".localized
                }
            }
        }
    }
    private func time(_ value: TimeInterval) -> String { String(format: "%02d:%02d", Int(value) / 60, Int(value) % 60) }
    private func updateIcon(for phase: TrainingPhase) {
        switch phase {
        case .ready: DynamicAppIcon.shared.update(for: .ready)
        case .stimulate: DynamicAppIcon.shared.update(for: .stimulate)
        case .rest: DynamicAppIcon.shared.update(for: .rest)
        case .complete: DynamicAppIcon.shared.update(for: .complete)
        }
    }

    private func showTrainingNotice(_ message: String) {
        trainingNotice = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if trainingNotice == message { trainingNotice = nil }
        }
    }
}

private struct FocusStatusOverlay: View {
    @ObservedObject var model: TrainingModel
    @ObservedObject var motionReceiver: MacMotionReceiver
    @ObservedObject var videoAnalyzer: VideoMotionAnalyzer
    let manualSceneLabel: SceneLabel?

    var body: some View {
        HStack(spacing: 14) {
            if !model.isRunning {
                Text("準備ができたら「トレーニング開始」".localized)
                    .fontWeight(.semibold)
            }
            Text("\(model.phaseTitle)  \(String(format: "%02d:%02d", Int(model.remaining) / 60, Int(model.remaining) % 60))").monospacedDigit()
            Divider().frame(height: 18)
            Text(motionReceiver.latestSample == nil
                 ? "手の動き：未接続".localized
                 : String(format: "手の動き：強さ %d%%  速さ(推定) %d%%".localized, Int(motionReceiver.intensity * 100), Int(motionReceiver.movementSpeed * 100)))
            Text(String(format: "動画 %d%%".localized, Int(videoAnalyzer.motionScore * 100)))
            Text(AppText.value((manualSceneLabel ?? videoAnalyzer.sceneLabel).rawValue))
        }
        .font(.caption)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(0.9)
    }
}

private struct FloatingControls: View {
    @ObservedObject var model: TrainingModel
    let player: AVPlayer
    @Binding var showingImporter: Bool
    @Binding var videoGravity: AVLayerVideoGravity
    @Binding var videoHeight: CGFloat
    @Binding var focusMode: Bool
    @Binding var appFullScreen: Bool
    let onPrevious: () -> Void
    let onChromeChange: (Bool) -> Void
    let onTrainingStart: () -> Void
    let onFinish: () -> Void
    @State private var playbackTime: Double = 0
    @State private var playerPlaying = false

    private var duration: Double {
        let value = player.currentItem?.duration.seconds ?? 0
        return value.isFinite && value > 0 ? value : 1
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: { showingImporter = true }) {
                Image(systemName: "folder")
            }
            .help("動画を選択…".localized)
            Button(action: onPrevious) {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(model.lastVideoURL == nil)
            .help("前回の動画".localized)
            Divider().frame(height: 18)
            Button(playerPlaying ? "一時停止".localized : "再生".localized, systemImage: playerPlaying ? "pause.fill" : "play.fill") {
                if playerPlaying {
                    player.pause()
                } else {
                    player.play()
                }
                playerPlaying.toggle()
            }
            .buttonStyle(.bordered)
            Button(model.isRunning ? "トレーニング停止".localized : "トレーニング開始".localized, systemImage: model.isRunning ? "stop.fill" : "figure.run") {
                if model.isRunning { model.pause() } else { onTrainingStart() }
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isRunning ? .orange : .blue)
            Button("休憩".localized, systemImage: "pause.circle.fill") { model.automaticRest() }
            Text("\(String(format: "%02d:%02d", Int(model.remaining) / 60, Int(model.remaining) % 60))")
                .monospacedDigit()
            Divider().frame(height: 18)
            Slider(value: Binding(
                get: { playbackTime },
                set: { value in
                    playbackTime = value
                    player.seek(to: CMTime(seconds: value, preferredTimescale: 600))
                }
            ), in: 0...duration)
            .frame(width: 180)
            Menu {
                Button("標準サイズ 420px".localized) { videoHeight = 420 }
                Button("大きめ 720px".localized) { videoHeight = 720 }
                Button("画面に合わせる".localized) { videoHeight = max(900, NSScreen.main?.visibleFrame.height ?? 900) }
            } label: {
                Image(systemName: "rectangle.resize.vertical")
            }
            .help("動画サイズ".localized)
            Menu {
                Button("アスペクト比を維持".localized) { videoGravity = .resizeAspect }
                Button("画面いっぱい".localized) { videoGravity = .resizeAspectFill }
                Button("引き伸ばす".localized) { videoGravity = .resize }
            } label: {
                Image(systemName: "rectangle.arrowtriangle.2.inward")
            }
            .help("動画の表示方法".localized)
            Button("終了".localized, systemImage: "stop.fill") { onFinish() }
            Button(appFullScreen ? "解除".localized : "全画面".localized, systemImage: appFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                appFullScreen.toggle()
                focusMode = appFullScreen
                videoHeight = appFullScreen ? max(600, (NSScreen.main?.visibleFrame.height ?? 900) - 80) : 720
                let window = NSApp.keyWindow ?? NSApp.mainWindow
                window?.collectionBehavior.insert(.fullScreenPrimary)
                window?.toggleFullScreen(nil)
                if appFullScreen {
                    onChromeChange(true)
                } else {
                    onChromeChange(false)
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(0.9)
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in
            guard !player.rate.isZero else { return }
            playbackTime = player.currentTime().seconds
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: TrainingModel
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Text("最近のセッション".localized).font(.headline); Spacer(); Button("履歴を消去".localized) { model.clearHistory() }.disabled(model.history.isEmpty) }
            List { ForEach(model.history) { item in HStack { Text(item.date, style: .date); Text(item.date, style: .time); Spacer(); Text("セット (item.completedSets)/(item.sets)") } }.onDelete(perform: model.deleteHistory) }
        }.padding()
    }
}
