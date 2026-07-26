import SwiftUI

public struct MoviesWatchlistView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var isGridView = true
    
    public init() {}
    
    private var movieItems: [LocalMediaItem] {
        dataManager.items.values.filter { $0.mediaType == "movie" && $0.isWatchlist && !$0.isStoppedWatching }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 20)
    ]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Grid/List Toggle
            HStack {
                Text("Movies Watchlist")
                    .font(.title2).fontWeight(.bold)
                Spacer()
                Button(action: { isGridView.toggle() }) {
                    Image(systemName: isGridView ? "list.bullet" : "squareshape.split.3x3")
                        .font(.title2)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.black.opacity(0.4))
            
            if movieItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Your Movies Watchlist is empty.")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if isGridView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(movieItems) { item in
                                MovieCardView(item: item)
                            }
                        }
                        .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(movieItems) { item in
                                MovieRowView(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            dataManager.fetchMissingCreditsForWatchedItems()
        }
    }
}

struct MovieCardView: View {
    let item: LocalMediaItem
    
    var body: some View {
        NavigationLink(destination: MovieDetailsView(movie: TMDbMediaItem(
            id: item.tmdbId,
            title: item.title,
            name: nil,
            overview: nil,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            voteAverage: item.voteAverage,
            voteCount: nil,
            releaseDate: item.releaseDate,
            firstAirDate: nil,
            mediaType: "movie",
            genreIds: nil
        ))) {
            VStack(alignment: .leading, spacing: 8) {
                if let path = item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 240)
                    .cornerRadius(12)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 240)
                        .cornerRadius(12)
                }
                
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.white)
            }
        }
    }
}

struct MovieRowView: View {
    let item: LocalMediaItem
    
    var body: some View {
        NavigationLink(destination: MovieDetailsView(movie: TMDbMediaItem(
            id: item.tmdbId,
            title: item.title,
            name: nil,
            overview: nil,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            voteAverage: item.voteAverage,
            voteCount: nil,
            releaseDate: item.releaseDate,
            firstAirDate: nil,
            mediaType: "movie",
            genreIds: nil
        ))) {
            GlassCardView {
                HStack(spacing: 16) {
                    if let path = item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 70, height: 105)
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        if let year = item.releaseDate {
                            Text(year)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        if let rating = item.voteAverage {
                            Text("★ \(String(format: "%.1f", rating))/10")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}
