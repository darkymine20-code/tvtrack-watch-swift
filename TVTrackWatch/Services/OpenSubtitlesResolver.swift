import Foundation

public struct OpenSubItem: Identifiable, Hashable {
    public var id: String { url.absoluteString }
    public let language: String
    public let langCode: String
    public let url: URL
    public let sourceName: String
    
    public init(language: String, langCode: String, url: URL, sourceName: String = "OpenSubtitles") {
        self.language = language
        self.langCode = langCode
        self.url = url
        self.sourceName = sourceName
    }
}

public final class OpenSubtitlesResolver {
    public static let shared = OpenSubtitlesResolver()
    private init() {}
    
    public func fetchSubtitles(imdbId: String, isTV: Bool, season: Int? = nil, episode: Int? = nil) async -> [OpenSubItem] {
        let cleanImdbId = imdbId.starts(with: "tt") ? imdbId : "tt\(imdbId)"
        let endpointString: String
        if isTV, let s = season, let e = episode {
            endpointString = "https://opensubtitles-v3.strem.io/subtitles/series/\(cleanImdbId):\(s):\(e).json"
        } else {
            endpointString = "https://opensubtitles-v3.strem.io/subtitles/movie/\(cleanImdbId).json"
        }
        
        guard let url = URL(string: endpointString) else { return [] }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let subtitles = json["subtitles"] as? [[String: Any]] else {
                return []
            }
            
            var results: [OpenSubItem] = []
            for sub in subtitles {
                guard let rawLang = sub["lang"] as? String,
                      let urlStr = sub["url"] as? String,
                      let subURL = URL(string: urlStr) else { continue }
                
                let lowerLang = rawLang.lowercased()
                if lowerLang.contains("eng") || lowerLang == "en" {
                    results.append(OpenSubItem(language: "English", langCode: "en", url: subURL, sourceName: "OpenSubtitles"))
                } else if lowerLang.contains("kur") || lowerLang == "ku" || lowerLang == "ckb" {
                    results.append(OpenSubItem(language: "Kurdish", langCode: "ku", url: subURL, sourceName: "OpenSubtitles"))
                }
            }
            return results
        } catch {
            print("OpenSubtitles fetch error: \(error)")
            return []
        }
    }
}
