import Foundation

public final class FlussonicResolver {
    public static let shared = FlussonicResolver()
    private init() {}
    
    // MARK: - PascalCase Title Formatting
    public static func formatTitleToPascalCase(_ title: String) -> String {
        // Step 1: Replace ampersand with " And " surrounded by spaces
        let step1 = title.replacingOccurrences(of: "&", with: " And ")
        
        // Step 2: Separate into alphanumeric word components
        let components = step1.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        // Step 3: Capitalize first letter of each word and join into single string
        return components.map { word -> String in
            guard let first = word.first else { return "" }
            return first.uppercased() + word.dropFirst()
        }.joined()
    }
    
    // MARK: - Movie Candidate URLs Generator
    public func generateMovieCandidates(title: String, year: Int) -> [URL] {
        let formatted = Self.formatTitleToPascalCase(title)
        let suffixes = ["\(formatted)-NoSub.mp4", "\(formatted).mp4"]
        
        var directories: [String] = []
        if year >= 2022 {
            directories = [
                "http://130.193.166.118/sss/EnglishMovies1/\(year)",
                "http://130.193.165.194/Flussonic247/EnglishMovies1/\(year)",
                "http://130.193.165.194/Flussonic247/EnglishMovies1/OTHER"
            ]
        } else if year >= 2001 {
            directories = [
                "http://130.193.165.194/Flussonic247/EnglishMovies1/\(year)",
                "http://130.193.166.118/sss/EnglishMovies1/\(year)",
                "http://130.193.165.194/Flussonic247/EnglishMovies1/OTHER"
            ]
        } else {
            directories = [
                "http://130.193.165.194/Flussonic247/EnglishMovies1/OTHER",
                "http://130.193.165.194/Flussonic247/EnglishMovies1/\(year)",
                "http://130.193.166.118/sss/EnglishMovies1/2022"
            ]
        }
        
        var urls: [URL] = []
        for dir in directories {
            for suffix in suffixes {
                if let url = URL(string: "\(dir)/\(suffix)") {
                    urls.append(url)
                }
            }
        }
        return urls
    }
    
    // MARK: - TV Show Candidate URLs Generator
    public func generateTVCandidates(title: String, year: Int, season: Int, episode: Int) -> [URL] {
        let formatted = Self.formatTitleToPascalCase(title)
        let ss = String(format: "%02d", season)
        let ee = String(format: "%02d", episode)
        let s = "\(season)"
        let e = "\(episode)"
        
        let suffixes = [
            "\(formatted)-S\(ss)E\(ee).mp4",
            "\(formatted)_S\(ss)E\(ee).mp4",
            "\(formatted)-S\(s)E\(e).mp4"
        ]
        
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
        for folder in folders {
            for suffix in suffixes {
                if let url = URL(string: "\(folder)/\(suffix)") {
                    urls.append(url)
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
        return candidates.first ?? URL(string: "http://130.193.166.118/sss/EnglishMovies1/\(year)/\(Self.formatTitleToPascalCase(title)).mp4")!
    }
    
    public func resolveTVDirectURL(title: String, year: Int, season: Int, episode: Int) async -> URL {
        let candidates = generateTVCandidates(title: title, year: year, season: season, episode: episode)
        for url in candidates {
            if await probeURL(url) {
                return url
            }
        }
        return candidates.first ?? URL(string: "http://154.48.204.98/Flussonic251/EnglishTvSeries1/\(Self.formatTitleToPascalCase(title))-S\(String(format: "%02d", season))E\(String(format: "%02d", episode)).mp4")!
    }
}
