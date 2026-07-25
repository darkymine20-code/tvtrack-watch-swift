import Foundation

public final class RecommendationEngine {
    public static let shared = RecommendationEngine()
    
    private init() {}
    
    public func generateRecommendations(userHistory: [LocalMediaItem], trendingItems: [TMDbMediaItem]) -> [TMDbMediaItem] {
        // If no user watch history yet, fallback to trending items
        guard !userHistory.isEmpty else {
            return Array(trendingItems.prefix(10))
        }
        
        let watchedIds = Set(userHistory.map { $0.tmdbId })
        let candidates = trendingItems.filter { !watchedIds.contains($0.id) }
        
        // Return top candidates sorted by rating/popularity
        return Array(candidates.sorted(by: { ($0.voteAverage ?? 0.0) > ($1.voteAverage ?? 0.0) }).prefix(10))
    }
}
