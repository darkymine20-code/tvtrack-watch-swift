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
        checkAndRepairMetadataIfNeeded(item: current)
    }
    
    public func toggleFavorite(item: TMDbMediaItem, castNames: [String] = [], directorNames: [String] = []) {
        let key = "\(item.mediaType ?? "movie")_\(item.id)"
        var current = items[key] ?? createLocalItem(from: item, castNames: castNames, directorNames: directorNames)
        current.isFavorite.toggle()
        items[key] = current
        saveToDisk()
        checkAndRepairMetadataIfNeeded(item: current)
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
        checkAndRepairMetadataIfNeeded(item: current)
    }
    
    public func toggleStoppedWatching(tmdbId: Int, mediaType: String) {
        let key = "\(mediaType)_\(tmdbId)"
        guard var current = items[key] else { return }
        current.isStoppedWatching.toggle()
        if current.isStoppedWatching {
            current.isWatchlist = false
            current.isWatched = false
        }
        items[key] = current
        saveToDisk()
    }
    
    public func toggleArchiveShow(item: TMDbMediaItem, castNames: [String] = [], directorNames: [String] = []) {
        let key = "\(item.mediaType ?? "tv")_\(item.id)"
        var current = items[key] ?? createLocalItem(from: item, castNames: castNames, directorNames: directorNames)
        current.isStoppedWatching.toggle()
        if current.isStoppedWatching {
            current.isWatchlist = false
            current.isWatched = false
        }
        items[key] = current
        saveToDisk()
        checkAndRepairMetadataIfNeeded(item: current)
    }
    
    public func setUserRating(tmdbId: Int, mediaType: String, rating: Double) {
        let key = "\(mediaType)_\(tmdbId)"
        guard var current = items[key] else { return }
        current.userRating = rating
        items[key] = current
        saveToDisk()
    }
    
    private func evaluateShowWatchlistState(item: inout LocalMediaItem) {
        guard item.mediaType == "tv" else { return }
        
        let watchedCount = item.watchedEpisodes.count
        let released = item.releasedEpisodes ?? item.totalEpisodes ?? 0
        let status = item.status ?? ""
        let isEndedOrCanceled = status == "Ended" || status == "Canceled" || status == "Ended / Finished"
        
        if released > 0 && watchedCount >= released {
            item.isWatched = true
            if isEndedOrCanceled {
                // Show is finished (e.g. Death Note 37/37) -> Remove from Watchlist into Watched TV Shows (Profile)
                item.isWatchlist = false
            } else {
                // Show is ongoing (e.g. Silo 24/24) -> Keep in Watchlist under Waiting for New Episodes
                item.isWatchlist = true
            }
        } else if released > 0 && watchedCount < released {
            // Unwatched released episodes exist -> Active Watchlist item
            item.isWatched = false
            item.isWatchlist = true
        } else if watchedCount > 0 {
            if isEndedOrCanceled {
                item.isWatched = true
                item.isWatchlist = false
            } else {
                item.isWatchlist = true
            }
        }
    }
    
    public func updateEpisodeCounts(tmdbId: Int, totalEpisodes: Int?, releasedEpisodes: Int?, status: String? = nil) {
        let key = "tv_\(tmdbId)"
        guard var current = items[key] else { return }
        current.totalEpisodes = totalEpisodes
        current.releasedEpisodes = releasedEpisodes
        if let s = status, !s.isEmpty {
            current.status = s
        }
        
        evaluateShowWatchlistState(item: &current)
        
        items[key] = current
        saveToDisk()
    }
    
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
        }
        
        evaluateShowWatchlistState(item: &current)
        items[key] = current
        saveToDisk()
    }
    
    public func toggleSeasonWatched(
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
        
        let allWatched = !episodes.isEmpty && episodes.allSatisfy { ep in
            current.watchedEpisodes["\(season)_\(ep.episodeNumber)"] != nil
        }
        
        if allWatched {
            for ep in episodes {
                current.watchedEpisodes.removeValue(forKey: "\(season)_\(ep.episodeNumber)")
            }
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayStr = dateFormatter.string(from: Date())
            
            for ep in episodes {
                let epKey = "\(season)_\(ep.episodeNumber)"
                current.watchedEpisodes[epKey] = todayStr
            }
            current.lastWatchedDate = Date()
        }
        
        evaluateShowWatchlistState(item: &current)
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
        toggleSeasonWatched(
            tvId: tvId,
            season: season,
            episodes: episodes,
            showTitle: showTitle,
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            releaseDate: releaseDate
        )
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
        updateMediaMetadata(
            tmdbId: tmdbId,
            mediaType: mediaType,
            castNames: castNames,
            directorNames: directorNames
        )
    }
    
    public func updateMediaMetadata(
        tmdbId: Int,
        mediaType: String,
        title: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double? = nil,
        releaseDate: String? = nil,
        castNames: [String]? = nil,
        directorNames: [String]? = nil
    ) {
        let key = "\(mediaType)_\(tmdbId)"
        var current = items[key] ?? LocalMediaItem(
            tmdbId: tmdbId,
            mediaType: mediaType,
            title: title ?? (mediaType == "movie" ? "Movie" : "TV Show"),
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            releaseDate: releaseDate
        )
        
        if let title = title, !title.isEmpty, title != "Movie" && title != "TV Show" && title != "Title" {
            current.title = title
        }
        if let posterPath = posterPath, !posterPath.isEmpty {
            current.posterPath = posterPath
        }
        if let backdropPath = backdropPath, !backdropPath.isEmpty {
            current.backdropPath = backdropPath
        }
        if let voteAverage = voteAverage, voteAverage > 0 {
            current.voteAverage = voteAverage
        }
        if let releaseDate = releaseDate, !releaseDate.isEmpty {
            current.releaseDate = releaseDate
        }
        if let castNames = castNames, !castNames.isEmpty {
            current.castNames = castNames
        }
        if let directorNames = directorNames, !directorNames.isEmpty {
            current.directorNames = directorNames
        }
        
        items[key] = current
        saveToDisk()
    }
    
    public func fetchMissingCreditsForWatchedItems() {
        Task {
            let targets = items.values.filter {
                $0.title == "Movie" || $0.title == "TV Show" || $0.title == "Title" || $0.title == "Untitled" || $0.title.isEmpty || $0.posterPath == nil || $0.posterPath?.isEmpty == true || (($0.isWatched || $0.isWatchlist) && $0.castNames.isEmpty)
            }
            for item in targets {
                do {
                    if item.mediaType == "tv" {
                        let det = try await TMDbService.shared.fetchTVDetails(id: item.tmdbId)
                        let cast = det.credits?.cast.prefix(10).map { $0.name } ?? []
                        let directors = det.credits?.crew.filter { $0.job == "Executive Producer" || $0.job == "Director" || $0.job == "Creator" }.map { $0.name } ?? []
                        
                        updateMediaMetadata(
                            tmdbId: item.tmdbId,
                            mediaType: "tv",
                            title: det.name,
                            posterPath: det.posterPath,
                            backdropPath: det.backdropPath,
                            voteAverage: det.voteAverage,
                            releaseDate: det.firstAirDate,
                            castNames: Array(cast),
                            directorNames: Array(directors)
                        )
                        
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
                        updateEpisodeCounts(tmdbId: item.tmdbId, totalEpisodes: det.numberOfEpisodes, releasedEpisodes: releasedCount, status: det.status)
                    } else {
                        let det = try await TMDbService.shared.fetchMovieDetails(id: item.tmdbId)
                        let cast = det.credits?.cast.prefix(10).map { $0.name } ?? []
                        let directors = det.credits?.crew.filter { $0.job == "Director" }.map { $0.name } ?? []
                        
                        updateMediaMetadata(
                            tmdbId: item.tmdbId,
                            mediaType: "movie",
                            title: det.title,
                            posterPath: det.posterPath,
                            backdropPath: det.backdropPath,
                            voteAverage: det.voteAverage,
                            releaseDate: det.releaseDate,
                            castNames: Array(cast),
                            directorNames: Array(directors)
                        )
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
    
    public func checkAndRepairMetadataIfNeeded(item: LocalMediaItem) {
        if item.title == "Movie" || item.title == "TV Show" || item.title == "Title" || item.title == "Untitled" || item.title.isEmpty || item.posterPath == nil || item.posterPath?.isEmpty == true {
            Task {
                if item.mediaType == "tv" {
                    if let det = try? await TMDbService.shared.fetchTVDetails(id: item.tmdbId) {
                        let cast = det.credits?.cast.prefix(10).map { $0.name } ?? []
                        let directors = det.credits?.crew.filter { $0.job == "Executive Producer" || $0.job == "Director" || $0.job == "Creator" }.map { $0.name } ?? []
                        await MainActor.run {
                            self.updateMediaMetadata(
                                tmdbId: item.tmdbId,
                                mediaType: "tv",
                                title: det.name,
                                posterPath: det.posterPath,
                                backdropPath: det.backdropPath,
                                voteAverage: det.voteAverage,
                                releaseDate: det.firstAirDate,
                                castNames: Array(cast),
                                directorNames: Array(directors)
                            )
                        }
                    }
                } else {
                    if let det = try? await TMDbService.shared.fetchMovieDetails(id: item.tmdbId) {
                        let cast = det.credits?.cast.prefix(10).map { $0.name } ?? []
                        let directors = det.credits?.crew.filter { $0.job == "Director" }.map { $0.name } ?? []
                        await MainActor.run {
                            self.updateMediaMetadata(
                                tmdbId: item.tmdbId,
                                mediaType: "movie",
                                title: det.title,
                                posterPath: det.posterPath,
                                backdropPath: det.backdropPath,
                                voteAverage: det.voteAverage,
                                releaseDate: det.releaseDate,
                                castNames: Array(cast),
                                directorNames: Array(directors)
                            )
                        }
                    }
                }
            }
        }
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
            fetchMissingCreditsForWatchedItems()
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
