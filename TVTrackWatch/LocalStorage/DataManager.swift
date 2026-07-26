import Foundation
import Combine

public final class DataManager: ObservableObject {
    public static let shared = DataManager()
    
    @Published public var items: [String: LocalMediaItem] = [:]
    
    private let storageKey = "tvtrack_local_media_items_v1"
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Actions
    public func toggleWatchlist(item: TMDbMediaItem, castNames: [String] = [], directorNames: [String] = []) {
        let key = "\(item.mediaType ?? "movie")_\(item.id)"
        var current = items[key] ?? createLocalItem(from: item, castNames: castNames, directorNames: directorNames)
        current.isWatchlist.toggle()
        items[key] = current
        saveToDisk()
    }
    
    public func toggleFavorite(item: TMDbMediaItem, castNames: [String] = [], directorNames: [String] = []) {
        let key = "\(item.mediaType ?? "movie")_\(item.id)"
        var current = items[key] ?? createLocalItem(from: item, castNames: castNames, directorNames: directorNames)
        current.isFavorite.toggle()
        items[key] = current
        saveToDisk()
    }
    
    public func toggleWatched(item: TMDbMediaItem, castNames: [String] = [], directorNames: [String] = []) {
        let key = "\(item.mediaType ?? "movie")_\(item.id)"
        var current = items[key] ?? createLocalItem(from: item, castNames: castNames, directorNames: directorNames)
        current.isWatched.toggle()
        if current.isWatched {
            current.lastWatchedDate = Date()
            current.isWatchlist = false
        }
        items[key] = current
        saveToDisk()
    }
    
    public func toggleStoppedWatching(tmdbId: Int, mediaType: String) {
        let key = "\(mediaType)_\(tmdbId)"
        guard var current = items[key] else { return }
        current.isStoppedWatching.toggle()
        items[key] = current
        saveToDisk()
    }
    
    public func setUserRating(tmdbId: Int, mediaType: String, rating: Double) {
        let key = "\(mediaType)_\(tmdbId)"
        guard var current = items[key] else { return }
        current.userRating = rating
        items[key] = current
        saveToDisk()
    }
    
    public func updateEpisodeCounts(tmdbId: Int, totalEpisodes: Int?, releasedEpisodes: Int?) {
        let key = "tv_\(tmdbId)"
        guard var current = items[key] else { return }
        current.totalEpisodes = totalEpisodes
        current.releasedEpisodes = releasedEpisodes
        items[key] = current
        saveToDisk()
    }
    
    // Fix 5: When an episode is marked as watched, automatically save show in Watchlist
    public func toggleEpisodeWatched(
        tvId: Int,
        season: Int,
        episode: Int,
        showTitle: String = "",
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double? = nil,
        releaseDate: String? = nil
    ) {
        let key = "tv_\(tvId)"
        var current = items[key] ?? LocalMediaItem(
            tmdbId: tvId,
            mediaType: "tv",
            title: showTitle.isEmpty ? "TV Show" : showTitle,
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            releaseDate: releaseDate
        )
        
        let epKey = "\(season)_\(episode)"
        if current.watchedEpisodes[epKey] != nil {
            current.watchedEpisodes.removeValue(forKey: epKey)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            current.watchedEpisodes[epKey] = dateFormatter.string(from: Date())
            current.lastWatchedDate = Date()
            // Fix 5: Auto-add TV show to Watchlist when an episode is marked as watched
            current.isWatchlist = true
        }
        items[key] = current
        saveToDisk()
    }
    
    public func markSeasonAsWatched(
        tvId: Int,
        season: Int,
        episodes: [TMDbEpisode],
        showTitle: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double? = nil,
        releaseDate: String? = nil
    ) {
        let key = "tv_\(tvId)"
        var current = items[key] ?? LocalMediaItem(
            tmdbId: tvId,
            mediaType: "tv",
            title: showTitle ?? "",
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            releaseDate: releaseDate
        )
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        
        for ep in episodes {
            let epKey = "\(season)_\(ep.episodeNumber)"
            current.watchedEpisodes[epKey] = todayStr
        }
        
        current.lastWatchedDate = Date()
        current.isWatchlist = true
        items[key] = current
        saveToDisk()
    }
    
