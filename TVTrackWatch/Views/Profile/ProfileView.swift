import SwiftUI
import UniformTypeIdentifiers

public struct ProfileView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var selectedFilter: ProfileFilter = .watchedMovies
    
    @State private var isCSVImporterPresented = false
    @State private var isImporting = false
    @State private var importProgressMessage = ""
    @State private var importCurrent = 0
    @State private var importTotal = 0
    @State private var importSummary: IMDbImportResult? = nil
    
    public enum ProfileFilter: String, CaseIterable, Identifiable {
        case watchedMovies = "Watched Movies"
        case watchedTV = "Watched TV Shows"
        case favoriteMovies = "Favorite Movies"
        case favoriteTV = "Favorite TV Shows"
        case stoppedWatching = "Stopped Watching Archive"
        
        public var id: String { rawValue }
        public var icon: String {
            switch self {
            case .watchedMovies: return "film.fill"
            case .watchedTV: return "tv.fill"
            case .favoriteMovies: return "heart.fill"
            case .favoriteTV: return "heart.circle.fill"
            case .stoppedWatching: return "archivebox.fill"
            }
        }
        public var color: Color {
            switch self {
            case .watchedMovies: return .blue
            case .watchedTV: return .green
            case .favoriteMovies: return .red
            case .favoriteTV: return .pink
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
    
    private var favoriteMovies: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "movie" && $0.isFavorite }
    }
    
    private var favoriteTV: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "tv" && $0.isFavorite }
    }
    
    private var stoppedWatchingArchive: [LocalMediaItem] {
        allItems.filter { $0.isStoppedWatching }
    }
    
    private var currentFilteredItems: [LocalMediaItem] {
        switch selectedFilter {
        case .watchedMovies: return watchedMovies
        case .watchedTV: return watchedTV
        case .favoriteMovies: return favoriteMovies
        case .favoriteTV: return favoriteTV
        case .stoppedWatching: return stoppedWatchingArchive
        }
    }
    
    private var stats: (topActors: [PersonStat], topDirectors: [PersonStat]) {
        WatchlistCategorizer.calculateTopStats(items: allItems, minThreshold: 1)
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
                        
                        Button(action: { isCSVImporterPresented = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("Import IMDb CSV")
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .shadow(color: .orange.opacity(0.4), radius: 6)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Dashboard Counters Grid (Clickable Category Filters)
                HStack(spacing: 12) {
                    CounterCardView(filter: .watchedMovies, count: watchedMovies.count, isSelected: selectedFilter == .watchedMovies) {
                        selectedFilter = .watchedMovies
                    }
                    CounterCardView(filter: .watchedTV, count: watchedTV.count, isSelected: selectedFilter == .watchedTV) {
                        selectedFilter = .watchedTV
                    }
                    CounterCardView(filter: .favoriteMovies, count: favoriteMovies.count, isSelected: selectedFilter == .favoriteMovies) {
                        selectedFilter = .favoriteMovies
                    }
                    CounterCardView(filter: .favoriteTV, count: favoriteTV.count, isSelected: selectedFilter == .favoriteTV) {
                        selectedFilter = .favoriteTV
                    }
                    CounterCardView(filter: .stoppedWatching, count: stoppedWatchingArchive.count, isSelected: selectedFilter == .stoppedWatching) {
                        selectedFilter = .stoppedWatching
                    }
                }
                .padding(.horizontal)
                
                // Cast & Director Stats
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
                                        ZStack(alignment: .topTrailing) {
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
                                            
                                            // User Rating Badge
                                            if let rating = item.userRating, rating > 0 {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "star.fill")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.yellow)
                                                    Text(String(format: "%.0f", rating))
                                                        .font(.caption2)
                                                        .fontWeight(.black)
                                                        .foregroundColor(.white)
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.black.opacity(0.85))
                                                .cornerRadius(6)
                                                .padding(6)
                                            }
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
        .fileImporter(
            isPresented: $isCSVImporterPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "csv") ?? .commaSeparatedText,
                .commaSeparatedText,
                .plainText,
                .data,
                .item,
                .content
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                var content = ""
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    content = text
                } else if let text = try? String(contentsOf: url, encoding: .ascii) {
                    content = text
                } else if let text = try? String(contentsOf: url, encoding: .isoLatin1) {
                    content = text
                } else if let text = try? String(contentsOf: url) {
                    content = text
                }
                
                if !content.isEmpty {
                    isImporting = true
                    Task {
                        let res = await IMDbCSVImporter.shared.importCSVData(content) { current, total, title in
                            DispatchQueue.main.async {
                                self.importCurrent = current
                                self.importTotal = total
                                self.importProgressMessage = "Importing (\(current)/\(total)): \(title)"
                            }
                        }
                        DispatchQueue.main.async {
                            self.importSummary = res
                        }
                    }
                }
            case .failure(let error):
                print("CSV Import error: \(error)")
            }
        }
        .sheet(isPresented: $isImporting) {
            VStack(spacing: 20) {
                if let summary = importSummary {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    
                    Text("IMDb Ratings Import Complete!")
                        .font(.title2)
                        .fontWeight(.black)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("🎬 Watched Movies:")
                            Spacer()
                            Text("\(summary.importedMovies)")
                                .fontWeight(.bold)
                        }
                        HStack {
                            Text("📺 Watched TV Shows:")
                            Spacer()
                            Text("\(summary.importedTVShows)")
                                .fontWeight(.bold)
                        }
                        if summary.failedCount > 0 {
                            HStack {
                                Text("⚠️ Unresolved Items:")
                                Spacer()
                                Text("\(summary.failedCount)")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    
                    Button("Done") {
                        self.isImporting = false
                        self.importSummary = nil
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                } else {
                    ProgressView()
                        .scaleEffect(1.4)
                    
                    Text(importProgressMessage.isEmpty ? "Preparing IMDb CSV..." : importProgressMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if importTotal > 0 {
                        ProgressView(value: Double(importCurrent), total: Double(importTotal))
                            .padding(.horizontal, 40)
                    }
                }
            }
            .padding(32)
            .background(Color.black.edgesIgnoringSafeArea(.all))
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
