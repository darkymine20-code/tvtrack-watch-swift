import SwiftUI
import WebKit

/// iTorrent streaming engine powered by WebTor.io server-side torrent-to-HLS proxy.
/// WebTor downloads the torrent server-side, transcodes to HLS with FFmpeg,
/// and streams via HTTPS directly to this WKWebView — no local BitTorrent client needed.
public struct ITorrentStreamView: UIViewRepresentable {
    public let magnetURL: String
    
    public init(magnetURL: String) {
        self.magnetURL = magnetURL
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        
        let htmlContent = generateITorrentHTML(magnetURL: magnetURL)
        webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://cdn.jsdelivr.net"))
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    private func generateITorrentHTML(magnetURL: String) -> String {
        let escapedMagnet = magnetURL
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "&quot;")
        
        // Percent-encode the full magnet URI for use in the webtor embed src
        let encodedMagnet = magnetURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? magnetURL
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background-color: #000;
                    color: #fff;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    overflow: hidden;
                }
                #status {
                    position: absolute;
                    top: 20px;
                    left: 20px;
                    background: rgba(0,0,0,0.85);
                    padding: 10px 18px;
                    border-radius: 10px;
                    font-size: 14px;
                    font-weight: 600;
                    color: #00d4ff;
                    z-index: 200;
                    pointer-events: none;
                    border: 1px solid rgba(0, 212, 255, 0.4);
                    backdrop-filter: blur(10px);
                    transition: opacity 0.5s ease;
                }
                #player-container {
                    width: 100vw;
                    height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    position: relative;
                }
                video {
                    width: 100vw;
                    height: 100vh;
                    object-fit: contain;
                    background: #000;
                }
                /* WebTor embed iframe styling */
                #webtor-player {
                    width: 100vw;
                    height: 100vh;
                    border: none;
                    background: #000;
                }
            </style>
        </head>
        <body>
            <div id="status">⚡ iTorrent P2P: Connecting to WebTor streaming proxy...</div>
            <div id="player-container">
                <video id="video" controls autoplay playsinline></video>
            </div>
            
            <script>
                const magnetURI = '\(escapedMagnet)';
                const statusEl = document.getElementById('status');
                const videoEl = document.getElementById('video');
                const container = document.getElementById('player-container');
                
                // Extract infoHash from magnet link
                function getInfoHash(magnet) {
                    const match = magnet.match(/btih:([a-fA-F0-9]{40})/i);
                    if (match) return match[1].toLowerCase();
                    const match32 = magnet.match(/btih:([A-Z2-7]{32})/i);
                    if (match32) return match32[1];
                    return null;
                }
                
                const infoHash = getInfoHash(magnetURI);
                
                if (!infoHash) {
                    statusEl.innerText = '❌ Invalid magnet link - no info hash found';
                    statusEl.style.color = '#ff3b30';
                } else {
                    statusEl.innerText = '⚡ iTorrent: Resolving torrent via WebTor proxy (' + infoHash.substring(0, 8) + '...)';
                    
                    // Strategy: Use WebTor.io embed player via iframe
                    // WebTor handles server-side torrent download + HLS transcoding
                    const encodedMagnet = encodeURIComponent(magnetURI);
                    
                    // Remove the video element and use WebTor's iframe player instead
                    videoEl.remove();
                    
                    const iframe = document.createElement('iframe');
                    iframe.id = 'webtor-player';
                    iframe.setAttribute('allowfullscreen', 'true');
                    iframe.setAttribute('allow', 'autoplay; fullscreen');
                    iframe.src = 'https://webtor.io/show?magnet=' + encodedMagnet;
                    container.appendChild(iframe);
                    
                    statusEl.innerText = '⚡ iTorrent: Loading WebTor HLS stream player...';
                    
                    iframe.onload = function() {
                        statusEl.innerText = '⚡ iTorrent: Stream connected! Select video file to play.';
                        setTimeout(function() {
                            statusEl.style.opacity = '0.3';
                        }, 8000);
                    };
                    
                    iframe.onerror = function() {
                        statusEl.innerText = '⚠️ WebTor connection failed. Retrying...';
                        statusEl.style.color = '#ff9500';
                    };
                }
            </script>
        </body>
        </html>
        """
    }
}
