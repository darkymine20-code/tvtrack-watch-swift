import SwiftUI
import WebKit

/// iTorrent streaming engine powered by WebTor.io.
/// Loads WebTor.io directly in WKWebView (not in an iframe) to avoid CSRF issues.
/// WebTor downloads the torrent server-side, transcodes to HLS with FFmpeg,
/// and streams via HTTPS directly in the web view.
public struct ITorrentStreamView: UIViewRepresentable {
    public let magnetURL: String
    
    public init(magnetURL: String) {
        self.magnetURL = magnetURL
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        // Build WebTor.io URL with the magnet link
        let encodedMagnet = magnetURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? magnetURL
        let webtorURL = "https://webtor.io/show?magnet=\(encodedMagnet)"
        
        if let url = URL(string: webtorURL) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    public class Coordinator: NSObject, WKNavigationDelegate {
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject CSS to make the player fill the screen and hide non-essential UI
            let css = """
            document.head.insertAdjacentHTML('beforeend', `
                <style>
                    body { background: #000 !important; overflow: hidden !important; }
                    .navbar, .footer, header, footer, .ad, .ads, .banner,
                    .cookie-notice, .social-share, nav { display: none !important; }
                    .player-container, .webtor-player, video, .content {
                        width: 100vw !important;
                        height: 100vh !important;
                        max-width: 100vw !important;
                        max-height: 100vh !important;
                        position: fixed !important;
                        top: 0 !important;
                        left: 0 !important;
                        z-index: 9999 !important;
                    }
                    video { object-fit: contain !important; }
                </style>
            `);
            """
            webView.evaluateJavaScript(css, completionHandler: nil)
        }
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation within WebTor.io domain
            if let url = navigationAction.request.url {
                let host = url.host?.lowercased() ?? ""
                if host.contains("webtor.io") || host.contains("webtor") || 
                   host.contains("jsdelivr.net") || host.contains("cloudflare") ||
                   navigationAction.navigationType == .other {
                    decisionHandler(.allow)
                    return
                }
                // Block external redirects/ads but allow API calls
                if navigationAction.navigationType == .linkActivated {
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
