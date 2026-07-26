import Foundation
import SwiftTorrent
import Network

/// Real P2P BitTorrent streaming engine powered by SwiftTorrent (pure Swift).
/// Downloads torrent pieces and serves them over a localhost HTTP server
/// for AVPlayer consumption.
@MainActor
public class LibtorrentStreamEngine: ObservableObject {
    public static let shared = LibtorrentStreamEngine()
    
    @Published public var isStreaming = false
    @Published public var progress: Double = 0.0
    @Published public var downloadRate: Double = 0.0
    @Published public var numPeers: Int = 0
    @Published public var statusText: String = ""
    
    private var session: Session?
    private var currentHandle: TorrentHandle?
    private var httpServer: TorrentHTTPServer?
    private var monitorTask: Task<Void, Never>?
    
    private let serverPort: UInt16 = 8080
    
    private init() {}
    
    /// Start streaming a torrent from a magnet URL.
    /// Returns a localhost URL that AVPlayer can use for playback.
    public func startTorrentStream(
        magnetURL: String,
        onStatus: @escaping (String) -> Void
    ) async -> String? {
        // Cleanup previous session
        await stopStream()
        
        onStatus("Initializing BitTorrent session...")
        
        do {
            // Create session
            let savePath = getTorrentSavePath()
            let newSession = Session(settings: SessionSettings())
            self.session = newSession
            
            onStatus("Starting DHT peer discovery...")
            try await newSession.startDHT()
            
            // Extract infoHash from magnet link
            let infoHash = extractInfoHash(from: magnetURL)
            
            // Strategy: Try to fetch .torrent file from cache (instant metadata)
            // This avoids the slow peer-based metadata resolution
            var params: AddTorrentParams
            
            if let hash = infoHash {
                onStatus("Fetching torrent metadata from cache...")
                if let torrentData = await fetchTorrentFromCache(infoHash: hash) {
                    onStatus("✅ Metadata cached! Parsing torrent file...")
                    let torrentInfo = try TorrentInfo.parse(from: torrentData)
                    params = AddTorrentParams(torrentInfo: torrentInfo, savePath: savePath)
                } else {
                    onStatus("Cache miss. Parsing magnet link...")
                    params = try AddTorrentParams.fromMagnet(magnetURL, savePath: savePath)
                }
            } else {
                onStatus("Parsing magnet link...")
                params = try AddTorrentParams.fromMagnet(magnetURL, savePath: savePath)
            }
            
            onStatus("Adding torrent to swarm...")
            let handle = try await newSession.addTorrent(params)
            self.currentHandle = handle
            
            await MainActor.run {
                self.isStreaming = true
                self.statusText = "Connecting to peers..."
            }
            
            // Get torrent info — either already available (from .torrent file) or wait for metadata
            let resolvedInfo: TorrentInfo
            if let files = await handle.getFiles(), !files.isEmpty {
                // Metadata already available (from cached .torrent file)
                onStatus("Metadata ready! Finding video file...")
                // Reconstruct TorrentInfo from the handle's status
                let status = await handle.status()
                // Use getFiles() result directly
                guard let videoFile = findLargestVideoFileFromEntries(files) else {
                    onStatus("❌ No video file found in torrent")
                    return nil
                }
                
                let sizeStr = ByteCountFormatter.string(fromByteCount: videoFile.length, countStyle: .file)
                onStatus("Found video: \(videoFile.path) (\(sizeStr))")
                
                // Start the local HTTP server
                let server = TorrentHTTPServer(port: serverPort, savePath: savePath, videoFile: videoFile)
                try server.start()
                self.httpServer = server
                
                // Start monitoring download progress
                startProgressMonitor(handle: handle, onStatus: onStatus)
                
                // Wait for buffer
                onStatus("Buffering initial data for smooth playback...")
                try await waitForBuffer(handle: handle, threshold: 0.03, onStatus: onStatus)
                
                let streamURL = "http://127.0.0.1:\(serverPort)/stream.mp4"
                onStatus("✅ Stream ready! Playing via native AVPlayer.")
                return streamURL
                
            } else {
                // Need to wait for metadata from peers (magnet link path)
                onStatus("Resolving torrent metadata from peers (this may take a moment)...")
                resolvedInfo = try await handle.waitForMetadata(timeout: 60)
            }
            
            // Find the largest video file
            guard let videoFile = findLargestVideoFile(info: resolvedInfo) else {
                onStatus("❌ No video file found in torrent")
                return nil
            }
            
            let sizeStr = ByteCountFormatter.string(fromByteCount: videoFile.length, countStyle: .file)
            onStatus("Found video: \(videoFile.path) (\(sizeStr))")
            
            // Start the local HTTP server to serve downloaded pieces
            let server = TorrentHTTPServer(port: serverPort, savePath: savePath, videoFile: videoFile)
            try server.start()
            self.httpServer = server
            
            // Start monitoring download progress
            startProgressMonitor(handle: handle, onStatus: onStatus)
            
            // Wait until enough data is buffered
            onStatus("Buffering initial data for smooth playback...")
            try await waitForBuffer(handle: handle, threshold: 0.03, onStatus: onStatus)
            
            let streamURL = "http://127.0.0.1:\(serverPort)/stream.mp4"
            onStatus("✅ Stream ready! Playing via native AVPlayer.")
            
            return streamURL
            
        } catch {
            onStatus("❌ BitTorrent error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Stop the current torrent stream and cleanup resources.
    public func stopStream() async {
        monitorTask?.cancel()
        monitorTask = nil
        
        httpServer?.stop()
        httpServer = nil
        
        if let session = session {
            try? await session.shutdown()
        }
        session = nil
        currentHandle = nil
        
        await MainActor.run {
            self.isStreaming = false
            self.progress = 0.0
            self.downloadRate = 0.0
            self.numPeers = 0
            self.statusText = ""
        }
    }
    
    // MARK: - Private Helpers
    
    private func getTorrentSavePath() -> String {
        let tempDir = NSTemporaryDirectory()
        let torrentDir = (tempDir as NSString).appendingPathComponent("iTorrentStreaming")
        try? FileManager.default.createDirectory(atPath: torrentDir, withIntermediateDirectories: true)
        return torrentDir
    }
    
    private func waitForBuffer(handle: TorrentHandle, threshold: Double, onStatus: @escaping (String) -> Void) async throws {
        for _ in 0..<300 { // 5 minute timeout
            let status = await handle.status()
            let prog = status.progress
            
            await MainActor.run {
                self.progress = prog
            }
            
            if prog >= threshold || status.state == .seeding {
                return
            }
            
            let pct = String(format: "%.1f", prog * 100)
            let speed = ByteCountFormatter.string(fromByteCount: Int64(status.downloadRate), countStyle: .file)
            onStatus("Buffering \(pct)% — \(speed)/s — \(status.numPeers) peers")
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        // If we timed out but have some data, allow playback anyway
    }
    
    private func findLargestVideoFile(info: TorrentInfo) -> TorrentInfo.FileEntry? {
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "ts"]
        
        var largestFile: TorrentInfo.FileEntry? = nil
        
        for file in info.files {
            let ext = (file.path as NSString).pathExtension.lowercased()
            if videoExtensions.contains(ext) {
                if largestFile == nil || file.length > (largestFile?.length ?? 0) {
                    largestFile = file
                }
            }
        }
        
        return largestFile
    }
    
    private func startProgressMonitor(handle: TorrentHandle, onStatus: @escaping (String) -> Void) {
        monitorTask = Task {
            while !Task.isCancelled {
                let status = await handle.status()
                
                await MainActor.run {
                    self.progress = status.progress
                    self.downloadRate = status.downloadRate
                    self.numPeers = status.numPeers
                    
                    let pct = String(format: "%.1f", status.progress * 100)
                    let speed = ByteCountFormatter.string(fromByteCount: Int64(status.downloadRate), countStyle: .file)
                    self.statusText = "\(pct)% — \(speed)/s — \(status.numPeers) peers"
                }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
    
    // MARK: - Torrent Cache Fetch (Skip Metadata Resolution)
    
    /// Extract 40-char hex info hash from magnet URI
    private func extractInfoHash(from magnetURL: String) -> String? {
        // Match btih: followed by 40 hex chars
        if let range = magnetURL.range(of: "btih:([a-fA-F0-9]{40})", options: .regularExpression) {
            let match = magnetURL[range]
            return String(match.dropFirst(5)).lowercased() // drop "btih:"
        }
        return nil
    }
    
    /// Fetch .torrent file from public torrent cache services.
    /// This provides instant metadata without needing peer-based metadata exchange.
    private func fetchTorrentFromCache(infoHash: String) async -> Data? {
        let cacheURLs = [
            "https://itorrents.org/torrent/\(infoHash.uppercased()).torrent",
            "https://btcache.me/torrent/\(infoHash.uppercased())",
            "https://torrage.info/torrent/\(infoHash.uppercased()).torrent"
        ]
        
        for urlString in cacheURLs {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                var request = URLRequest(url: url, timeoutInterval: 8)
                request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   data.count > 50 { // Valid .torrent files are > 50 bytes
                    return data
                }
            } catch {
                continue // Try next cache
            }
        }
        
        return nil
    }
    
    /// Find largest video file from a [TorrentInfo.FileEntry] array
    private func findLargestVideoFileFromEntries(_ files: [TorrentInfo.FileEntry]) -> TorrentInfo.FileEntry? {
        let videoExtensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "ts"]
        
        var largestFile: TorrentInfo.FileEntry? = nil
        
        for file in files {
            let ext = (file.path as NSString).pathExtension.lowercased()
            if videoExtensions.contains(ext) {
                if largestFile == nil || file.length > (largestFile?.length ?? 0) {
                    largestFile = file
                }
            }
        }
        
        return largestFile
    }
}

// MARK: - Local HTTP Server for AVPlayer

/// Lightweight HTTP server that serves downloaded torrent video data to AVPlayer.
class TorrentHTTPServer {
    private let port: UInt16
    private let savePath: String
    private let videoFile: TorrentInfo.FileEntry
    private var listener: NWListener?
    
    init(port: UInt16, savePath: String, videoFile: TorrentInfo.FileEntry) {
        self.port = port
        self.savePath = savePath
        self.videoFile = videoFile
    }
    
    func start() throws {
        let params = NWParameters.tcp
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: .global(qos: .userInteractive))
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInteractive))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            self.serveVideoFile(connection: connection, request: request)
        }
    }
    
