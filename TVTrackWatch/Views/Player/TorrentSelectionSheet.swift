import SwiftUI

public struct TorrentSelectionSheet: View {
    public let title: String
    public let tmdbId: Int
    public let isTV: Bool
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let onSelectCandidate: (TorrentioStreamCandidate) -> Void
    
    @State private var candidates: [TorrentioStreamCandidate] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    @Environment(\.dismiss) var dismiss
    
    public init(title: String, tmdbId: Int, isTV: Bool, seasonNumber: Int? = nil, episodeNumber: Int? = nil, onSelectCandidate: @escaping (TorrentioStreamCandidate) -> Void) {
        self.title = title
        self.tmdbId = tmdbId
        self.isTV = isTV
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.onSelectCandidate = onSelectCandidate
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            .scaleEffect(1.4)
                        Text("Searching Torrentio Streams...")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Fetching available torrents for \(title)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.purple)
                        Text(error)
                            .font(.headline)
                            .foregroundColor(.white)
                        Button("Retry") {
                            loadCandidates()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                } else if candidates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                        Text("No torrent streams found on Torrentio.")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            Text("Select a torrent stream to send to Seedr Cloud (Max 2.9 GB):")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            ForEach(candidates) { candidate in
                                let isAllowed = candidate.sizeBytes <= SeedrTorrentResolver.maxSizeBytes && candidate.sizeBytes > 0
                                
                                Button(action: {
                                    if isAllowed {
                                        dismiss()
                                        onSelectCandidate(candidate)
                                    }
                                }) {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 8) {
                                                Text(candidate.quality.isEmpty ? "HD" : candidate.quality)
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(isAllowed ? Color.purple.opacity(0.3) : Color.gray.opacity(0.3))
                                                    .foregroundColor(isAllowed ? .purple : .gray)
                                                    .cornerRadius(6)
                                                
                                                if candidate.sizeBytes > 0 {
                                                    Text(formatSizeBytes(candidate.sizeBytes))
                                                        .font(.caption.bold())
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .background(isAllowed ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                                        .foregroundColor(isAllowed ? .green : .red)
                                                        .cornerRadius(6)
                                                }
                                                
                                                Spacer()
                                                
                                                Text("👤 \(candidate.seeders) seeders")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Text(candidate.titleName)
                                                .font(.subheadline)
                                                .foregroundColor(isAllowed ? .white : .gray)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        
                                        Image(systemName: isAllowed ? "paperplane.circle.fill" : "xmark.circle")
                                            .font(.title2)
                                            .foregroundColor(isAllowed ? .purple : .gray)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isAllowed ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .disabled(!isAllowed)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Torrent Streams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCandidates()
        }
    }
    
    private func loadCandidates() {
        isLoading = true
        errorMessage = nil
        
        Task {
            var imdbId = await TMDbService.shared.fetchIMDbId(mediaType: isTV ? "tv" : "movie", id: tmdbId) ?? ""
            if imdbId.isEmpty {
                imdbId = "tt\(tmdbId)"
            }
            
            // Unrestricted fetch to show all streams (with size warnings)
            let fetched = await fetchAllTorrentioCandidates(imdbId: imdbId)
            
            await MainActor.run {
                self.candidates = fetched
                self.isLoading = false
            }
        }
    }
    
    private func fetchAllTorrentioCandidates(imdbId: String) async -> [TorrentioStreamCandidate] {
        let cleanImdbId = imdbId.starts(with: "tt") ? imdbId : "tt\(imdbId)"
        let endpointString: String
        if isTV, let s = seasonNumber, let e = episodeNumber {
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
            
            var list: [TorrentioStreamCandidate] = []
            for stream in streams {
                guard let infoHash = stream["infoHash"] as? String else { continue }
                let rawTitle = stream["title"] as? String ?? ""
                let rawName = stream["name"] as? String ?? "Torrentio"
                
                let sizeBytes = parseSizeBytes(from: rawTitle)
                let seeders = parseSeeders(from: rawTitle)
                let magnet = "magnet:?xt=urn:btih:\(infoHash)"
                
                list.append(TorrentioStreamCandidate(
                    titleName: rawTitle,
                    infoHash: infoHash,
                    magnetURL: magnet,
                    sizeBytes: sizeBytes ?? 0,
                    quality: rawName,
                    seeders: seeders
                ))
            }
            return list.sorted(by: { $0.seeders > $1.seeders })
        } catch {
            return []
        }
    }
    
    private func parseSizeBytes(from text: String) -> Int64? {
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
