import Foundation

public final class TraktService: ObservableObject {
    public static let shared = TraktService()
    private let clientId = AppConfig.traktClientId
    private let session = URLSession.shared
    
    private init() {}
    
    private var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "trakt-api-version": "2",
            "trakt-api-key": clientId
        ]
    }
    
    // MARK: - Trakt Generic Item Wrapper
    public struct TraktItemWrapper: Codable {
        public let watcherCount: Int?
        public let playCount: Int?
        public let collectorCount: Int?
        public let movie: TraktMovie?
        public let show: TraktShow?
        
        enum CodingKeys: String, CodingKey {
            case watcherCount = "watcher_count"
            case playCount = "play_count"
            case collectorCount = "collector_count"
            case movie, show
        }
    }
    
    // MARK: - Discovery Feeds (Trending, Most Favorited, Most Watched, Most Played)
    public func fetchTrendingShows() async throws -> [TraktShow] {
        let urlString = "\(AppConfig.traktBaseURL)/shows/trending?extended=full"
        let list: [TraktItemWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.compactMap { $0.show }
    }
    
    public func fetchTrendingMovies() async throws -> [TraktMovie] {
        let urlString = "\(AppConfig.traktBaseURL)/movies/trending?extended=full"
        let list: [TraktItemWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.compactMap { $0.movie }
    }
    
    public func fetchFavoritedShows() async throws -> [TraktShow] {
        let urlString = "\(AppConfig.traktBaseURL)/shows/favorited?extended=full"
        let list: [TraktItemWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.compactMap { $0.show }
    }
    
    public func fetchFavoritedMovies() async throws -> [TraktMovie] {
        let urlString = "\(AppConfig.traktBaseURL)/movies/favorited?extended=full"
        let list: [TraktItemWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.compactMap { $0.movie }
    }
    
    public func fetchWatchedShows() async throws -> [TraktShow] {
        let urlString = "\(AppConfig.traktBaseURL)/shows/watched?extended=full"
        let list: [TraktItemWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.compactMap { $0.show }
    }
    
    public func fetchWatchedMovies() async throws -> [TraktMovie] {
        let urlString = "\(AppConfig.traktBaseURL)/movies/watched?extended=full"
        let list: [TraktItemWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.compactMap { $0.movie }
    }
    
    public func fetchPlayedShows() async throws -> [TraktShow] {
        let urlString = "\(AppConfig.traktBaseURL)/shows/played?extended=full"
        let list: [TraktItemWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.compactMap { $0.show }
    }
    
    public func fetchPlayedMovies() async throws -> [TraktMovie] {
        let urlString = "\(AppConfig.traktBaseURL)/movies/played?extended=full"
        let list: [TraktItemWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.compactMap { $0.movie }
    }
    
    // MARK: - Public Community Comments (Fetching up to 100 comments)
    public func fetchMovieComments(traktIdOrSlug: String) async throws -> [TraktComment] {
        let urlString = "\(AppConfig.traktBaseURL)/movies/\(traktIdOrSlug)/comments/top?extended=full&limit=100"
        return try await fetchAndDecode(urlString: urlString)
    }
    
    public func fetchShowComments(traktIdOrSlug: String) async throws -> [TraktComment] {
        let urlString = "\(AppConfig.traktBaseURL)/shows/\(traktIdOrSlug)/comments/top?extended=full&limit=100"
        return try await fetchAndDecode(urlString: urlString)
    }
    
    // MARK: - Helper
    private func fetchAndDecode<T: Codable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
