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
                
                // Server Selector Dropdown
                Menu {
                    ForEach(streamingEngine.availableServers) { server in
                        Button(action: {
                            streamingEngine.selectServer(server)
                            if server.name.contains("Flussonic") || server.movieURLTemplate == "flussonic_direct" {
                                resolveFlussonicURL()
                            } else {
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
                            Text("Testing primary and backup mirrors for 200 OK...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    } else if let player = avPlayer {
                        VideoPlayer(player: player)
                            .ignoresSafeArea()
                            .onDisappear {
                                player.pause()
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
        avPlayer?.pause()
        avPlayer = nil
        
        let cleanTitle: String
        if isTV {
            // Strip out S01E01 suffix if passed in title
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
                self.isResolvingFlussonic = false
                newPlayer.play()
            }
        }
    }
}
