import SwiftUI
import WebKit
import AVKit

#if canImport(UIKit)
import UIKit

public struct WebViewWrapper: UIViewRepresentable {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.load(URLRequest(url: url))
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}
#elseif canImport(AppKit)
import AppKit

public struct WebViewWrapper: NSViewRepresentable {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: url))
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
#endif

public struct VideoPlayerView: View {
    @ObservedObject var streamingEngine = StreamingEngine.shared
    public let title: String
    public let tmdbId: Int
    public let releaseYear: Int?
    public let isTV: Bool
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    
    @State private var directVideoURL: URL? = nil
    @State private var isResolvingFlussonic = false
    @State private var isResolvingSeedr = false
    @State private var seedrStatusMessage = ""
    @State private var showTorrentSelectionSheet = false
    @State private var avPlayer: AVPlayer? = nil
    
    @State private var kurdishSubtitleURL: URL? = nil
    @State private var englishSubtitleURL: URL? = nil
    @State private var kurdishSubtitleCues: [SubtitleCue] = []
    @State private var englishSubtitleCues: [SubtitleCue] = []
    @State private var selectedSubtitleLanguage: String = "Off"
    @State private var activeSubtitleText: String = ""
    @State private var timeObserverToken: Any? = nil
    
    @State private var resumeToastMessage: String? = nil
    @State private var lastSavedProgressTime: TimeInterval = 0
    
    @Environment(\.dismiss) var dismiss
    
    public init(title: String, tmdbId: Int, releaseYear: Int? = nil, isTV: Bool = false, seasonNumber: Int? = nil, episodeNumber: Int? = nil) {
        self.title = title
        self.tmdbId = tmdbId
        self.releaseYear = releaseYear
        self.isTV = isTV
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
    }
    
    public var isFlussonicSelected: Bool {
        streamingEngine.selectedServer.name.contains("Flussonic") || streamingEngine.selectedServer.movieURLTemplate == "flussonic_direct"
    }
    
    public var isTorrentioSeedrSelected: Bool {
        streamingEngine.selectedServer.name.contains("Seedr") || streamingEngine.selectedServer.movieURLTemplate == "torrentio_seedr"
    }
    
