import Foundation

public final class FlussonicResolver {
    public static let shared = FlussonicResolver()
    private init() {}
    
    // MARK: - PascalCase Title Formatting with Apostrophe Variations
    public static func formatTitleToPascalCase(_ title: String) -> [String] {
        var variations: [String] = []
        
        // Variation 1: Pre-clean possessives ('s -> s, ' -> empty) e.g., Schindler's -> Schindlers
        let cleaned1 = title
            .replacingOccurrences(of: "'s", with: "s")
            .replacingOccurrences(of: "’s", with: "s")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "&", with: " And ")
        
        let words1 = cleaned1.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let pascal1 = words1.map { word -> String in
            guard let first = word.first else { return "" }
            return first.uppercased() + word.dropFirst()
        }.joined()
        if !pascal1.isEmpty { variations.append(pascal1) }
        
        // Variation 2: Standard split (which capitalizes S in 's e.g., SchindlerSList)
        let cleaned2 = title.replacingOccurrences(of: "&", with: " And ")
        let words2 = cleaned2.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let pascal2 = words2.map { word -> String in
            guard let first = word.first else { return "" }
            return first.uppercased() + word.dropFirst()
        }.joined()
        if !pascal2.isEmpty && !variations.contains(pascal2) {
            variations.append(pascal2)
        }
        
        return variations
    }
    
    // MARK: - Movie Candidate URLs Generator
    public func generateMovieCandidates(title: String, year: Int) -> [URL] {
        let titleVariations = Self.formatTitleToPascalCase(title)
        
        var directories: [String] = []
        if year >= 2022 {
            directories = [
                "http://130.193.166.118/sss/EnglishMovies1/\(year)",
                "http://130.193.165.194/Flussonic247/EnglishMovies1/\(year)",
                "http://130.193.165.194/Flussonic247/EnglishMovies1/OTHER",
                "http://130.193.166.118/sss/EnglishMovies1/OTHER"
            ]
        } else if year >= 2001 {
            directories = [
                "http://130.193.165.194/Flussonic247/EnglishMovies1/\(year)",
                "http://130.193.166.118/sss/EnglishMovies1/\(year)",
                "http://130.193.165.194/Flussonic247/EnglishMovies1/OTHER",
                "http://130.193.166.118/sss/EnglishMovies1/OTHER"
            ]
        } else {
            directories = [
                "http://130.193.165.194/Flussonic247/EnglishMovies1/OTHER",
                "http://130.193.165.194/Flussonic247/EnglishMovies1/\(year)",
                "http://130.193.166.118/sss/EnglishMovies1/\(year)",
                "http://130.193.166.118/sss/EnglishMovies1/OTHER",
                "http://130.193.166.118/sss/EnglishMovies1/2022"
            ]
        }
        
        var urls: [URL] = []
        for formatted in titleVariations {
            let suffixes = ["\(formatted)-NoSub.mp4", "\(formatted).mp4"]
            for dir in directories {
                for suffix in suffixes {
                    if let url = URL(string: "\(dir)/\(suffix)"), !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }
    
    // MARK: - TV Show Candidate URLs Generator
    public func generateTVCandidates(title: String, year: Int, season: Int, episode: Int) -> [URL] {
        let titleVariations = Self.formatTitleToPascalCase(title)
        let ss = String(format: "%02d", season)
        let ee = String(format: "%02d", episode)
        let s = "\(season)"
        let e = "\(episode)"
        
        let primaryPool: String
        let secondaryPool: String
        
        if year >= 2026 {
            primaryPool = "http://130.193.166.197/nasstore/EnglishTvSeries1"
            secondaryPool = "http://154.48.204.98/Flussonic251/EnglishTvSeries1"
        } else {
            primaryPool = "http://154.48.204.98/Flussonic251/EnglishTvSeries1"
            secondaryPool = "http://130.193.166.197/nasstore/EnglishTvSeries1"
        }
        
        let folders = [
            primaryPool,
            "\(primaryPool)/OTHER",
            secondaryPool,
            "\(secondaryPool)/OTHER"
        ]
        
        var urls: [URL] = []
        for formatted in titleVariations {
            let suffixes = [
                "\(formatted)-S\(ss)E\(ee).mp4",
                "\(formatted)_S\(ss)E\(ee).mp4",
                "\(formatted)-S\(s)E\(e).mp4"
            ]
            for folder in folders {
                for suffix in suffixes {
                    if let url = URL(string: "\(folder)/\(suffix)"), !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }
    
    // MARK: - HTTP Probing Logic
    public func probeURL(_ url: URL, timeout: TimeInterval = 3.0) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 206 {
                    return true
                }
            }
        } catch {
            // Range GET probe fallback if server blocks HEAD
            var getRequest = URLRequest(url: url)
            getRequest.httpMethod = "GET"
            getRequest.setValue("bytes=0-100", forHTTPHeaderField: "Range")
            getRequest.timeoutInterval = timeout
            
            if let (_, response) = try? await URLSession.shared.data(for: getRequest),
               let httpResponse = response as? HTTPURLResponse,
               (httpResponse.statusCode == 200 || httpResponse.statusCode == 206) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Resolution Entrypoints
    public func resolveMovieDirectURL(title: String, year: Int) async -> URL {
        let candidates = generateMovieCandidates(title: title, year: year)
        for url in candidates {
            if await probeURL(url) {
                return url
            }
        }
        return candidates.first ?? URL(string: "http://130.193.165.194/Flussonic247/EnglishMovies1/OTHER/SchindlersList-NoSub.mp4")!
    }
    
    public func resolveTVDirectURL(title: String, year: Int, season: Int, episode: Int) async -> URL {
        let candidates = generateTVCandidates(title: title, year: year, season: season, episode: episode)
        for url in candidates {
            if await probeURL(url) {
                return url
            }
        }
        return candidates.first ?? URL(string: "http://154.48.204.98/Flussonic251/EnglishTvSeries1/\(Self.formatTitleToPascalCase(title).first ?? "Show")-S\(String(format: "%02d", season))E\(String(format: "%02d", episode)).mp4")!
    }
}