    public func updatePlaybackProgress(tmdbId: Int, mediaType: String, seconds: Double) {
        let key = "\(mediaType)_\(tmdbId)"
        guard var current = items[key] else { return }
        current.playbackProgressSeconds = seconds
        current.lastWatchedDate = Date()
        items[key] = current
        saveToDisk()
    }
    
    public func updateCreditsInfo(tmdbId: Int, mediaType: String, castNames: [String], directorNames: [String] = []) {
        let key = "\(mediaType)_\(tmdbId)"
        var current = items[key] ?? LocalMediaItem(
            tmdbId: tmdbId,
            mediaType: mediaType,
            title: mediaType == "movie" ? "Movie" : "TV Show",
            castNames: castNames,
            directorNames: directorNames
        )
        current.castNames = castNames
        if !directorNames.isEmpty {
            current.directorNames = directorNames
        }
        items[key] = current
        saveToDisk()
    }
    
    public func fetchMissingCreditsForWatchedItems() {
        Task {
            let targets = items.values.filter { $0.isWatched || !$0.watchedEpisodes.isEmpty || $0.isWatchlist }
            for item in targets {
                do {
                    if item.mediaType == "tv" {
                        let det = try await TMDbService.shared.fetchTVDetails(id: item.tmdbId)
                        if item.castNames.isEmpty {
                            let cast = det.credits?.cast.prefix(10).map { $0.name } ?? []
                            let directors = det.credits?.crew.filter { $0.job == "Executive Producer" || $0.job == "Director" || $0.job == "Creator" }.map { $0.name } ?? []
                            updateCreditsInfo(tmdbId: item.tmdbId, mediaType: "tv", castNames: Array(cast), directorNames: Array(directors))
                        }
                        
                        // Calculate released episodes
                        var releasedCount = 0
                        if let lastEp = det.lastEpisodeToAir, let lastSeason = lastEp.seasonNumber, let lastEpNum = lastEp.episodeNumber {
                            if let seasons = det.seasons {
                                for season in seasons where season.seasonNumber > 0 && season.seasonNumber < lastSeason {
                                    releasedCount += season.episodeCount ?? 0
                                }
                            }
                            releasedCount += lastEpNum
                        } else if det.status == "Ended" {
                            releasedCount = det.numberOfEpisodes ?? 0
                        } else if let seasons = det.seasons {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            let todayStr = formatter.string(from: Date())
                            for season in seasons where season.seasonNumber > 0 {
                                if let date = season.airDate, !date.isEmpty, date <= todayStr {
                                    releasedCount += season.episodeCount ?? 0
                                }
                            }
                        }
                        if releasedCount == 0, let total = det.numberOfEpisodes {
                            releasedCount = total
                        }
                        updateEpisodeCounts(tmdbId: item.tmdbId, totalEpisodes: det.numberOfEpisodes, releasedEpisodes: releasedCount)
                    } else if item.castNames.isEmpty {
                        let det = try await TMDbService.shared.fetchMovieDetails(id: item.tmdbId)
                        let cast = det.credits?.cast.prefix(10).map { $0.name } ?? []
                        let directors = det.credits?.crew.filter { $0.job == "Director" }.map { $0.name } ?? []
                        updateCreditsInfo(tmdbId: item.tmdbId, mediaType: "movie", castNames: Array(cast), directorNames: Array(directors))
                    }
                } catch {
                    print("Failed pre-fetching details for \(item.title): \(error)")
                }
            }
        }
    }
    
    public func getLocalItem(tmdbId: Int, mediaType: String) -> LocalMediaItem? {
        return items["\(mediaType)_\(tmdbId)"]
    }
    
    // MARK: - Disk Persistence
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save DataManager to disk: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: LocalMediaItem].self, from: data)
            self.items = decoded
        } catch {
            print("Failed to load DataManager from disk: \(error)")
        }
    }
    
    private func createLocalItem(from item: TMDbMediaItem, castNames: [String], directorNames: [String]) -> LocalMediaItem {
        return LocalMediaItem(
            tmdbId: item.id,
            mediaType: item.mediaType ?? "movie",
            title: item.displayTitle,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            voteAverage: item.voteAverage,
            releaseDate: item.releaseDate ?? item.firstAirDate,
            castNames: castNames,
            directorNames: directorNames
        )
    }
}
