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
            // Auto-remove from watchlist when marked as watched
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
    
    public func toggleEpisodeWatched(tvId: Int, season: Int, episode: Int) {
        let key = "tv_\(tvId)"
        guard var current = items[key] else { return }
        let epKey = "\(season)_\(episode)"
        if current.watchedEpisodes[epKey] != nil {
            current.watchedEpisodes.removeValue(forKey: epKey)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            current.watchedEpisodes[epKey] = dateFormatter.string(from: Date())
            current.lastWatchedDate = Date()
        }
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
