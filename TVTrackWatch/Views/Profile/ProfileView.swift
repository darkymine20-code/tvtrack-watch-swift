import SwiftUI

public struct ProfileView: View {
    @ObservedObject var dataManager = DataManager.shared
    
    public init() {}
    
    private var allItems: [LocalMediaItem] {
        Array(dataManager.items.values)
    }
    
    private var watchedMovies: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "movie" && $0.isWatched }
    }
    
    private var watchedTV: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "tv" && $0.isWatched }
    }
    
    private var favoriteMovies: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "movie" && $0.isFavorite }
    }
    
    private var favoriteTV: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "tv" && $0.isFavorite }
    }
    
    private var stoppedWatchingArchive: [LocalMediaItem] {
        allItems.filter { $0.isStoppedWatching }
    }
    
    private var stats: (topActors: [PersonStat], topDirectors: [PersonStat]) {
        WatchlistCategorizer.calculateTopStats(items: allItems, minThreshold: 4)
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header User Summary
                GlassCardView {
                    HStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iPadOS Local Profile")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("tvtrack+ watch Local User Dashboard")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Dashboard Counters Grid
                HStack(spacing: 16) {
                    CounterCardView(title: "Watched Movies", count: watchedMovies.count, icon: "film", color: .blue)
                    CounterCardView(title: "Watched TV Shows", count: watchedTV.count, icon: "tv", color: .green)
                    CounterCardView(title: "Favorites", count: favoriteMovies.count + favoriteTV.count, icon: "heart.fill", color: .red)
                    CounterCardView(title: "Stopped Watching", count: stoppedWatchingArchive.count, icon: "archivebox.fill", color: .orange)
                }
                .padding(.horizontal)
                
                // Cast & Director Stats (Threshold >= 4)
                TopStatsView(topActors: stats.topActors, topDirectors: stats.topDirectors)
                
                // Favorites Collection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Favorite Movies & Shows")
                        .font(.title2).fontWeight(.bold)
                        .padding(.horizontal)
                    
                    if favoriteMovies.isEmpty && favoriteTV.isEmpty {
                        Text("No favorites added yet.")
                            .font(.subheadline).foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        ProfileMediaRow(items: favoriteMovies + favoriteTV)
                    }
                }
                
                // "Stopped Watching" Archive Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.orange)
                        Text("\"Stopped Watching\" Archive")
                            .font(.title2).fontWeight(.bold)
                    }
                    .padding(.horizontal)
                    
                    if stoppedWatchingArchive.isEmpty {
                        Text("Archive is empty.")
                            .font(.subheadline).foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        ProfileMediaRow(items: stoppedWatchingArchive)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct CounterCardView: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        GlassCardView {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.system(size: 28, weight: .bold))
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ProfileMediaRow: View {
    let items: [LocalMediaItem]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        if let path = item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                            AsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 120, height: 180)
                            .cornerRadius(10)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 180)
                                .cornerRadius(10)
                        }
                        
                        Text(item.title)
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(width: 120, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
