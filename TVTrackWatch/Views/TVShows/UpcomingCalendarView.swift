import SwiftUI

public struct UpcomingCalendarView: View {
    public let watchlistItems: [LocalMediaItem]
    @ObservedObject var tmdbService = TMDbService.shared
    
    @State private var upcomingDetailsList: [UpcomingShowItem] = []
    @State private var isLoading = true
    
    public struct UpcomingShowItem: Identifiable {
        public var id: String { "\(showId)_\(seasonNumber)_\(episodeNumber)" }
        public let showId: Int
        public let showTitle: String
        public let posterPath: String?
        public let seasonNumber: Int
        public let episodeNumber: Int
        public let episodeName: String
        public let airDate: String
        public let overview: String?
        public let stillPath: String?
    }
    
    public init(watchlistItems: [LocalMediaItem]) {
        self.watchlistItems = watchlistItems
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Upcoming Episode Release Calendar")
                    .font(.title2).fontWeight(.black)
                    .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading upcoming episode schedules...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if upcomingDetailsList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 54))
                            .foregroundColor(.gray)
                        Text("No upcoming episodes scheduled for your Watchlist.")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Add TV shows to your Watchlist to automatically track new episode air dates here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(upcomingDetailsList) { item in
                            GlassCardView {
                                HStack(spacing: 16) {
                                    if let path = item.stillPath ?? item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                                        AsyncImage(url: url) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: 100, height: 75)
                                        .cornerRadius(10)
                                        .clipped()
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.showTitle)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 8) {
                                            Text("S\(String(format: "%02d", item.seasonNumber))E\(String(format: "%02d", item.episodeNumber))")
                                                .font(.caption)
                                                .fontWeight(.black)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(6)
                                            
                                            Text(item.episodeName)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                        
                                        HStack(spacing: 6) {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.green)
                                            Text("Airing: \(item.airDate)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .task {
            await loadUpcomingSchedule()
        }
    }
    
    private func loadUpcomingSchedule() async {
        var results: [UpcomingShowItem] = []
        for item in watchlistItems {
            do {
                let tv = try await tmdbService.fetchTVDetails(id: item.tmdbId)
                if let seasons = tv.seasons, let latestSeason = seasons.last(where: { $0.seasonNumber > 0 }) {
                    let seasonDetails = try await tmdbService.fetchSeasonDetails(tvId: item.tmdbId, seasonNumber: latestSeason.seasonNumber)
                    for ep in seasonDetails.episodes {
                        let dateStr = ep.airDate ?? ""
                        if !dateStr.isEmpty {
                            results.append(
                                UpcomingShowItem(
                                    showId: item.tmdbId,
                                    showTitle: tv.name,
                                    posterPath: tv.posterPath,
                                    seasonNumber: ep.seasonNumber,
                                    episodeNumber: ep.episodeNumber,
                                    episodeName: ep.name,
                                    airDate: dateStr,
                                    overview: ep.overview,
                                    stillPath: ep.stillPath
                                )
                            )
                        }
                    }
                }
            } catch {
                print("Error loading upcoming schedule for \(item.title): \(error)")
            }
        }
        
        self.upcomingDetailsList = results.sorted(by: { $0.airDate < $1.airDate })
        self.isLoading = false
    }
}
