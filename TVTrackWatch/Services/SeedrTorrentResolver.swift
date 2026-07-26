import Foundation

public struct TorrentioStreamCandidate: Identifiable {
    public let id = UUID()
    public let titleName: String
    public let infoHash: String
    public let magnetURL: String
    public let sizeBytes: Int64
    public let quality: String
    public let seeders: Int
}

public struct SeedrFolderResponse: Codable {
    public let folders: [SeedrFolderItem]?
    public let files: [SeedrFileItem]?
    public let torrents: [SeedrTorrentItem]?
}

public struct SeedrFolderItem: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let size: Int64?
}

public struct SeedrFileItem: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let size: Int64?
    public let url: String?
}

public struct SeedrTorrentItem: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let size: Int64?
    public let progress: Int?
}

public final class SeedrTorrentResolver {
    public static let shared = SeedrTorrentResolver()
    private init() {}
    
    public var defaultEmail = "hawremhamad2026@gmail.com"
    public var defaultPassword = "19711971"
    private var cachedToken: String? = nil
    
    // Max allowable storage (2.9 GB in Bytes)
    public static let maxSizeBytes: Int64 = Int64(2.9 * 1024.0 * 1024.0 * 1024.0) // 3,113,851,801 bytes
    
    // MARK: - 1. Fetch Torrentio Candidates
    public func fetchTorrentioCandidates(imdbId: String, isTV: Bool, season: Int? = nil, episode: Int? = nil) async -> [TorrentioStreamCandidate] {
        let cleanImdbId = imdbId.starts(with: "tt") ? imdbId : "tt\(imdbId)"
        let endpointString: String
        if isTV, let s = season, let e = episode {
            endpointString = "https://torrentio.strem.fun/stream/series/\(cleanImdbId):\(s):\(e).json"
        } else {
            endpointString = "https://torrentio.strem.fun/stream/movie/\(cleanImdbId).json"
        }
        
        guard let url = URL(string: endpointString) else { return [] }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let streams = json["streams"] as? [[String: Any]] else {
                return []
            }
            
            var candidates: [TorrentioStreamCandidate] = []
            for stream in streams {
                guard let infoHash = stream["infoHash"] as? String else { continue }
                let rawTitle = stream["title"] as? String ?? ""
                let rawName = stream["name"] as? String ?? "Torrentio"
                
                let sizeBytes = parseSizeBytes(from: rawTitle)
                
                // Rule: Do NOT send anything > 2.9 GB
                if let size = sizeBytes, size > Self.maxSizeBytes {
                    continue
                }
                
                let seeders = parseSeeders(from: rawTitle)
                let magnet = "magnet:?xt=urn:btih:\(infoHash)"
                
                candidates.append(TorrentioStreamCandidate(
                    titleName: rawTitle,
                    infoHash: infoHash,
                    magnetURL: magnet,
                    sizeBytes: sizeBytes ?? 0,
                    quality: rawName,
                    seeders: seeders
                ))
            }
            
            // Sort by seeders descending
            return candidates.sorted(by: { $0.seeders > $1.seeders })
        } catch {
            print("Torrentio fetch error: \(error)")
            return []
        }
    }
    
    // MARK: - Helper: Size Parser
    private func parseSizeBytes(from text: String) -> Int64? {
        // Matches e.g. "2.55 GB" or "991.48 MB"
        let range = NSRange(location: 0, length: text.utf16.count)
        let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(GB|MB)"#, options: .caseInsensitive)
        guard let match = regex?.firstMatch(in: text, options: [], range: range) else { return nil }
        
        guard let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let numValue = Double(text[valueRange]) else { return nil }
        
        let unit = text[unitRange].uppercased()
        if unit == "GB" {
            return Int64(numValue * 1024.0 * 1024.0 * 1024.0)
        } else if unit == "MB" {
            return Int64(numValue * 1024.0 * 1024.0)
        }
        return nil
    }
    
    private func parseSeeders(from text: String) -> Int {
        let components = text.components(separatedBy: "\n")
        for line in components {
            if line.contains("👤") || line.contains("👤 ") {
                let parts = line.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let first = parts.first, let val = Int(first) {
                    return val
                }
            }
        }
        return 0
    }
    
    // MARK: - 2. Seedr Authentication
    public func getSeedrAccessToken() async -> String? {
        if let token = cachedToken { return token }
        
        let url = URL(string: "https://www.seedr.cc/oauth_test/token.php")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyString = "grant_type=password&username=\(defaultEmail)&password=\(defaultPassword)&client_id=seedr_chrome"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                self.cachedToken = token
                return token
            }
        } catch {
            print("Seedr login error: \(error)")
        }
        return nil
    }
    
    // MARK: - 3. Check Existing Seedr Storage
    public func checkExistingStream(token: String, title: String) async -> URL? {
        guard let rootFolder = await fetchRootFolder(token: token) else { return nil }
        
        let targetWords = title.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 }
        
        // Check existing folders
        if let folders = rootFolder.folders {
            for folder in folders {
                let cleanFolder = folder.name.lowercased()
                let isMatch = targetWords.isEmpty || targetWords.contains(where: { cleanFolder.contains($0) })
                if isMatch {
                    if let fileURL = await fetchFirstVideoURLInFolder(token: token, folderId: folder.id) {
                        return fileURL
                    }
                }
            }
        }
        
        // Check existing root files
        if let files = rootFolder.files {
            for file in files {
                let fileId = file.id
                let resourceURL = URL(string: "https://www.seedr.cc/oauth_test/resource.php")!
                var req = URLRequest(url: resourceURL)
                req.httpMethod = "POST"
                let body = "access_token=\(token)&func=fetch_file&folder_file_id=\(fileId)"
                req.httpBody = body.data(using: .utf8)
                req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                
                if let (fData, _) = try? await URLSession.shared.data(for: req),
                   let fJson = try? JSONSerialization.jsonObject(with: fData) as? [String: Any],
                   let directUrlStr = fJson["url"] as? String,
                   let directUrl = URL(string: directUrlStr) {
                    return directUrl
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 4. Wipe Seedr Storage
    public func wipeSeedrAccount(token: String) async {
        guard let root = await fetchRootFolder(token: token) else { return }
        
        var deleteList: [[String: Any]] = []
        if let folders = root.folders {
            for f in folders {
                deleteList.append(["type": "folder", "id": f.id])
            }
        }
        if let files = root.files {
            for f in files {
                deleteList.append(["type": "file", "id": f.id])
            }
        }
        if let torrents = root.torrents {
            for t in torrents {
                deleteList.append(["type": "torrent", "id": t.id])
            }
        }
        
        guard !deleteList.isEmpty else { return }
        
        guard let deleteJSONData = try? JSONSerialization.data(withJSONObject: deleteList),
              let deleteJSONString = String(data: deleteJSONData, encoding: .utf8) else { return }
        
        let url = URL(string: "https://www.seedr.cc/oauth_test/resource.php")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let bodyString = "access_token=\(token)&func=delete&delete_arr=\(deleteJSONString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        _ = try? await URLSession.shared.data(for: request)
    }
    
    // MARK: - 5. Send Torrent to Seedr
    public func addMagnetToSeedr(token: String, magnetURL: String) async -> Bool {
        let url = URL(string: "https://www.seedr.cc/oauth_test/resource.php")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let encodedMagnet = magnetURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? magnetURL
        let bodyString = "access_token=\(token)&func=add_torrent&torrent_magnet=\(encodedMagnet)"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let result = json["result"] as? Bool, result == true { return true }
                if json["user_torrent_id"] != nil { return true }
            }
        } catch {
            print("Add magnet error: \(error)")
        }
        return false
    }
    
    // MARK: - 6. Poll Seedr for Stream URL
    public func pollForStreamURL(token: String, maxPolls: Int = 90, onProgress: ((String) -> Void)? = nil) async -> URL? {
        for attempt in 0..<maxPolls {
            try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
            
            if let root = await fetchRootFolder(token: token) {
                // 1. Check if folder created and has video files
                if let folders = root.folders, !folders.isEmpty {
                    for folder in folders {
                        if let fileURL = await fetchFirstVideoURLInFolder(token: token, folderId: folder.id) {
                            onProgress?("Ready! Direct stream URL acquired.")
                            return fileURL
                        }
                    }
                }
                
                // 2. Check if active torrent is downloading
                if let torrents = root.torrents, let firstT = torrents.first {
                    let progress = firstT.progress ?? 0
                    onProgress?("Downloading on Seedr Cloud: \(progress)%...")
                } else {
                    onProgress?("Converting torrent on Seedr Cloud (\(attempt + 1)/\(maxPolls))...")
                }
            }
        }
        return nil
    }
    
    // MARK: - Process Selected Candidate
    public func processUserSelectedCandidate(candidate: TorrentioStreamCandidate, title: String, onProgress: @escaping (String) -> Void) async -> URL? {
        onProgress("Authenticating with Seedr Cloud...")
        guard let token = await getSeedrAccessToken() else {
            onProgress("Failed to authenticate with Seedr account.")
            return nil
        }
        
        // Step 1: Check existing
        onProgress("Checking if \(title) already exists on Seedr...")
        if let existingURL = await checkExistingStream(token: token, title: title) {
            onProgress("Found on Seedr Cloud! Loading stream...")
            return existingURL
        }
        
        // Step 2: Wipe Seedr account
        onProgress("Wiping Seedr storage to make space (3GB)...")
        await wipeSeedrAccount(token: token)
        
        // Step 3: Send magnet
        onProgress("Sending torrent (\(formatSizeBytes(candidate.sizeBytes))) to Seedr...")
        let added = await addMagnetToSeedr(token: token, magnetURL: candidate.magnetURL)
        guard added else {
            onProgress("Failed to add torrent to Seedr.")
            return nil
        }
        
        // Step 4: Poll Seedr with live progress
        return await pollForStreamURL(token: token, maxPolls: 90, onProgress: onProgress)
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
    
    // MARK: - Internal Utilities
    private func fetchRootFolder(token: String) async -> SeedrFolderResponse? {
        guard let url = URL(string: "https://www.seedr.cc/api/folder?access_token=\(token)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(SeedrFolderResponse.self, from: data)
        } catch {
            return nil
        }
    }
    
    private func fetchFirstVideoURLInFolder(token: String, folderId: Int) async -> URL? {
        guard let url = URL(string: "https://www.seedr.cc/api/folder/\(folderId)?access_token=\(token)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = json["files"] as? [[String: Any]] else { return nil }
            
            let videoExtensions = [".mp4", ".mkv", ".avi", ".mov", ".m4v"]
            
            var bestFileId: Int? = nil
            var maxFileSize: Int64 = 0
            
            for file in files {
                guard let name = file["name"] as? String else { continue }
                let ext = (name as NSString).pathExtension.lowercased()
                let isVideo = (file["is_video"] as? Bool) ?? false
                
                if isVideo || videoExtensions.contains(".\(ext)") {
                    let size = (file["size"] as? Int64) ?? 0
                    if size >= maxFileSize {
                        maxFileSize = size
                        bestFileId = file["folder_file_id"] as? Int ?? file["id"] as? Int
                    }
                }
            }
            
            if let fileId = bestFileId {
                let resourceURL = URL(string: "https://www.seedr.cc/oauth_test/resource.php")!
                var req = URLRequest(url: resourceURL)
                req.httpMethod = "POST"
                let body = "access_token=\(token)&func=fetch_file&folder_file_id=\(fileId)"
                req.httpBody = body.data(using: .utf8)
                req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                
                let (fData, _) = try await URLSession.shared.data(for: req)
                if let fJson = try JSONSerialization.jsonObject(with: fData) as? [String: Any],
                   let directUrlStr = fJson["url"] as? String,
                   let directUrl = URL(string: directUrlStr) {
                    return directUrl
                }
            }
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: - Main High-Level Resolution Entrypoint
    public func resolveTorrentioSeedrStream(title: String, imdbId: String, isTV: Bool, season: Int? = nil, episode: Int? = nil) async -> URL? {
        guard let token = await getSeedrAccessToken() else {
            print("Failed to authenticate with Seedr.")
            return nil
        }
        
        if let existingURL = await checkExistingStream(token: token, title: title) {
            return existingURL
        }
        
        let candidates = await fetchTorrentioCandidates(imdbId: imdbId, isTV: isTV, season: season, episode: episode)
        guard let bestCandidate = candidates.first else {
            return nil
        }
        
        await wipeSeedrAccount(token: token)
        
        let added = await addMagnetToSeedr(token: token, magnetURL: bestCandidate.magnetURL)
        guard added else {
            return nil
        }
        
        return await pollForStreamURL(token: token)
    }
}
