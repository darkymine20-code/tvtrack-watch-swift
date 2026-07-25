import Foundation

public final class StreamingEngine: ObservableObject {
    public static let shared = StreamingEngine()
    @Published public var availableServers: [StreamingServer] = AppConfig.streamingServers
    @Published public var selectedServer: StreamingServer = AppConfig.streamingServers[0]
    
    private init() {}
    
    public func getMovieStreamURL(tmdbId: Int) -> URL? {
        return selectedServer.getMovieURL(tmdbId: tmdbId)
    }
    
    public func getTVStreamURL(tmdbId: Int, season: Int, episode: Int) -> URL? {
        return selectedServer.getTVURL(tmdbId: tmdbId, season: season, episode: episode)
    }
    
    public func selectServer(_ server: StreamingServer) {
        self.selectedServer = server
    }
}