    private func serveVideoFile(connection: NWConnection, request: String) {
        let filePath = (savePath as NSString).appendingPathComponent(videoFile.path)
        
        guard FileManager.default.fileExists(atPath: filePath),
              let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }
        
        defer { fileHandle.closeFile() }
        
        let fileSize = videoFile.length
        
        // Parse Range header
        var rangeStart: Int64 = 0
        var rangeEnd: Int64 = fileSize - 1
        
        if let rangeHeader = request.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("range:") }) {
            let rangeValue = rangeHeader.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces)
            if rangeValue.hasPrefix("bytes=") {
                let rangeParts = rangeValue.dropFirst(6).components(separatedBy: "-")
                if let start = Int64(rangeParts[0]) {
                    rangeStart = start
                }
                if rangeParts.count > 1, let end = Int64(rangeParts[1]) {
                    rangeEnd = min(end, fileSize - 1)
                }
            }
        }
        
        let contentLength = rangeEnd - rangeStart + 1
        let mimeType = videoFile.path.hasSuffix(".mkv") ? "video/x-matroska" : "video/mp4"
        
        let headers: String
        if rangeStart == 0 && rangeEnd == fileSize - 1 {
            headers = "HTTP/1.1 200 OK\r\nContent-Type: \(mimeType)\r\nContent-Length: \(fileSize)\r\nAccept-Ranges: bytes\r\n\r\n"
        } else {
            headers = "HTTP/1.1 206 Partial Content\r\nContent-Type: \(mimeType)\r\nContent-Range: bytes \(rangeStart)-\(rangeEnd)/\(fileSize)\r\nContent-Length: \(contentLength)\r\nAccept-Ranges: bytes\r\n\r\n"
        }
        
        // Send headers then file data in chunks
        connection.send(content: headers.data(using: .utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil else {
                connection.cancel()
                return
            }
            self?.sendFileChunks(connection: connection, fileHandle: fileHandle, offset: rangeStart, remaining: contentLength)
        })
    }
    
    private func sendFileChunks(connection: NWConnection, fileHandle: FileHandle, offset: Int64, remaining: Int64) {
        guard remaining > 0 else {
            connection.cancel()
            return
        }
        
        let chunkSize = min(remaining, 512 * 1024) // 512KB chunks
        fileHandle.seek(toFileOffset: UInt64(offset))
        let data = fileHandle.readData(ofLength: Int(chunkSize))
        
        guard !data.isEmpty else {
            connection.cancel()
            return
        }
        
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard error == nil else {
                connection.cancel()
                return
            }
            self?.sendFileChunks(
                connection: connection,
                fileHandle: fileHandle,
                offset: offset + Int64(data.count),
                remaining: remaining - Int64(data.count)
            )
        })
    }
}
