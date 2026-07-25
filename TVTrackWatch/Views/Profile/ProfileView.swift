import SwiftUI

public struct ProfileView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var selectedFilter: ProfileFilter = .watchedMovies
    
    public enum ProfileFilter: String, CaseIterable, Identifiable {
        case watchedMovies = "Watched Movies"
        case watchedTV = "Watched TV Shows"
        case favorites = "Favorites"
        case stoppedWatching = "Stopped Watching Archive"
        
        public var id: String { rawValue }
        public var icon: String {
            switch self {
            case .watchedMovies: return "film.fill"
            case .watchedTV: return "tv.fill"
            case .favorites: return "heart.fill"
            case .stoppedWatching: return "archivebox.fill"
            }
        }
        public var color: Color {
            switch self {
            case .watchedMovies: return .blue
            case .watchedTV: return .green
            case .favorites: return .red
            case .stoppedWatching: return .orange
            }
        }
    }
    
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
    
    private var favorites: [LocalMediaItem] {
        allItems.filter { $0.isFavorite }
    }
    
    private var stoppedWatchingArchive: [LocalMediaItem] {
        allItems.filter { $0.isStoppedWatching }
    }
    
    private var currentFilteredItems: [LocalMediaItem] {
        switch selectedFilter {
        case .watchedMovies: return watchedMovies
        case .watchedTV: return watchedTV
        case .favorites: return favorites
        case .stoppedWatching: return stoppedWatchingArchive
        }
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
                            .font(.system(size: 68))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iPadOS Local Profile")
                                .font(.title)
                                .fontWeight(.black)
                            Text("tvtrack+ watch Activity Dashboard")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Dashboard Counters Grid (Clickable Category Filters)
                HStack(spacing: 16) {
                    CounterCardView(filter: .watchedMovies, count: watchedMovies.count, isSelected: selectedFilter == .watchedMovies) {
                        selectedFilter = .watchedMovies
                    }
                    CounterCardView(filter: .watchedTV, count: watchedTV.count, isSelected: selectedFilter == .watchedTV) {
                        selectedFilter = .watchedTV
                    }
                    CounterCardView(filter: .favorites, count: favorites.count, isSelected: selectedFilter == .favorites) {
                        selectedFilter = .favorites
                    }
                    CounterCardView(filter: .stoppedWatching, count: stoppedWatchingArchive.count, isSelected: selectedFilter == .stoppedWatching) {
                        selectedFilter = .stoppedWatching
                    }
                }
                .padding(.horizontal)
                
                // Cast & Director Stats (Threshold >= 4)
                TopStatsView(topActors: stats.topActors, topDirectors: stats.topDirectors)
                
                // Active Selected Category Collection Grid
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: selectedFilter.icon)
                            .foregroundColor(selectedFilter.color)
                            .font(.title2)
                        Text("\(selectedFilter.rawValue) (\(currentFilteredItems.count))")
                            .font(.title2).fontWeight(.black)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    if currentFilteredItems.isEmpty {
                        GlassCardView {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.largeTitle).foregroundColor(.gray)
                                Text("No items in \(selectedFilter.rawValue).")
                                    .font(.headline).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 20) {
                            ForEach(currentFilteredItems) { item in
                                NavigationLink(destination: Group {
                                    if item.mediaType == "tv" {
                                        TVShowDetailsView(show: TMDbMediaItem(
                                            id: item.tmdbId, title: nil, name: item.title, overview: nil,
                                            posterPath: item.posterPath, backdropPath: item.backdropPath,
                                            voteAverage: item.voteAverage, voteCount: nil, releaseDate: nil,
                                            firstAirDate: item.releaseDate, mediaType: "tv", genreIds: nil
                                        ))
                                    } else {
                                        MovieDetailsView(movie: TMDbMediaItem(
                                            id: item.tmdbId, title: item.title, name: nil, overview: nil,
                                            posterPath: item.posterPath, backdropPath: item.backdropPath,
                                            voteAverage: item.voteAverage, voteCount: nil, releaseDate: item.releaseDate,
                                            firstAirDate: nil, mediaType: "movie", genreIds: nil
                                        ))
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let path = item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                                            AsyncImage(url: url) { img in
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Rectangle().fill(Color.gray.opacity(0.3))
                                            }
                                            .frame(height: 220)
                                            .cornerRadius(12)
                                            .clipped()
                                        } else {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(height: 220)
                                                .cornerRadius(12)
                                        }
                                        
                                        Text(item.title)
                                            .font(.caption).fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

public struct CounterCardView: View {
    public let filter: ProfileView.ProfileFilter
    public let count: Int
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(filter: ProfileView.ProfileFilter, count: Int, isSelected: Bool, action: @escaping () -> Void) {
        self.filter = filter
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            GlassCardView {
                VStack(spacing: 8) {
                    Image(systemName: filter.icon)
                        .font(.title)
                        .foregroundColor(filter.color)
                    Text("\(count)")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.white)
                    Text(filter.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? filter.color : .secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? filter.color : Color.clear, lineWidth: 2.5)
            )
        }
    }
}
