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
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        
        loadContent(into: webView, targetURL: url)
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            loadContent(into: uiView, targetURL: url)
        }
    }
    
    private func loadContent(into webView: WKWebView, targetURL: URL) {
        let ext = targetURL.pathExtension.lowercased()
        let isDirectMedia = targetURL.host?.contains("seedr") == true || ["mp4", "mkv", "avi", "mov", "m4v", "webm"].contains(ext)
        
        if isDirectMedia {
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body, html { width: 100%; height: 100%; background-color: #000000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
                video { width: 100%; height: 100%; max-width: 100%; max-height: 100%; object-fit: contain; background-color: #000000; }
            </style>
            </head>
            <body>
                <video controls autoplay playsinline webkit-playsinline name="media">
                    <source src="\(targetURL.absoluteString)">
                </video>
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: targetURL)
        } else {
            var request = URLRequest(url: targetURL)
            request.setValue("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            webView.load(request)
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
    @State private var isResolvingP2P = false
    @State private var isResolvingITorrent = false
    @State private var seedrStatusMessage = ""
    @State private var p2pStatusMessage = ""
    @State private var itorrentStatusMessage = ""
    @State private var activeP2PMagnetURL: String? = nil
    @State private var showTorrentSelectionSheet = false
    @State private var avPlayer: AVPlayer? = nil
    
    @State private var kurdishSubtitleURL: URL? = nil
    @State private var englishSubtitleURL: URL? = nil
    @State private var kurdishSubtitleCues: [SubtitleCue] = []
    @State private var englishSubtitleCues: [SubtitleCue] = []
    @State private var openSubtitlesList: [OpenSubItem] = []
    @State private var selectedOpenSubItem: OpenSubItem? = nil
    @State private var openSubtitlesCues: [String: [SubtitleCue]] = [:]
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
    
    public var isDirectP2PTorrentSelected: Bool {
        streamingEngine.selectedServer.name.contains("P2P") || streamingEngine.selectedServer.movieURLTemplate == "direct_p2p_torrent"
    }
    
    public var isITorrentSelected: Bool {
        streamingEngine.selectedServer.name.contains("iTorrent") || streamingEngine.selectedServer.movieURLTemplate == "itorrent_native_p2p"
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
                        selectedOpenSubItem = nil
                        activeSubtitleText = ""
                    }) {
                        HStack {
                            Text("Off")
                            if selectedSubtitleLanguage == "Off" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    if kurdishSubtitleURL != nil || englishSubtitleURL != nil {
                        Section(header: Text("Flussonic Direct")) {
                            if kurdishSubtitleURL != nil {
                                Button(action: {
                                    selectedSubtitleLanguage = "Kurdish (Flussonic)"
                                    selectedOpenSubItem = nil
                                }) {
                                    HStack {
                                        Text("Kurdish (Flussonic)")
                                        if selectedSubtitleLanguage == "Kurdish (Flussonic)" {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            
                            if englishSubtitleURL != nil {
                                Button(action: {
                                    selectedSubtitleLanguage = "English (Flussonic)"
                                    selectedOpenSubItem = nil
                                }) {
                                    HStack {
                                        Text("English (Flussonic)")
                                        if selectedSubtitleLanguage == "English (Flussonic)" {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if !openSubtitlesList.isEmpty {
                        Section(header: Text("OpenSubtitles Cloud")) {
                            ForEach(openSubtitlesList) { subItem in
                                Button(action: {
                                    selectOpenSubItem(subItem)
                                }) {
                                    HStack {
                                        Text("\(subItem.language) (OpenSubtitles)")
                                        if selectedOpenSubItem?.id == subItem.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
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
                            } else if server.name.contains("iTorrent") || server.movieURLTemplate == "itorrent_native_p2p" {
                                resolveITorrentURL()
                            } else if server.name.contains("P2P") || server.movieURLTemplate == "direct_p2p_torrent" {
                                resolveP2PTorrentURL()
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
                    } else if let directURL = directVideoURL {
                        WebViewWrapper(url: directURL)
                            .ignoresSafeArea()
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
                } else if isITorrentSelected {
                    if isResolvingITorrent {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                .scaleEffect(1.4)
                            Text("iTorrent Native LibTorrent Core")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(itorrentStatusMessage)
                                .font(.subheadline)
                                .foregroundColor(.cyan)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    } else if let player = avPlayer {
                        renderPlayerContainer(player: player)
                    } else if let directURL = directVideoURL {
                        WebViewWrapper(url: directURL)
                            .ignoresSafeArea()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.cyan)
                            Text("iTorrent Core Engine Ready")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(itorrentStatusMessage.isEmpty ? "Select a torrent stream from the iTorrent selector." : itorrentStatusMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    }
                } else if isDirectP2PTorrentSelected {
                    if isResolvingP2P {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                .scaleEffect(1.4)
                            Text("Direct P2P Torrent Engine (No Seedr)")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(p2pStatusMessage)
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    } else if let magnet = activeP2PMagnetURL {
                        WebTorrentPlayerView(magnetURL: magnet)
                            .ignoresSafeArea()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.green)
                            Text("Direct P2P Torrent Engine Ready")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Select a torrent stream from the P2P stream selector menu.")
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
                if isITorrentSelected {
                    processSelectedITorrentCandidate(candidate: candidate)
                } else if isDirectP2PTorrentSelected {
                    processSelectedP2PCandidate(candidate: candidate)
                } else {
                    processSelectedTorrentCandidate(candidate: candidate)
                }
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
    
    private func resolveITorrentURL() {
        isResolvingITorrent = true
        itorrentStatusMessage = "Initializing iTorrent LibTorrent core..."
        removeTimeObserver()
        avPlayer?.pause()
        avPlayer = nil
        
        showTorrentSelectionSheet = true
    }
    
    private func processSelectedITorrentCandidate(candidate: TorrentioStreamCandidate) {
        isResolvingITorrent = true
        itorrentStatusMessage = "Connecting TCP/UDP BitTorrent Trackers..."
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
            if let streamURL = await LibtorrentStreamEngine.shared.startTorrentStream(
                magnetURL: candidate.magnetURL,
                onStatus: { status in
                    DispatchQueue.main.async {
                        self.itorrentStatusMessage = status
                    }
                }
            ) {
                await MainActor.run {
                    self.startPlayingDirectURL(targetURL: streamURL, cleanTitle: cleanTitle, year: year)
                    self.isResolvingITorrent = false
                }
            } else {
                await MainActor.run {
                    self.itorrentStatusMessage = "Failed to stream torrent with iTorrent engine."
                    self.isResolvingITorrent = false
                }
            }
        }
    }
    
    private func resolveP2PTorrentURL() {
        isResolvingP2P = true
        p2pStatusMessage = "Opening P2P torrent stream selector..."
        removeTimeObserver()
        avPlayer?.pause()
        avPlayer = nil
        
        showTorrentSelectionSheet = true
    }
    
    private func processSelectedP2PCandidate(candidate: TorrentioStreamCandidate) {
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
        
        self.activeP2PMagnetURL = candidate.magnetURL
        self.isResolvingP2P = false
        
        resolveAllSubtitles(targetURL: nil, cleanTitle: cleanTitle, year: year)
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
        
        let pathExt = targetURL.pathExtension.lowercased()
        let isAVPlayerCompatible = targetURL.absoluteString.contains("m3u8") || ["mp4", "m4v", "mov", "m3u8"].contains(pathExt)
        
        if isAVPlayerCompatible {
            let headers: [String: String] = [
                "User-Agent": "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            ]
            let asset = AVURLAsset(url: targetURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            let item = AVPlayerItem(asset: asset)
            let newPlayer = AVPlayer(playerItem: item)
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
            newPlayer.play()
        } else {
            // For .mkv, .avi, .webm, WebKit engine decodes and plays it seamlessly
            self.avPlayer = nil
        }
        
        self.isResolvingFlussonic = false
        self.isResolvingSeedr = false
        
        resolveAllSubtitles(targetURL: targetURL, cleanTitle: cleanTitle, year: year)
    }
    
    private func resolveAllSubtitles(targetURL: URL?, cleanTitle: String, year: Int) {
        Task {
            // 1. Fetch Flussonic Direct Subtitles
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
                        self.selectedSubtitleLanguage = "Kurdish (Flussonic)"
                    }
                }
            }
            
            if let enURL = subResult.englishURL {
                let parsed = await FlussonicSubtitleResolver.shared.fetchAndParseSubtitle(from: enURL)
                await MainActor.run {
                    self.englishSubtitleCues = parsed
                    if self.selectedSubtitleLanguage == "Off" && self.kurdishSubtitleCues.isEmpty && !parsed.isEmpty {
                        self.selectedSubtitleLanguage = "English (Flussonic)"
                    }
                }
            }
            
            // 2. Fetch OpenSubtitles Cloud Subtitles
            var resolvedImdbId = await TMDbService.shared.fetchIMDbId(mediaType: isTV ? "tv" : "movie", id: tmdbId) ?? ""
            if resolvedImdbId.isEmpty {
                resolvedImdbId = "tt\(tmdbId)"
            }
            
            let openSubs = await OpenSubtitlesResolver.shared.fetchSubtitles(
                imdbId: resolvedImdbId,
                isTV: isTV,
                season: seasonNumber,
                episode: episodeNumber
            )
            
            await MainActor.run {
                self.openSubtitlesList = openSubs
            }
        }
    }
    
    private func selectOpenSubItem(_ item: OpenSubItem) {
        selectedOpenSubItem = item
        selectedSubtitleLanguage = "\(item.language) (OpenSubtitles)"
        
        if openSubtitlesCues[item.id] != nil { return }
        
        Task {
            let parsed = await FlussonicSubtitleResolver.shared.fetchAndParseSubtitle(from: item.url)
            await MainActor.run {
                self.openSubtitlesCues[item.id] = parsed
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
        if selectedSubtitleLanguage == "Kurdish (Flussonic)" || selectedSubtitleLanguage == "Kurdish (Ku)" {
            targetCues = kurdishSubtitleCues
        } else if selectedSubtitleLanguage == "English (Flussonic)" || selectedSubtitleLanguage == "English (En)" {
            targetCues = englishSubtitleCues
        } else if let openItem = selectedOpenSubItem {
            targetCues = openSubtitlesCues[openItem.id] ?? []
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
