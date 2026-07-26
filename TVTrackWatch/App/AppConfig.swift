import Foundation

public struct AppConfig {
    public static let tmdbApiKey = "92cb9e28d9c7c9028682a433e85ea5d9"
    public static let traktClientId = "e52812225595b18eeae7720d8ec9322eca18708e1ae1935d0007990be9ae5388"
    
    public static let tmdbBaseURL = "https://api.themoviedb.org/3"
    public static let tmdbThumbnailBaseURL = "https://image.tmdb.org/t/p/w185" // Fast small thumbnail
    public static let tmdbImageBaseURL = "https://image.tmdb.org/t/p/w500"     // Medium poster
    public static let tmdbBackdropBaseURL = "https://image.tmdb.org/t/p/original" // High-res backdrop
    
    public static let traktBaseURL = "https://api.trakt.tv"
    
    public static let streamingServers: [StreamingServer] = [
        StreamingServer(
            name: "Flussonic Direct Server",
            movieURLTemplate: "flussonic_direct",
            tvURLTemplate: "flussonic_direct"
        ),
        StreamingServer(
            name: "Torrentio + Seedr Cloud",
            movieURLTemplate: "torrentio_seedr",
            tvURLTemplate: "torrentio_seedr"
        ),
        StreamingServer(
            name: "Direct P2P Torrent Engine",
            movieURLTemplate: "direct_p2p_torrent",
            tvURLTemplate: "direct_p2p_torrent"
        ),
        StreamingServer(
            name: "iTorrent Native P2P Core",
            movieURLTemplate: "itorrent_native_p2p",
            tvURLTemplate: "itorrent_native_p2p"
        ),
        StreamingServer(
            name: "Vidking Primary",
            movieURLTemplate: "https://www.vidking.net/embed/movie/{tmdb_id}",
            tvURLTemplate: "https://www.vidking.net/embed/tv/{tmdb_id}/{season_number}/{episode_number}"
        ),
        StreamingServer(
            name: "Vidking Backup",
            movieURLTemplate: "https://vidsrc.me/embed/movie?tmdb={tmdb_id}",
            tvURLTemplate: "https://vidsrc.me/embed/tv?tmdb={tmdb_id}&season={season_number}&episode={episode_number}"
        )
    ]
}

public struct StreamingServer: Identifiable, Hashable, Codable {
    public var id: String { name }
    public let name: String
    public let movieURLTemplate: String
    public let tvURLTemplate: String
    
    public init(name: String, movieURLTemplate: String, tvURLTemplate: String) {
        self.name = name
        self.movieURLTemplate = movieURLTemplate
        self.tvURLTemplate = tvURLTemplate
    }
    
    public func getMovieURL(tmdbId: Int) -> URL? {
        let urlString = movieURLTemplate.replacingOccurrences(of: "{tmdb_id}", with: "\(tmdbId)")
        return URL(string: urlString)
    }
    
    public func getTVURL(tmdbId: Int, season: Int, episode: Int) -> URL? {
        let urlString = tvURLTemplate
            .replacingOccurrences(of: "{tmdb_id}", with: "\(tmdbId)")
            .replacingOccurrences(of: "{season_number}", with: "\(season)")
            .replacingOccurrences(of: "{episode_number}", with: "\(episode)")
        return URL(string: urlString)
    }
}
