import Foundation

// MARK: - TMDb Movie & TV Models
public struct TMDbMediaItem: Identifiable, Codable, Hashable {
    public let id: Int
    public let title: String?
    public let name: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let releaseDate: String?
    public let firstAirDate: String?
    public let mediaType: String?
    public let genreIds: [Int]?
    
    public var displayTitle: String {
        return title ?? name ?? "Untitled"
    }
    
    public var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)")
    }
    
    public var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "\(AppConfig.tmdbBackdropBaseURL)\(path)")
    }
    
    public var releaseYear: String {
        let dateStr = releaseDate ?? firstAirDate ?? ""
        return String(dateStr.prefix(4))
    }

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case mediaType = "media_type"
        case genreIds = "genre_ids"
    }
}

public struct TMDbResponse<T: Codable>: Codable {
    public let page: Int?
    public let results: [T]
    public let totalPages: Int?
    public let totalResults: Int?
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Detailed Movie & TV Response
public struct TMDbMovieDetails: Codable, Identifiable {
    public let id: Int
    public let title: String
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let releaseDate: String?
    public let runtime: Int?
    public let genres: [TMDbGenre]?
    public let imdbId: String?
    public let credits: TMDbCredits?
    public let videos: TMDbVideoResponse?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, genres, runtime, credits, videos
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDate = "release_date"
        case imdbId = "imdb_id"
    }
    
    public var youtubeTrailerKey: String? {
        videos?.results.first(where: { $0.site == "YouTube" && ($0.type == "Trailer" || $0.type == "Teaser") })?.key
    }
}

public struct TMDbTVDetails: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let firstAirDate: String?
    public let lastAirDate: String?
    public let numberOfSeasons: Int?
    public let numberOfEpisodes: Int?
    public let seasons: [TMDbSeasonSummary]?
    public let genres: [TMDbGenre]?
    public let credits: TMDbCredits?
    public let videos: TMDbVideoResponse?
    public let externalIds: TMDbExternalIds?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, seasons, credits, videos
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case externalIds = "external_ids"
    }
    
    public var youtubeTrailerKey: String? {
        videos?.results.first(where: { $0.site == "YouTube" && ($0.type == "Trailer" || $0.type == "Teaser") })?.key
    }
}

public struct TMDbExternalIds: Codable {
    public let imdbId: String?
    
    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
    }
}

public struct TMDbGenre: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
}

public struct TMDbSeasonSummary: Codable, Identifiable, Hashable {
    public let id: Int
    public let seasonNumber: Int
    public let name: String
    public let episodeCount: Int?
    public let posterPath: String?
    public let airDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
        case airDate = "air_date"
    }
}

public struct TMDbSeasonDetails: Codable, Identifiable {
    public let id: Int
    public let seasonNumber: Int
    public let name: String
    public let overview: String?
    public let posterPath: String?
    public let episodes: [TMDbEpisode]
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, episodes
        case seasonNumber = "season_number"
        case posterPath = "poster_path"
    }
}

public struct TMDbEpisode: Codable, Identifiable, Hashable {
    public let id: Int
    public let episodeNumber: Int
    public let seasonNumber: Int
    public let name: String
    public let overview: String?
    public let stillPath: String?
    public let airDate: String?
    public let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }
    
    public var stillURL: URL? {
        guard let path = stillPath else { return nil }
        return URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)")
    }
}

public struct TMDbCredits: Codable {
    public let cast: [TMDbCastMember]
    public let crew: [TMDbCrewMember]
}

public struct TMDbCastMember: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let character: String?
    public let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
    
    public var profileURL: URL? {
        guard let path = profilePath else { return nil }
        return URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)")
    }
}

public struct TMDbCrewMember: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let job: String?
    public let department: String?
    public let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}

public struct TMDbVideoResponse: Codable {
    public let results: [TMDbVideo]
}

public struct TMDbVideo: Codable, Identifiable {
    public let id: String
    public let key: String
    public let name: String
    public let site: String
    public let type: String
}
