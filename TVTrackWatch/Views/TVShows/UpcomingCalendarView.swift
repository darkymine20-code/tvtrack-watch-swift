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
                    ProgressView("Checking upcoming episode release schedules...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if upcomingDetailsList.isEmpty {
                    GlassCardView {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 54))
                                .foregroundColor(.blue)
                            Text("No Unreleased Episodes Currently Scheduled")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Shows in your Watchlist are fully caught up or waiting for official future release announcement dates.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .padding(.horizontal)
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
                                        .frame(width: 110, height: 75)
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
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(.green)
                                            Text("Upcoming Release: \(item.airDate)")
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
    
    // Fix 1: Filter ONLY unreleased episodes (airDate >= today)
    private func loadUpcomingSchedule() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        
        var results: [UpcomingShowItem] = []
        for item in watchlistItems {
            do {
                let tv = try await tmdbService.fetchTVDetails(id: item.tmdbId)
                if let seasons = tv.seasons {
                    for seasonSummary in seasons where seasonSummary.seasonNumber > 0 {
                        let seasonDetails = try await tmdbService.fetchSeasonDetails(tvId: item.tmdbId, seasonNumber: seasonSummary.seasonNumber)
                        for ep in seasonDetails.episodes {
                            if let dateStr = ep.airDate, !dateStr.isEmpty, dateStr >= todayStr {
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
                }
            } catch {
                print("Error loading upcoming schedule for \(item.title): \(error)")
            }
        }
        
        self.upcomingDetailsList = results.sorted(by: { $0.airDate < $1.airDate })
        self.isLoading = false
    }
}
