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
    
    public func fetchFilteredMediaPaginated(mediaType: String, genreId: Int?, year: String?, minRating: Double?, page: Int = 1) async throws -> (items: [TMDbMediaItem], totalPages: Int) {
        var urlString = "\(AppConfig.tmdbBaseURL)/discover/\(mediaType)?api_key=\(apiKey)&sort_by=popularity.desc&page=\(page)"
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
        guard let url = URL(string: urlString) else { return ([], 0) }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TMDbResponse<TMDbMediaItem>.self, from: data)
        let items = response.results.map { item in
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
        return (items, response.totalPages ?? 1)
    }
    
    public func fetchFilteredMedia(mediaType: String, genreId: Int?, year: String?, minRating: Double?) async throws -> [TMDbMediaItem] {
        let (items, _) = try await fetchFilteredMediaPaginated(mediaType: mediaType, genreId: genreId, year: year, minRating: minRating, page: 1)
        return items
    }
    
    // MARK: - Section Catalog Pagination for Explore "See All"
    public func fetchSectionMediaPaginated(section: String, mediaType: String, page: Int = 1) async throws -> (items: [TMDbMediaItem], totalPages: Int) {
        if mediaType == "all" {
            async let movies = fetchSectionMediaPaginated(section: section, mediaType: "movie", page: page)
            async let tvShows = fetchSectionMediaPaginated(section: section, mediaType: "tv", page: page)
            let (mRes, tRes) = (try await movies, try await tvShows)
            var combined: [TMDbMediaItem] = []
            let maxCount = max(mRes.items.count, tRes.items.count)
            for i in 0..<maxCount {
                if i < mRes.items.count { combined.append(mRes.items[i]) }
                if i < tRes.items.count { combined.append(tRes.items[i]) }
            }
            return (combined, max(mRes.totalPages, tRes.totalPages))
        }
        
        let endpoint: String
        let sectionLower = section.lowercased()
        if sectionLower.contains("trending") {
            endpoint = mediaType == "movie" ? "trending/movie/week" : "trending/tv/week"
        } else if sectionLower.contains("favorited") || sectionLower.contains("favorite") {
            endpoint = mediaType == "movie" ? "movie/top_rated" : "tv/top_rated"
        } else if sectionLower.contains("watched") {
            endpoint = mediaType == "movie" ? "movie/popular" : "tv/popular"
        } else if sectionLower.contains("played") {
            endpoint = mediaType == "movie" ? "movie/now_playing" : "tv/on_the_air"
        } else {
            endpoint = mediaType == "movie" ? "trending/movie/week" : "trending/tv/week"
        }
        
        let urlString = "\(AppConfig.tmdbBaseURL)/\(endpoint)?api_key=\(apiKey)&page=\(page)"
        guard let url = URL(string: urlString) else { return ([], 0) }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TMDbResponse<TMDbMediaItem>.self, from: data)
        let items = response.results.map { item in
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
        return (items, response.totalPages ?? 1)
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
    
    public func fetchByIMDbId(imdbId: String) async throws -> TMDbMediaItem? {
        let urlString = "\(AppConfig.tmdbBaseURL)/find/\(imdbId)?api_key=\(apiKey)&external_source=imdb_id"
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TMDbFindResponse.self, from: data)
        if let movie = response.movieResults?.first {
            return TMDbMediaItem(
                id: movie.id,
                title: movie.title,
                name: movie.name,
                overview: movie.overview,
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                voteAverage: movie.voteAverage,
                voteCount: movie.voteCount,
                releaseDate: movie.releaseDate,
                firstAirDate: movie.firstAirDate,
                mediaType: "movie",
                genreIds: movie.genreIds
            )
        } else if let tv = response.tvResults?.first {
            return TMDbMediaItem(
                id: tv.id,
                title: tv.title,
                name: tv.name,
                overview: tv.overview,
                posterPath: tv.posterPath,
                backdropPath: tv.backdropPath,
                voteAverage: tv.voteAverage,
                voteCount: tv.voteCount,
                releaseDate: tv.releaseDate,
                firstAirDate: tv.firstAirDate,
                mediaType: "tv",
                genreIds: tv.genreIds
            )
        }
        return nil
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
