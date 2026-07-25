import Foundation

public final class TMDbService: ObservableObject {
    public static let shared = TMDbService()
    private let apiKey = AppConfig.tmdbApiKey
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Movies & TV Discovery
    public func fetchTrendingMovies() async throws -> [TMDbMediaItem] {
        let urlString = "\(AppConfig.tmdbBaseURL)/trending/movie/week?api_key=\(apiKey)"
        return try await fetchMediaList(from: urlString, mediaType: "movie")
    }
    
    public func fetchTrendingTVShows() async throws -> [TMDbMediaItem] {
        let urlString = "\(AppConfig.tmdbBaseURL)/trending/tv/week?api_key=\(apiKey)"
        return try await fetchMediaList(from: urlString, mediaType: "tv")
    }
    
    // MARK: - External IDs Lookup (IMDb ID ttXXXXXXX)
    public func fetchIMDbId(mediaType: String, id: Int) async -> String? {
        let urlString = "\(AppConfig.tmdbBaseURL)/\(mediaType)/\(id)/external_ids?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let imdbId = json["imdb_id"] as? String, !imdbId.isEmpty {
                return imdbId
            }
        } catch {
            print("Error fetching external IDs: \(error)")
        }
        return nil
    }
    
    // MARK: - Paginated Infinite Search
    public func searchMediaPaginated(query: String, page: Int = 1) async throws -> (items: [TMDbMediaItem], totalPages: Int) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return ([], 0) }
        let urlString = "\(AppConfig.tmdbBaseURL)/search/multi?api_key=\(apiKey)&query=\(encodedQuery)&page=\(page)"
        guard let url = URL(string: urlString) else { return ([], 0) }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TMDbResponse<TMDbMediaItem>.self, from: data)
        let filtered = response.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
        return (filtered, response.totalPages ?? 1)
    }
    
    public func searchMedia(query: String) async throws -> [TMDbMediaItem] {
        let (items, _) = try await searchMediaPaginated(query: query, page: 1)
        return items
    }
    
    public func fetchFilteredMedia(mediaType: String, genreId: Int?, year: String?, minRating: Double?) async throws -> [TMDbMediaItem] {
        var urlString = "\(AppConfig.tmdbBaseURL)/discover/\(mediaType)?api_key=\(apiKey)&sort_by=popularity.desc"
        if let genreId = genreId {
            urlString += "&with_genres=\(genreId)"
        }
        if let year = year, !year.isEmpty {
            if mediaType == "movie" {
                urlString += "&primary_release_year=\(year)"
            } else {
                urlString += "&first_air_date_year=\(year)"
            }
        }
        if let minRating = minRating, minRating > 0 {
            urlString += "&vote_average.gte=\(minRating)&vote_count.gte=10"
        }
        return try await fetchMediaList(from: urlString, mediaType: mediaType)
    }
    
    // MARK: - Details & Credits
    public func fetchMovieDetails(id: Int) async throws -> TMDbMovieDetails {
        let urlString = "\(AppConfig.tmdbBaseURL)/movie/\(id)?api_key=\(apiKey)&append_to_response=credits,videos"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(TMDbMovieDetails.self, from: data)
    }
    
    public func fetchTVDetails(id: Int) async throws -> TMDbTVDetails {
        let urlString = "\(AppConfig.tmdbBaseURL)/tv/\(id)?api_key=\(apiKey)&append_to_response=credits,videos,external_ids"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(TMDbTVDetails.self, from: data)
    }
    
    public func fetchMovieCredits(id: Int) async throws -> TMDbCredits {
        let urlString = "\(AppConfig.tmdbBaseURL)/movie/\(id)/credits?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(TMDbCredits.self, from: data)
    }
    
    public func fetchTVCredits(id: Int) async throws -> TMDbCredits {
        let urlString = "\(AppConfig.tmdbBaseURL)/tv/\(id)/credits?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(TMDbCredits.self, from: data)
    }
    
    public func fetchSeasonDetails(tvId: Int, seasonNumber: Int) async throws -> TMDbSeasonDetails {
        let urlString = "\(AppConfig.tmdbBaseURL)/tv/\(tvId)/season/\(seasonNumber)?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(TMDbSeasonDetails.self, from: data)
    }
    
    // MARK: - Helper
    private func fetchMediaList(from urlString: String, mediaType: String) async throws -> [TMDbMediaItem] {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TMDbResponse<TMDbMediaItem>.self, from: data)
        return response.results.map { item in
            TMDbMediaItem(
                id: item.id,
                title: item.title,
                name: item.name,
                overview: item.overview,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                voteAverage: item.voteAverage,
                voteCount: item.voteCount,
                releaseDate: item.releaseDate,
                firstAirDate: item.firstAirDate,
                mediaType: item.mediaType ?? mediaType,
                genreIds: item.genreIds
            )
        }
    }
}
