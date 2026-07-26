import Foundation

// MARK: - Local Media Item Model (Core Data / Local Cache entity)
public struct LocalMediaItem: Codable, Identifiable, Hashable {
    public var id: String { "\(mediaType)_\(tmdbId)" }
    public let tmdbId: Int
    public let mediaType: String // "movie" or "tv"
    public var title: String
    public var posterPath: String?
    public var backdropPath: String?
    public var voteAverage: Double?
    public var releaseDate: String?
    
    // User State Flags
    public var isWatchlist: Bool
    public var isFavorite: Bool
    public var isWatched: Bool
    public var isStoppedWatching: Bool
    
    // Rating & History
    public var userRating: Double? // 10-star scale (1.0 - 10.0)
    public var lastWatchedDate: Date?
    public var addedToWatchlistDate: Date
    public var playbackProgressSeconds: Double
    
    // Playback progress per episode e.g. ["1_5": 1240.0]
    public var episodeProgressSeconds: [String: Double]
    
    // TV Show specifics: [Season_Episode: WatchedDateString] e.g. ["1_1": "2026-07-25"]
    public var watchedEpisodes: [String: String]
    
    // Metadata for stats: Cast names & Director names
    public var castNames: [String]
    public var directorNames: [String]
    
    // Episode Counts & Status for TV Shows
    public var totalEpisodes: Int?
    public var releasedEpisodes: Int?
    public var status: String? // "Ended", "Returning Series", "Canceled"

    public init(
        tmdbId: Int,
        mediaType: String,
        title: String,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double? = nil,
        releaseDate: String? = nil,
        isWatchlist: Bool = false,
        isFavorite: Bool = false,
        isWatched: Bool = false,
        isStoppedWatching: Bool = false,
        userRating: Double? = nil,
        lastWatchedDate: Date? = nil,
        addedToWatchlistDate: Date = Date(),
        playbackProgressSeconds: Double = 0.0,
        watchedEpisodes: [String: String] = [:],
        episodeProgressSeconds: [String: Double] = [:],
        castNames: [String] = [],
        directorNames: [String] = [],
        totalEpisodes: Int? = nil,
        releasedEpisodes: Int? = nil,
        status: String? = nil
    ) {
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.title = title
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.releaseDate = releaseDate
        self.isWatchlist = isWatchlist
        self.isFavorite = isFavorite
        self.isWatched = isWatched
        self.isStoppedWatching = isStoppedWatching
        self.userRating = userRating
        self.lastWatchedDate = lastWatchedDate
        self.addedToWatchlistDate = addedToWatchlistDate
        self.playbackProgressSeconds = playbackProgressSeconds
        self.watchedEpisodes = watchedEpisodes
        self.episodeProgressSeconds = episodeProgressSeconds
        self.castNames = castNames
        self.directorNames = directorNames
        self.totalEpisodes = totalEpisodes
        self.releasedEpisodes = releasedEpisodes
        self.status = status
    }
    
    enum CodingKeys: String, CodingKey {
        case tmdbId, mediaType, title, posterPath, backdropPath, voteAverage, releaseDate
        case isWatchlist, isFavorite, isWatched, isStoppedWatching
        case userRating, lastWatchedDate, addedToWatchlistDate, playbackProgressSeconds
        case watchedEpisodes, episodeProgressSeconds, castNames, directorNames, totalEpisodes, releasedEpisodes, status
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tmdbId = try container.decode(Int.self, forKey: .tmdbId)
        mediaType = try container.decode(String.self, forKey: .mediaType)
        title = try container.decode(String.self, forKey: .title)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        isWatchlist = try container.decode(Bool.self, forKey: .isWatchlist)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        isWatched = try container.decode(Bool.self, forKey: .isWatched)
        isStoppedWatching = try container.decodeIfPresent(Bool.self, forKey: .isStoppedWatching) ?? false
        userRating = try container.decodeIfPresent(Double.self, forKey: .userRating)
        lastWatchedDate = try container.decodeIfPresent(Date.self, forKey: .lastWatchedDate)
        addedToWatchlistDate = try container.decodeIfPresent(Date.self, forKey: .addedToWatchlistDate) ?? Date()
        playbackProgressSeconds = try container.decodeIfPresent(Double.self, forKey: .playbackProgressSeconds) ?? 0.0
        watchedEpisodes = try container.decodeIfPresent([String: String].self, forKey: .watchedEpisodes) ?? [:]
        episodeProgressSeconds = try container.decodeIfPresent([String: Double].self, forKey: .episodeProgressSeconds) ?? [:]
        castNames = try container.decodeIfPresent([String].self, forKey: .castNames) ?? []
        directorNames = try container.decodeIfPresent([String].self, forKey: .directorNames) ?? []
        totalEpisodes = try container.decodeIfPresent(Int.self, forKey: .totalEpisodes)
        releasedEpisodes = try container.decodeIfPresent(Int.self, forKey: .releasedEpisodes)
        status = try container.decodeIfPresent(String.self, forKey: .status)
    }
}
