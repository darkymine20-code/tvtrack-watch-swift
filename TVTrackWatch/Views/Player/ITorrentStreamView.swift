import SwiftUI
import WebKit

/// iTorrent stream view with native AVPlayer handoff bridge.
/// Resolves torrent streams via WebTor.io in the background while:
/// 1. Extracting the raw HLS/MP4 stream URL to hand off to native AVPlayer in-app.
/// 2. Displaying a clean, 100% full-screen chromeless player (no website headers/footers) as a seamless fallback.
public struct ITorrentStreamView: UIViewRepresentable {
    public let magnetURL: String
    public var onStreamFound: ((URL) -> Void)? = nil
    
    public init(magnetURL: String, onStreamFound: ((URL) -> Void)? = nil) {
        self.magnetURL = magnetURL
        self.onStreamFound = onStreamFound
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onStreamFound: onStreamFound)
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Add script message handler to extract native stream URLs
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "streamExtractor")
        
        // Inject JS script at document start to hook video element sources and XHR/fetch
        let hookScript = """
        (function() {
            function reportStream(url) {
                if (!url || typeof url !== 'string') return;
                if (url.startsWith('blob:') || url.startsWith('data:')) return;
                if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('engine.webtor.io') || url.includes('/stream/')) {
                    window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamExtractor && window.webkit.messageHandlers.streamExtractor.postMessage(url);
                }
            }
            
            // Hook HTMLMediaElement.src
            try {
                const descriptor = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
                if (descriptor && descriptor.set) {
                    Object.defineProperty(HTMLMediaElement.prototype, 'src', {
                        set: function(val) {
                            reportStream(val);
                            return descriptor.set.call(this, val);
                        },
                        get: descriptor.get
                    });
                }
            } catch(e) {}
            
            // Hook fetch
            const origFetch = window.fetch;
            window.fetch = function() {
                const arg = arguments[0];
                if (typeof arg === 'string') reportStream(arg);
                else if (arg && arg.url) reportStream(arg.url);
                return origFetch.apply(this, arguments);
            };
            
            // Hook XMLHttpRequest
            const origOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
                if (typeof url === 'string') reportStream(url);
                return origOpen.apply(this, arguments);
            };
        })();
        """
        
        let script = WKUserScript(source: hookScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(script)
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        let encodedMagnet = magnetURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? magnetURL
        let webtorURL = "https://webtor.io/show?magnet=\(encodedMagnet)"
        
        if let url = URL(string: webtorURL) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onStreamFound: ((URL) -> Void)?
        private var hasReportedStream = false
        
        init(onStreamFound: ((URL) -> Void)?) {
            self.onStreamFound = onStreamFound
        }
        
        // Handle JS messages from streamExtractor
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "streamExtractor",
                  let urlString = message.body as? String,
                  let streamURL = URL(string: urlString),
                  !hasReportedStream else { return }
            
            hasReportedStream = true
            DispatchQueue.main.async {
                self.onStreamFound?(streamURL)
            }
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject CSS & JS to hide all web chrome (headers, footers, ads) and auto-play
            let script = """
            (function() {
                // 1. Inject aggressive CSS to hide all non-player UI
                const style = document.createElement('style');
                style.textContent = `
                    body, html {
                        background: #000 !important;
                        overflow: hidden !important;
                        margin: 0 !important;
                        padding: 0 !important;
                    }
                    header, footer, nav, .navbar, .site-header, .site-footer,
                    .ad, .ads, .banner, .cookie-notice, .social-share, .logo,
                    .description, .comments, .related-torrents, .file-list-header {
                        display: none !important;
                        visibility: hidden !important;
                        height: 0 !important;
                        opacity: 0 !important;
                    }
                    .player-container, .webtor-player, video, iframe, .content {
                        width: 100vw !important;
                        height: 100vh !important;
                        max-width: 100vw !important;
                        max-height: 100vh !important;
                        position: fixed !important;
                        top: 0 !important;
                        left: 0 !important;
                        z-index: 999999 !important;
                        background: #000 !important;
                        border: none !important;
                    }
                    video { object-fit: contain !important; }
                `;
                document.head.appendChild(style);
                
                // 2. Interval loop to auto-click video items & check video element sources
                setInterval(function() {
                    // Check for video tag source
                    const video = document.querySelector('video');
                    if (video) {
                        if (video.src && video.src.length > 5 && !video.src.startsWith('blob:')) {
                            window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.streamExtractor && window.webkit.messageHandlers.streamExtractor.postMessage(video.src);
                        }
                        if (video.paused) {
                            video.play().catch(function(){});
                        }
                    }
                    
                    // Auto-click video file items if presented in a list
                    const links = document.querySelectorAll('a, .file-item, .list-group-item, tr, td');
                    for (const link of links) {
                        const txt = (link.innerText || link.textContent || '').toLowerCase();
                        if (txt.match(/\\.(mp4|mkv|avi|mov|flv|webm|m4v)$/)) {
                            if (!link.dataset.autoClicked) {
                                link.dataset.autoClicked = 'true';
                                link.click();
                            }
                        }
                    }
                }, 1000);
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                let host = url.host?.lowercased() ?? ""
                if host.contains("webtor.io") || host.contains("webtor") ||
                   host.contains("jsdelivr.net") || host.contains("cloudflare") ||
                   navigationAction.navigationType == .other {
                    decisionHandler(.allow)
                    return
                }
                if navigationAction.navigationType == .linkActivated {
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
