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
                    VStack(alignment: .leading, spacing: 26) {
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
                .fontWeight(.black)
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
            Text("No shows in this section.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(items) { item in
                        TVShowPosterCard(item: item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// Fix 2: TV Show Poster Card with Watched Episode Progressive Bar
struct TVShowPosterCard: View {
    let item: LocalMediaItem
    
    private var watchedCount: Int {
        item.watchedEpisodes.count
    }
    
    private var totalEpisodesCount: Int {
        if let released = item.releasedEpisodes, released > 0 {
            return max(watchedCount, released)
        }
        if let total = item.totalEpisodes, total > 0 {
            return max(watchedCount, total)
        }
        return max(watchedCount, 1)
    }
    
    private var progressRatio: Double {
        min(Double(watchedCount) / Double(totalEpisodesCount), 1.0)
    }
    
    var body: some View {
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
                ZStack(alignment: .bottom) {
                    if let path = item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 145, height: 215)
                        .cornerRadius(14)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 145, height: 215)
                            .cornerRadius(14)
                    }
                    
                    // Watched Episode Counter Pill Badge
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(watchedCount)/\(totalEpisodesCount) Ep")
                                .font(.caption2)
                                .fontWeight(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.8))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green.opacity(0.4), lineWidth: 1))
                                .padding(6)
                        }
                        Spacer()
                    }
                    
                    // Progressive Watched Bar at Poster Bottom Edge
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(height: 6)
                                
                                Rectangle()
                                    .fill(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(progressRatio), height: 6)
                                    .shadow(color: .green.opacity(0.6), radius: 4)
                            }
                            .cornerRadius(3)
                        }
                    }
                    .frame(height: 215)
                }
                
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 145, alignment: .leading)
            }
        }
    }
}