    public var currentStreamURL: URL? {
        if isTV, let s = seasonNumber, let e = episodeNumber {
            return streamingEngine.getTVStreamURL(tmdbId: tmdbId, season: s, episode: e)
        } else {
            return streamingEngine.getMovieStreamURL(tmdbId: tmdbId)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Player Navigation Top Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    if isTV, let s = seasonNumber, let e = episodeNumber {
                        Text("Season \(s) Episode \(e)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Subtitle Selection Menu
                Menu {
                    Button(action: {
                        selectedSubtitleLanguage = "Off"
                        activeSubtitleText = ""
                    }) {
                        HStack {
                            Text("Off")
                            if selectedSubtitleLanguage == "Off" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: {
                        selectedSubtitleLanguage = "Kurdish (Ku)"
                    }) {
                        HStack {
                            Text("Kurdish (Ku)")
                            if kurdishSubtitleURL != nil {
                                Text("✓")
                            }
                            if selectedSubtitleLanguage == "Kurdish (Ku)" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: {
                        selectedSubtitleLanguage = "English (En)"
                    }) {
                        HStack {
                            Text("English (En)")
                            if englishSubtitleURL != nil {
                                Text("✓")
                            }
                            if selectedSubtitleLanguage == "English (En)" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedSubtitleLanguage == "Off" ? "captions.bubble" : "captions.bubble.fill")
                        Text(selectedSubtitleLanguage == "Off" ? "Subtitles" : selectedSubtitleLanguage)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedSubtitleLanguage != "Off" ? Color.blue.opacity(0.3) : Color.white.opacity(0.15))
                    .foregroundColor(selectedSubtitleLanguage != "Off" ? .blue : .white)
                    .cornerRadius(8)
                }
                .padding(.trailing, 8)
                
                // Server Selector Dropdown
                Menu {
                    ForEach(streamingEngine.availableServers) { server in
                        Button(action: {
                            streamingEngine.selectServer(server)
                            if server.name.contains("Flussonic") || server.movieURLTemplate == "flussonic_direct" {
                                resolveFlussonicURL()
                            } else if server.name.contains("Seedr") || server.movieURLTemplate == "torrentio_seedr" {
                                resolveSeedrTorrentURL()
                            } else {
                                removeTimeObserver()
                                saveCurrentProgress()
                                avPlayer?.pause()
                                avPlayer = nil
                                directVideoURL = nil
                            }
                        }) {
                            HStack {
                                Text(server.name)
                                if server.id == streamingEngine.selectedServer.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "server.rack")
                        Text(streamingEngine.selectedServer.name)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    saveCurrentProgress()
                    removeTimeObserver()
                    avPlayer?.pause()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .padding(.leading, 8)
            }
            .padding()
            .background(Color.black)
            
            // Player Content View
            ZStack {
                if isFlussonicSelected {
                    if isResolvingFlussonic {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(1.4)
                            Text("Probing Flussonic high-speed servers...")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Testing video and subtitle mirrors for 200 OK...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    } else if let player = avPlayer {
                        renderPlayerContainer(player: player)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.yellow)
                            Text("Flussonic direct link unavailable.")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Switching to embed servers...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    }
                } else if isTorrentioSeedrSelected {
                    if isResolvingSeedr {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                .scaleEffect(1.4)
                            Text("Torrentio + Seedr Cloud Engine")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(seedrStatusMessage)
                                .font(.subheadline)
                                .foregroundColor(.purple)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    } else if let player = avPlayer {
                        renderPlayerContainer(player: player)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.purple)
                            Text("Seedr stream resolution failed.")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(seedrStatusMessage.isEmpty ? "No torrent < 2.9 GB available." : seedrStatusMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    }
                } else if let url = currentStreamURL {
                    WebViewWrapper(url: url)
                        .ignoresSafeArea()
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Failed to generate streaming server URL.")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .background(Color.black)
                }
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showTorrentSelectionSheet) {
            TorrentSelectionSheet(
                title: title,
                tmdbId: tmdbId,
                isTV: isTV,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            ) { candidate in
                processSelectedTorrentCandidate(candidate: candidate)
            }
        }
    }
    
    @ViewBuilder
    private func renderPlayerContainer(player: AVPlayer) -> some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottom) {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onDisappear {
                        saveCurrentProgress()
                        removeTimeObserver()
                        player.pause()
                    }
                
                if !activeSubtitleText.isEmpty {
                    Text(activeSubtitleText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 60)
                        .shadow(radius: 6)
                }
            }
            
            if let toast = resumeToastMessage {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.blue)
                    Text(toast)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Start Over") {
                        player.seek(to: .zero)
                        withAnimation { resumeToastMessage = nil }
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.85))
                .cornerRadius(12)
                .padding(.top, 16)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private func resolveFlussonicURL() {
        isResolvingFlussonic = true
        removeTimeObserver()
        avPlayer?.pause()
        avPlayer = nil
        
        let cleanTitle: String
        if isTV {
            if let index = title.range(of: " S")?.lowerBound {
                cleanTitle = String(title[..<index])
            } else {
                cleanTitle = title
            }
        } else {
            cleanTitle = title
        }
        
        let year = releaseYear ?? Calendar.current.component(.year, from: Date())
        
        Task {
            let targetURL: URL
            if isTV, let s = seasonNumber, let e = episodeNumber {
                targetURL = await FlussonicResolver.shared.resolveTVDirectURL(
                    title: cleanTitle,
                    year: year,
                    season: s,
                    episode: e
                )
            } else {
                targetURL = await FlussonicResolver.shared.resolveMovieDirectURL(
                    title: cleanTitle,
                    year: year
                )
            }
            
            await MainActor.run {
                self.startPlayingDirectURL(targetURL: targetURL, cleanTitle: cleanTitle, year: year)
            }
        }
    }
    
    private func resolveSeedrTorrentURL() {
        isResolvingSeedr = true
        seedrStatusMessage = "Checking Seedr Cloud storage..."
        removeTimeObserver()
        avPlayer?.pause()
        avPlayer = nil
        
        let cleanTitle: String
        if isTV {
            if let index = title.range(of: " S")?.lowerBound {
                cleanTitle = String(title[..<index])
            } else {
                cleanTitle = title
            }
        } else {
            cleanTitle = title
        }
        
        let year = releaseYear ?? Calendar.current.component(.year, from: Date())
        
        Task {
            guard let token = await SeedrTorrentResolver.shared.getSeedrAccessToken() else {
                await MainActor.run {
                    self.seedrStatusMessage = "Failed to authenticate with Seedr account."
                    self.isResolvingSeedr = false
                }
                return
            }
            
            // Check if exact title exists on Seedr
            if let existingURL = await SeedrTorrentResolver.shared.checkExistingStream(token: token, title: cleanTitle) {
                await MainActor.run {
                    self.seedrStatusMessage = "Found in Seedr Cloud! Loading stream..."
                    self.startPlayingDirectURL(targetURL: existingURL, cleanTitle: cleanTitle, year: year)
                }
                return
            }
            
            // Open user torrent selection sheet
            await MainActor.run {
                self.showTorrentSelectionSheet = true
            }
        }
    }
    
    private func processSelectedTorrentCandidate(candidate: TorrentioStreamCandidate) {
        isResolvingSeedr = true
        seedrStatusMessage = "Connecting to Seedr Cloud..."
        removeTimeObserver()
        avPlayer?.pause()
        avPlayer = nil
        
        let cleanTitle: String
        if isTV {
            if let index = title.range(of: " S")?.lowerBound {
                cleanTitle = String(title[..<index])
            } else {
                cleanTitle = title
            }
        } else {
            cleanTitle = title
        }
        
        let year = releaseYear ?? Calendar.current.component(.year, from: Date())
        
        Task {
            if let directURL = await SeedrTorrentResolver.shared.processUserSelectedCandidate(
                candidate: candidate,
                title: cleanTitle,
                onProgress: { status in
                    DispatchQueue.main.async {
                        self.seedrStatusMessage = status
                    }
                }
            ) {
                await MainActor.run {
                    self.startPlayingDirectURL(targetURL: directURL, cleanTitle: cleanTitle, year: year)
                }
            } else {
                await MainActor.run {
                    if self.seedrStatusMessage.isEmpty || self.seedrStatusMessage.contains("Downloading") {
                        self.seedrStatusMessage = "Seedr conversion timed out. Try a torrent stream with higher seeders."
                    }
                    self.isResolvingSeedr = false
                }
            }
        }
    }
    
    private func startPlayingDirectURL(targetURL: URL, cleanTitle: String, year: Int) {
        self.directVideoURL = targetURL
        let newPlayer = AVPlayer(url: targetURL)
        self.avPlayer = newPlayer
        
        let savedProgress = DataManager.shared.getPlaybackProgress(
            tmdbId: tmdbId,
            mediaType: isTV ? "tv" : "movie",
            season: seasonNumber,
            episode: episodeNumber
        )
        
        if savedProgress > 5.0 {
            let cmTime = CMTime(seconds: savedProgress, preferredTimescale: 600)
            newPlayer.seek(to: cmTime)
            let formatted = formatSeconds(savedProgress)
            self.resumeToastMessage = "Resumed from \(formatted)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation {
                    if self.resumeToastMessage != nil {
                        self.resumeToastMessage = nil
                    }
                }
            }
        }
        
        self.setupTimeObserver(player: newPlayer)
        self.isResolvingFlussonic = false
        self.isResolvingSeedr = false
        newPlayer.play()
        
        resolveFlussonicSubtitles(targetURL: targetURL, cleanTitle: cleanTitle, year: year)
    }
    
    private func resolveFlussonicSubtitles(targetURL: URL?, cleanTitle: String, year: Int) {
        Task {
            let subResult = await FlussonicSubtitleResolver.shared.resolveSubtitles(
                title: cleanTitle,
                year: year,
                isTV: isTV,
                season: seasonNumber,
                episode: episodeNumber,
                activeStreamURL: targetURL
            )
            
            await MainActor.run {
                self.kurdishSubtitleURL = subResult.kurdishURL
                self.englishSubtitleURL = subResult.englishURL
            }
            
            if let kuURL = subResult.kurdishURL {
                let parsed = await FlussonicSubtitleResolver.shared.fetchAndParseSubtitle(from: kuURL)
                await MainActor.run {
                    self.kurdishSubtitleCues = parsed
                    if self.selectedSubtitleLanguage == "Off" && !parsed.isEmpty {
                        self.selectedSubtitleLanguage = "Kurdish (Ku)"
                    }
                }
            }
            
            if let enURL = subResult.englishURL {
                let parsed = await FlussonicSubtitleResolver.shared.fetchAndParseSubtitle(from: enURL)
                await MainActor.run {
                    self.englishSubtitleCues = parsed
                    if self.selectedSubtitleLanguage == "Off" && self.kurdishSubtitleCues.isEmpty && !parsed.isEmpty {
                        self.selectedSubtitleLanguage = "English (En)"
                    }
                }
            }
        }
    }
    
    private func setupTimeObserver(player: AVPlayer) {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard player != nil else { return }
            let currentTime = time.seconds
            self.updateActiveSubtitle(currentTime: currentTime)
            
            if abs(currentTime - self.lastSavedProgressTime) >= 3.0 && currentTime > 2.0 {
                self.lastSavedProgressTime = currentTime
                DataManager.shared.updatePlaybackProgress(
                    tmdbId: self.tmdbId,
                    mediaType: self.isTV ? "tv" : "movie",
                    seconds: currentTime,
                    season: self.seasonNumber,
                    episode: self.episodeNumber
                )
            }
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken, let player = avPlayer {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    private func saveCurrentProgress() {
        if let player = avPlayer {
            let seconds = player.currentTime().seconds
            if seconds > 2.0 {
                DataManager.shared.updatePlaybackProgress(
                    tmdbId: tmdbId,
                    mediaType: isTV ? "tv" : "movie",
                    seconds: seconds,
                    season: seasonNumber,
                    episode: episodeNumber
                )
            }
        }
    }
    
    private func updateActiveSubtitle(currentTime: TimeInterval) {
        guard selectedSubtitleLanguage != "Off" else {
            if !activeSubtitleText.isEmpty { activeSubtitleText = "" }
            return
        }
        
        let targetCues: [SubtitleCue]
        if selectedSubtitleLanguage == "Kurdish (Ku)" {
            targetCues = kurdishSubtitleCues
        } else if selectedSubtitleLanguage == "English (En)" {
            targetCues = englishSubtitleCues
        } else {
            targetCues = []
        }
        
        if let matching = targetCues.first(where: { currentTime >= $0.startTime && currentTime <= $0.endTime }) {
            if activeSubtitleText != matching.text {
                activeSubtitleText = matching.text
            }
        } else {
            if !activeSubtitleText.isEmpty {
                activeSubtitleText = ""
            }
        }
    }
    
    private func formatSeconds(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hrs = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
    
    private func formatSizeBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return String(format: "%.0f MB", mb)
        }
    }
}
