import Foundation

// MARK: - Local Media Item Model (Core Data / Local Cache entity)
public struct LocalMediaItem: Codable, Identifiable, Hashable {
    public var id: String { "\(mediaType)_\(tmdbId)" }
    public let tmdbId: Int
    public let mediaType: String // "movie" or "tv"
    public let title: String
    public let posterPath: String?
    public let backdropPath: String?
    public let voteAverage: Double?
    public let releaseDate: String?
    
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
    
    // TV Show specifics: [Season_Episode: WatchedDateString] e.g. ["1_1": "2026-07-25"]
    public var watchedEpisodes: [String: String]
    
    // Metadata for stats: Cast names & Director names
    public var castNames: [String]
    public var directorNames: [String]

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
        castNames: [String] = [],
        directorNames: [String] = []
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
        self.castNames = castNames
        self.directorNames = directorNames
    }
}
