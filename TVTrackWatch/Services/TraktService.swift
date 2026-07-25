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
    
    // MARK: - Public Discovery Feeds
    public func fetchTrendingShows() async throws -> [TraktTrendingShow] {
        let urlString = "\(AppConfig.traktBaseURL)/shows/trending?extended=full"
        return try await fetchAndDecode(urlString: urlString)
    }
    
    public func fetchTrendingMovies() async throws -> [TraktTrendingMovie] {
        let urlString = "\(AppConfig.traktBaseURL)/movies/trending?extended=full"
        return try await fetchAndDecode(urlString: urlString)
    }
    
    public func fetchPopularShows() async throws -> [TraktShow] {
        let urlString = "\(AppConfig.traktBaseURL)/shows/popular?extended=full"
        return try await fetchAndDecode(urlString: urlString)
    }
    
    public func fetchPopularMovies() async throws -> [TraktMovie] {
        let urlString = "\(AppConfig.traktBaseURL)/movies/popular?extended=full"
        return try await fetchAndDecode(urlString: urlString)
    }
    
    public func fetchAnticipatedShows() async throws -> [TraktShow] {
        // Trakt anticipated shows endpoint
        let urlString = "\(AppConfig.traktBaseURL)/shows/anticipated?extended=full"
        struct AnticipatedShowWrapper: Codable {
            let show: TraktShow
        }
        let list: [AnticipatedShowWrapper] = try await fetchAndDecode(urlString: urlString)
        return list.map { $0.show }
    }
    
    // MARK: - Public Community Comments
    public func fetchMovieComments(traktIdOrSlug: String) async throws -> [TraktComment] {
        let urlString = "\(AppConfig.traktBaseURL)/movies/\(traktIdOrSlug)/comments/top?extended=full"
        return try await fetchAndDecode(urlString: urlString)
    }
    
    public func fetchShowComments(traktIdOrSlug: String) async throws -> [TraktComment] {
        let urlString = "\(AppConfig.traktBaseURL)/shows/\(traktIdOrSlug)/comments/top?extended=full"
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
