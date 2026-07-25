import SwiftUI

public struct TVShowsWatchlistView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var selectedTab = 0 // 0: Watchlist, 1: Upcoming
    
    public init() {}
    
    private var categorized: (
        watchNext: [LocalMediaItem],
        notWatched30Days: [LocalMediaItem],
        waitingForNewEpisodes: [LocalMediaItem],
        haveNotStarted: [LocalMediaItem]
    ) {
        WatchlistCategorizer.categorizeTVWatchlist(items: Array(dataManager.items.values))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Sub-Header Navigation Tabs
            Picker("TV Section", selection: $selectedTab) {
                Text("Watchlist").tag(0)
                Text("Upcoming Calendar").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color.black.opacity(0.4))
            
            if selectedTab == 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Sub-Section 1: Watch Next
                        SectionHeaderView(title: "Watch Next", count: categorized.watchNext.count, systemImage: "play.circle.fill", color: .blue)
                        MediaGridHorizontal(items: categorized.watchNext)
                        
                        // Sub-Section 2: Not Watched for 30+ Days
                        SectionHeaderView(title: "Not Watched for 30+ Days", count: categorized.notWatched30Days.count, systemImage: "clock.arrow.circlepath", color: .orange)
                        MediaGridHorizontal(items: categorized.notWatched30Days)
                        
                        // Sub-Section 3: Waiting for New Episodes
                        SectionHeaderView(title: "Waiting for New Episodes", count: categorized.waitingForNewEpisodes.count, systemImage: "hourglass", color: .purple)
                        MediaGridHorizontal(items: categorized.waitingForNewEpisodes)
                        
                        // Sub-Section 4: Have Not Started
                        SectionHeaderView(title: "Have Not Started", count: categorized.haveNotStarted.count, systemImage: "sparkles", color: .green)
                        MediaGridHorizontal(items: categorized.haveNotStarted)
                    }
                    .padding(.vertical)
                }
            } else {
                UpcomingCalendarView(watchlistItems: Array(dataManager.items.values).filter { $0.mediaType == "tv" && $0.isWatchlist })
            }
        }
    }
}

struct SectionHeaderView: View {
    let title: String
    let count: Int
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(color)
                .font(.title3)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text("(\(count))")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct MediaGridHorizontal: View {
    let items: [LocalMediaItem]
    
    var body: some View {
        if items.isEmpty {
            Text("No shows in this category.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(destination: TVShowDetailsView(show: TMDbMediaItem(
                            id: item.tmdbId,
                            title: nil,
                            name: item.title,
                            overview: nil,
                            posterPath: item.posterPath,
                            backdropPath: item.backdropPath,
                            voteAverage: item.voteAverage,
                            voteCount: nil,
                            releaseDate: nil,
                            firstAirDate: item.releaseDate,
                            mediaType: "tv",
                            genreIds: nil
                        ))) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    if let path = item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                                        AsyncImage(url: url) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: 140, height: 210)
                                        .cornerRadius(12)
                                        .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 140, height: 210)
                                            .cornerRadius(12)
                                    }
                                }
                                
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
