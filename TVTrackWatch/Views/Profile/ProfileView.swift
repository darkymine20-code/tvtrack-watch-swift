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
        public var title: String { rawValue }
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
    
    @ViewBuilder
    private func detailsView(for item: LocalMediaItem) -> some View {
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
                        
                        Button(action: { isImportOptionsPresented = true }) {
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
                            .shadow(color: .orange.opacity(0.4), radius: 4)
                        }
                        .confirmationDialog("Import IMDb Data", isPresented: $isImportOptionsPresented, titleVisibility: .visible) {
                            Button("📁 Choose CSV File from Files App") {
                                isCSVImporterPresented = true
                            }
                            Button("📋 Paste CSV Text from Clipboard") {
                                pastedCSVText = UIPasteboard.general.string ?? ""
                                isPasteSheetPresented = true
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Dashboard Overview
                VStack(alignment: .leading, spacing: 20) {
                    Text("Dashboard Overview")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ProfileStatCard(title: "Watched Movies", count: watchedMovies.count, icon: "film.fill", color: .purple, isSelected: selectedFilter == .watchedMovies) {
                            selectedFilter = .watchedMovies
                        }
                        
                        ProfileStatCard(title: "Watched TV Shows", count: watchedTV.count, icon: "tv.fill", color: .blue, isSelected: selectedFilter == .watchedTV) {
                            selectedFilter = .watchedTV
                        }
                        
                        ProfileStatCard(title: "Favorite Movies", count: favoriteMovies.count, icon: "heart.fill", color: .pink, isSelected: selectedFilter == .favoriteMovies) {
                            selectedFilter = .favoriteMovies
                        }
                        
                        ProfileStatCard(title: "Favorite TV Shows", count: favoriteTV.count, icon: "star.fill", color: .yellow, isSelected: selectedFilter == .favoriteTV) {
                            selectedFilter = .favoriteTV
                        }
                    }
                    .padding(.horizontal)
                    
                    // Stopped Watching Filter Card
                    GlassCardView {
                        HStack {
                            Image(systemName: "hand.raised.slash.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                            Text("Stopped Watching Archive")
                                .font(.headline)
                            Spacer()
                            Text("\(stoppedWatchingArchive.count) items")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFilter = .stoppedWatching
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Actor & Director Stats Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cast & Crew Breakdown")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    HStack(alignment: .top, spacing: 20) {
                        // Top Actors
                        GlassCardView {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "person.3.fill")
                                        .foregroundColor(.cyan)
                                    Text("Top Actors")
                                        .font(.headline)
                                }
                                Divider()
                                if stats.topActors.isEmpty {
                                    Text("No actor stats available yet. View movie details to track top cast!")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    ForEach(stats.topActors) { actor in
                                        HStack {
                                            Text(actor.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text("\(actor.count) watched")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.cyan.opacity(0.2))
                                                .foregroundColor(.cyan)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Top Directors
                        GlassCardView {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.orange)
                                    Text("Top Directors")
                                        .font(.headline)
                                }
                                Divider()
                                if stats.topDirectors.isEmpty {
                                    Text("No director stats available yet. View movie details to track directors!")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    ForEach(stats.topDirectors) { director in
                                        HStack {
                                            Text(director.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text("\(director.count) watched")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Filtered List View
                VStack(alignment: .leading, spacing: 16) {
                    Text(selectedFilter.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    if currentFilteredItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No items found in this section")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 16)], spacing: 16) {
                            ForEach(currentFilteredItems) { item in
                                NavigationLink(destination: detailsView(for: item)) {
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
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.yellow)
                                            .cornerRadius(8)
                                            .padding(6)
                                        }
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
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                
                var content = ""
                if let text = try? String(contentsOf: url, encoding: .utf8) { content = text }
                else if let text = try? String(contentsOf: url, encoding: .ascii) { content = text }
                
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
                        DispatchQueue.main.async { self.importSummary = res }
                    }
                }
            case .failure(let error):
                print("CSV Import error: \(error)")
            }
        }
        .sheet(isPresented: $isPasteSheetPresented) {
            NavigationView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste the content of your IMDb ratings.csv or watchlist.csv file below:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button(action: {
                            if let clip = UIPasteboard.general.string { pastedCSVText = clip }
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard.fill")
                                Text("Paste from Clipboard")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        Spacer()
                        if !pastedCSVText.isEmpty {
                            Button("Clear") { pastedCSVText = "" }
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    TextEditor(text: $pastedCSVText)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    
                    Button(action: {
                        let contentToImport = pastedCSVText
                        isPasteSheetPresented = false
                        pastedCSVText = ""
                        isImporting = true
                        Task {
                            let res = await IMDbCSVImporter.shared.importCSVData(contentToImport) { current, total, title in
                                DispatchQueue.main.async {
                                    self.importCurrent = current
                                    self.importTotal = total
                                    self.importProgressMessage = "Importing (\(current)/\(total)): \(title)"
                                }
                            }
                            DispatchQueue.main.async { self.importSummary = res }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Start Importing CSV Data")
                        }
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .disabled(pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .navigationTitle("Import IMDb CSV Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isPasteSheetPresented = false }
                    }
                }
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
