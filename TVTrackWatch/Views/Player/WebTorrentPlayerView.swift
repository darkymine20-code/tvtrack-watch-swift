import SwiftUI
import WebKit

public struct WebTorrentPlayerView: UIViewRepresentable {
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
        
        let htmlContent = generateWebTorrentHTML(magnetURL: magnetURL)
        webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://cdn.jsdelivr.net"))
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    private func generateWebTorrentHTML(magnetURL: String) -> String {
        let escapedMagnet = magnetURL.replacingOccurrences(of: "'", with: "\\'")
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body { margin: 0; padding: 0; background-color: #000; color: #fff; font-family: -apple-system, BlinkMacSystemFont, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; overflow: hidden; }
                video { width: 100vw; height: 100vh; object-fit: contain; background: #000; }
                #status { position: absolute; top: 24px; left: 24px; background: rgba(0,0,0,0.85); padding: 12px 20px; border-radius: 10px; font-size: 15px; font-weight: 600; color: #34c759; z-index: 100; pointer-events: none; border: 1px solid rgba(52, 199, 89, 0.4); backdrop-filter: blur(10px); }
                #player-container { width: 100vw; height: 100vh; display: flex; align-items: center; justify-content: center; }
            </style>
            <script src="https://cdn.jsdelivr.net/npm/webtorrent@latest/webtorrent.min.js"></script>
        </head>
        <body>
            <div id="status">⚡ Connecting to P2P BitTorrent Swarm...</div>
            <div id="player-container"></div>

            <script>
                const client = new WebTorrent();
                const magnetURI = '\(escapedMagnet)';

                client.add(magnetURI, function (torrent) {
                    document.getElementById('status').innerText = '⚡ Connecting to P2P Seeders (' + (torrent.numPeers) + ' peers)...';
                    
                    const file = torrent.files.find(function (f) {
                        const lower = f.name.toLowerCase();
                        return lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.avi') || lower.endsWith('.webm');
                    }) || torrent.files[0];

                    file.appendTo('#player-container', { autoplay: true, controls: true }, function (err, elem) {
                        if (err) {
                            document.getElementById('status').innerText = 'P2P Playback Warning: ' + err.message;
                        } else {
                            setTimeout(function() {
                                document.getElementById('status').style.opacity = '0.3';
                            }, 5000);
                        }
                    });

                    torrent.on('download', function (bytes) {
                        const progress = (torrent.progress * 100).toFixed(1);
                        const speed = (torrent.downloadSpeed / (1024 * 1024)).toFixed(2);
                        document.getElementById('status').innerText = '⚡ P2P Direct Stream: ' + progress + '% (' + speed + ' MB/s, ' + torrent.numPeers + ' peers)';
                    });
                });

                client.on('error', function (err) {
                    document.getElementById('status').innerText = 'P2P Connection Error: ' + err.message;
                });
            </script>
        </body>
        </html>
        """
    }
}
