import Foundation

public struct PersonStat: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let count: Int
    public let role: String // "Actor" or "Director"
}

public final class WatchlistCategorizer {
    
    // MARK: - TV Show Watchlist Sub-sections
    public static func categorizeTVWatchlist(items: [LocalMediaItem]) -> (
        watchNext: [LocalMediaItem],
        notWatched30Days: [LocalMediaItem],
        waitingForNewEpisodes: [LocalMediaItem],
        haveNotStarted: [LocalMediaItem]
    ) {
        let tvItems = items.filter { $0.mediaType == "tv" && $0.isWatchlist && !$0.isStoppedWatching }
        let now = Date()
        let thirtyDaysSeconds: TimeInterval = 30 * 24 * 60 * 60
        
        var watchNext: [LocalMediaItem] = []
        var notWatched30Days: [LocalMediaItem] = []
        var waitingForNewEpisodes: [LocalMediaItem] = []
        var haveNotStarted: [LocalMediaItem] = []
        
        for item in tvItems {
            let watchedCount = item.watchedEpisodes.count
            
            if watchedCount == 0 {
                haveNotStarted.append(item)
            } else if let lastWatched = item.lastWatchedDate, now.timeIntervalSince(lastWatched) > thirtyDaysSeconds {
                notWatched30Days.append(item)
            } else if item.isWatched {
                waitingForNewEpisodes.append(item)
            } else {
                watchNext.append(item)
            }
        }
        
        return (watchNext, notWatched30Days, waitingForNewEpisodes, haveNotStarted)
    }
    
    // MARK: - Cast & Director Stats
    public static func calculateTopStats(items: [LocalMediaItem], minThreshold: Int = 1) -> (topActors: [PersonStat], topDirectors: [PersonStat]) {
        let watchedItems = items.filter { $0.isWatched || !$0.watchedEpisodes.isEmpty || $0.isFavorite || $0.isWatchlist }
        
        var actorCounts: [String: Int] = [:]
        var directorCounts: [String: Int] = [:]
        
        for item in watchedItems {
            for actor in item.castNames {
                actorCounts[actor, default: 0] += 1
            }
            for director in item.directorNames {
                directorCounts[director, default: 0] += 1
            }
        }
        
        let topActors = actorCounts
            .filter { $0.value >= minThreshold }
            .map { PersonStat(name: $0.key, count: $0.value, role: "Actor") }
            .sorted(by: { $0.count > $1.count })
        
        let topDirectors = directorCounts
            .filter { $0.value >= minThreshold }
            .map { PersonStat(name: $0.key, count: $0.value, role: "Director") }
            .sorted(by: { $0.count > $1.count })
        
        return (topActors, topDirectors)
    }
}
