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
        let tvItems = items.filter { item in
            guard item.mediaType == "tv" && item.isWatchlist && !item.isStoppedWatching else { return false }
            let watchedCount = item.watchedEpisodes.count
            let released = item.releasedEpisodes ?? item.totalEpisodes ?? 0
            let status = item.status ?? ""
            let isEndedOrCanceled = status == "Ended" || status == "Canceled" || status == "Ended / Finished"
            if isEndedOrCanceled && (item.isWatched || (released > 0 && watchedCount >= released)) {
                return false
            }
            return true
        }
        let now = Date()
        let thirtyDaysSeconds: TimeInterval = 30 * 24 * 60 * 60
        
        var watchNext: [LocalMediaItem] = []
        var notWatched30Days: [LocalMediaItem] = []
        var waitingForNewEpisodes: [LocalMediaItem] = []
        var haveNotStarted: [LocalMediaItem] = []
        
        for item in tvItems {
            let watchedCount = item.watchedEpisodes.count
            let released = item.releasedEpisodes ?? 0
            let total = item.totalEpisodes ?? 0
            
            if watchedCount == 0 {
                haveNotStarted.append(item)
            } else if (released > 0 && watchedCount >= released) || item.isWatched || (total > 0 && watchedCount >= total) {
                // User HAS watched all currently aired episodes (e.g. Silo 24/24) -> MUST be in Waiting for New Episodes!
                waitingForNewEpisodes.append(item)
            } else if released > 0 && watchedCount < released {
                // User HAS unwatched released episodes -> Watch Next or Not Watched 30 Days
                if let lastWatched = item.lastWatchedDate, now.timeIntervalSince(lastWatched) > thirtyDaysSeconds {
                    notWatched30Days.append(item)
                } else {
                    watchNext.append(item)
                }
            } else if let lastWatched = item.lastWatchedDate, now.timeIntervalSince(lastWatched) > thirtyDaysSeconds {
                notWatched30Days.append(item)
            } else {
                watchNext.append(item)
            }
        }
        
        return (watchNext, notWatched30Days, waitingForNewEpisodes, haveNotStarted)
    }
    
    // MARK: - Cast & Director Stats
    public static func calculateTopStats(items: [LocalMediaItem], minThreshold: Int = 4) -> (topActors: [PersonStat], topDirectors: [PersonStat]) {
        // Only count watched movies AND watched TV shows (movies + tv shows combined)
        let watchedItems = items.filter { item in
            if item.mediaType == "movie" {
                return item.isWatched
            } else {
                return item.isWatched || !item.watchedEpisodes.isEmpty
            }
        }
        
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
            .filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.value >= minThreshold }
            .map { PersonStat(name: $0.key, count: $0.value, role: "Actor") }
            .sorted(by: { $0.count > $1.count })
        
        let topDirectors = directorCounts
            .filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.value >= minThreshold }
            .map { PersonStat(name: $0.key, count: $0.value, role: "Director") }
            .sorted(by: { $0.count > $1.count })
        
        return (topActors, topDirectors)
    }
}
