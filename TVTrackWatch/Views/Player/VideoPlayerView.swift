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
    @State private var avPlayer: AVPlayer? = nil
    
    @State private var kurdishSubtitleURL: URL? = nil
    @State private var englishSubtitleURL: URL? = nil
    @State private var kurdishSubtitleCues: [SubtitleCue] = []
    @State private var englishSubtitleCues: [SubtitleCue] = []
    @State private var selectedSubtitleLanguage: String = "Off"
    @State private var activeSubtitleText: String = ""
    @State private var timeObserverToken: Any? = nil
    
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
                            } else {
                                removeTimeObserver()
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
                        ZStack(alignment: .bottom) {
                            VideoPlayer(player: player)
                                .ignoresSafeArea()
                                .onDisappear {
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
        .onAppear {
            if isFlussonicSelected {
                resolveFlussonicURL()
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
                self.directVideoURL = targetURL
                let newPlayer = AVPlayer(url: targetURL)
                self.avPlayer = newPlayer
                self.setupTimeObserver(player: newPlayer)
                self.isResolvingFlussonic = false
                newPlayer.play()
            }
            
            resolveFlussonicSubtitles(targetURL: targetURL, cleanTitle: cleanTitle, year: year)
        }
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
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken, let player = avPlayer {
            player.removeTimeObserver(token)
            timeObserverToken = nil
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
}
