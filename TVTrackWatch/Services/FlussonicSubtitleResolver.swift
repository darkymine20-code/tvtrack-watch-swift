import Foundation

public struct SubtitleCue: Identifiable, Equatable {
    public let id = UUID()
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    
    public init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

public struct SubtitleResult {
    public let kurdishURL: URL?
    public let englishURL: URL?
}

public final class FlussonicSubtitleResolver {
    public static let shared = FlussonicSubtitleResolver()
    private init() {}
    
    // MARK: - SRT Parser
    public static func parseSRT(_ srtString: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = srtString.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for block in blocks {
            let lines = block.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            guard lines.count >= 2 else { continue }
            
            let timestampLineIndex = lines.firstIndex { $0.contains("-->") } ?? 1
            guard timestampLineIndex < lines.count else { continue }
            
            let timestampLine = lines[timestampLineIndex]
            let timeParts = timestampLine.components(separatedBy: "-->")
            guard timeParts.count == 2 else { continue }
            
            let startTime = parseTimestamp(timeParts[0].trimmingCharacters(in: .whitespaces))
            let endTime = parseTimestamp(timeParts[1].trimmingCharacters(in: .whitespaces))
            
            let textLines = lines.suffix(from: timestampLineIndex + 1)
            let rawText = textLines.joined(separator: "\n")
            let cleanText = rawText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            
            if endTime > startTime && !cleanText.isEmpty {
                cues.append(SubtitleCue(startTime: startTime, endTime: endTime, text: cleanText))
            }
        }
        return cues
    }
    
    private static func parseTimestamp(_ timestamp: String) -> TimeInterval {
        let clean = timestamp.replacingOccurrences(of: ",", with: ".")
        let parts = clean.components(separatedBy: ":")
        guard parts.count == 3 else { return 0 }
        
        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let seconds = Double(parts[2]) ?? 0
        
        return (hours * 3600.0) + (minutes * 60.0) + seconds
    }
    
    // MARK: - Movie Subtitle Candidates Generator
    public func generateMovieSubtitleCandidates(title: String, year: Int, language: String, activeStreamURL: URL? = nil) -> [URL] {
        let titleVariations = FlussonicResolver.formatTitleToPascalCase(title)
        let langCode = language == "Ku" ? "Ku" : "En"
        
        var baseBases = [
            "http://130.193.165.194/Flussonic247/EnglishMovies-Subtitle",
            "http://130.193.166.118/sss/EnglishMovies-Subtitle"
        ]
        
        if let active = activeStreamURL?.host {
            let scheme = activeStreamURL?.scheme ?? "http"
            let customBase = "\(scheme)://\(active)/EnglishMovies-Subtitle"
            if !baseBases.contains(customBase) {
                baseBases.insert(customBase, at: 1)
            }
        }
        
        var yearFolders = ["\(year)"]
        if year != 2025 { yearFolders.append("2025") }
        yearFolders.append(contentsOf: ["OTHER", "Other"])
        
        var urls: [URL] = []
        for formatted in titleVariations {
            let filename = "\(formatted)-\(langCode).srt"
            for base in baseBases {
                for yFolder in yearFolders {
                    let urlString = "\(base)/\(langCode)/\(yFolder)/\(filename)"
                    if let url = URL(string: urlString), !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }
    
    // MARK: - TV Show Subtitle Candidates Generator
    public func generateTVSubtitleCandidates(title: String, year: Int, season: Int, episode: Int, language: String, activeStreamURL: URL? = nil) -> [URL] {
        let titleVariations = FlussonicResolver.formatTitleToPascalCase(title)
        let langCode = language == "Ku" ? "Ku" : "En"
        let ss = String(format: "%02d", season)
        let ee = String(format: "%02d", episode)
        
        var baseBases = [
            "http://154.48.204.98/Flussonic251/EnglishTvSeries-Subtitle",
            "http://130.193.166.118/sss/EnglishTvSeries-Subtitle"
        ]
        
        if let active = activeStreamURL?.host {
            let scheme = activeStreamURL?.scheme ?? "http"
            let customBase = "\(scheme)://\(active)/EnglishTvSeries-Subtitle"
            if !baseBases.contains(customBase) {
                baseBases.insert(customBase, at: 1)
            }
        }
        
        var folders: [String?] = [nil, "\(year)", "OTHER", "Other", "2025", "2024"]
        
        var urls: [URL] = []
        for formatted in titleVariations {
            let filename = "\(formatted)-\(langCode)-S\(ss)E\(ee).srt"
            for base in baseBases {
                for f in folders {
                    let urlString: String
                    if let folder = f {
                        urlString = "\(base)/\(langCode)/\(folder)/\(filename)"
                    } else {
                        urlString = "\(base)/\(langCode)/\(filename)"
                    }
                    if let url = URL(string: urlString), !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }
    
    // MARK: - Subtitle Resolution Entrypoint
    public func resolveSubtitles(title: String, year: Int, isTV: Bool, season: Int? = nil, episode: Int? = nil, activeStreamURL: URL? = nil) async -> SubtitleResult {
        async let kurdish = resolveLanguageSubtitle(title: title, year: year, isTV: isTV, season: season, episode: episode, language: "Ku", activeStreamURL: activeStreamURL)
        async let english = resolveLanguageSubtitle(title: title, year: year, isTV: isTV, season: season, episode: episode, language: "En", activeStreamURL: activeStreamURL)
        
        let (kuURL, enURL) = await (kurdish, english)
        return SubtitleResult(kurdishURL: kuURL, englishURL: enURL)
    }
    
    private func resolveLanguageSubtitle(title: String, year: Int, isTV: Bool, season: Int?, episode: Int?, language: String, activeStreamURL: URL?) async -> URL? {
        let candidates: [URL]
        if isTV, let s = season, let e = episode {
            candidates = generateTVSubtitleCandidates(title: title, year: year, season: s, episode: e, language: language, activeStreamURL: activeStreamURL)
        } else {
            candidates = generateMovieSubtitleCandidates(title: title, year: year, language: language, activeStreamURL: activeStreamURL)
        }
        
        for url in candidates {
            if await FlussonicResolver.shared.probeURL(url) {
                return url
            }
        }
        return nil
    }
    
    // MARK: - Download & Parse SRT
    public func fetchAndParseSubtitle(from url: URL) async -> [SubtitleCue] {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            let (data, _) = try await URLSession.shared.data(for: request)
            if let srtString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                return Self.parseSRT(srtString)
            }
        } catch {
            print("Error downloading subtitle from \(url): \(error)")
        }
        return []
    }
}
