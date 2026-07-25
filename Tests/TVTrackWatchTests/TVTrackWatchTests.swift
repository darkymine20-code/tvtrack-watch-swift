import XCTest
@testable import TVTrackWatch

final class TVTrackWatchTests: XCTestCase {
    func testAppConfigKeys() {
        XCTAssertEqual(AppConfig.tmdbApiKey, "92cb9e28d9c7c9028682a433e85ea5d9")
        XCTAssertEqual(AppConfig.traktClientId, "e52812225595b18eeae7720d8ec9322eca18708e1ae1935d0007990be9ae5388")
        XCTAssertFalse(AppConfig.streamingServers.isEmpty)
    }
    
    func testStreamingURLBuilder() {
        let server = AppConfig.streamingServers[0]
        let movieURL = server.getMovieURL(tmdbId: 550)
        XCTAssertEqual(movieURL?.absoluteString, "https://www.vidking.net/embed/movie/550")
        
        let tvURL = server.getTVURL(tmdbId: 1399, season: 1, episode: 1)
        XCTAssertEqual(tvURL?.absoluteString, "https://www.vidking.net/embed/tv/1399/1/1")
    }
    
    func testWatchlistCategorizer() {
        let now = Date()
        let items: [LocalMediaItem] = [
            LocalMediaItem(tmdbId: 1, mediaType: "tv", title: "Show 1", posterPath: nil, backdropPath: nil, voteAverage: 8.0, releaseDate: "2026", isWatchlist: true, watchedEpisodes: [:]), // HaveNotStarted
            LocalMediaItem(tmdbId: 2, mediaType: "tv", title: "Show 2", posterPath: nil, backdropPath: nil, voteAverage: 8.5, releaseDate: "2026", isWatchlist: true, lastWatchedDate: now.addingTimeInterval(-40 * 24 * 3600), watchedEpisodes: ["1_1": "2026-06-01"]), // 30+ Days
            LocalMediaItem(tmdbId: 3, mediaType: "tv", title: "Show 3", posterPath: nil, backdropPath: nil, voteAverage: 9.0, releaseDate: "2026", isWatchlist: true, isWatched: true, watchedEpisodes: ["1_1": "2026-07-20"]), // Waiting for New Episodes
            LocalMediaItem(tmdbId: 4, mediaType: "tv", title: "Show 4", posterPath: nil, backdropPath: nil, voteAverage: 7.5, releaseDate: "2026", isWatchlist: true, lastWatchedDate: now, watchedEpisodes: ["1_1": "2026-07-25"]) // Watch Next
        ]
        
        let categorized = WatchlistCategorizer.categorizeTVWatchlist(items: items)
        XCTAssertEqual(categorized.haveNotStarted.count, 1)
        XCTAssertEqual(categorized.notWatched30Days.count, 1)
        XCTAssertEqual(categorized.waitingForNewEpisodes.count, 1)
        XCTAssertEqual(categorized.watchNext.count, 1)
    }
    
    func testTopStatsThreshold() {
        let items: [LocalMediaItem] = [
            LocalMediaItem(tmdbId: 101, mediaType: "movie", title: "M1", posterPath: nil, backdropPath: nil, voteAverage: 8.0, releaseDate: "2026", isWatched: true, castNames: ["Actor A", "Actor B"], directorNames: ["Director X"]),
            LocalMediaItem(tmdbId: 102, mediaType: "movie", title: "M2", posterPath: nil, backdropPath: nil, voteAverage: 8.0, releaseDate: "2026", isWatched: true, castNames: ["Actor A", "Actor B"], directorNames: ["Director X"]),
            LocalMediaItem(tmdbId: 103, mediaType: "movie", title: "M3", posterPath: nil, backdropPath: nil, voteAverage: 8.0, releaseDate: "2026", isWatched: true, castNames: ["Actor A", "Actor B"], directorNames: ["Director X"]),
            LocalMediaItem(tmdbId: 104, mediaType: "movie", title: "M4", posterPath: nil, backdropPath: nil, voteAverage: 8.0, releaseDate: "2026", isWatched: true, castNames: ["Actor A"], directorNames: ["Director X"])
        ]
        
        let stats = WatchlistCategorizer.calculateTopStats(items: items, minThreshold: 4)
        XCTAssertEqual(stats.topActors.count, 1)
        XCTAssertEqual(stats.topActors.first?.name, "Actor A")
        XCTAssertEqual(stats.topActors.first?.count, 4)
        
        XCTAssertEqual(stats.topDirectors.count, 1)
        XCTAssertEqual(stats.topDirectors.first?.name, "Director X")
        XCTAssertEqual(stats.topDirectors.first?.count, 4)
    }
}
