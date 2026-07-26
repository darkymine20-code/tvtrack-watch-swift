import SwiftUI
import UniformTypeIdentifiers

public struct ProfileView: View {
    @ObservedObject var dataManager = DataManager.shared
    @State private var selectedFilter: ProfileFilter = .watchedMovies
    @State private var selectedSortOption: ProfileSortOption = .dateWatchedNewest
    @State private var displayLimit = 18
    
    @State private var isImportOptionsPresented = false
    @State private var isCSVImporterPresented = false
    @State private var isPasteSheetPresented = false
    @State private var pastedCSVText = ""
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
        case topCast = "Top Cast & Directors"
        case stoppedWatching = "Stopped Watching Archive"
        
        public var id: String { rawValue }
        public var icon: String {
            switch self {
            case .watchedMovies: return "film.fill"
            case .watchedTV: return "tv.fill"
            case .favoriteMovies: return "heart.fill"
            case .favoriteTV: return "star.fill"
            case .topCast: return "person.3.fill"
            case .stoppedWatching: return "archivebox.fill"
            }
        }
        public var color: Color {
            switch self {
            case .watchedMovies: return .blue
            case .watchedTV: return .green
            case .favoriteMovies: return .red
            case .favoriteTV: return .pink
            case .topCast: return .purple
            case .stoppedWatching: return .orange
            }
        }
        public var title: String { rawValue }
    }
    
    public enum ProfileSortOption: String, CaseIterable, Identifiable {
        case dateWatchedNewest = "Date Watched (Newest)"
        case dateWatchedOldest = "Date Watched (Oldest)"
        case userRatingHighest = "My Rating (Highest)"
        case userRatingLowest = "My Rating (Lowest)"
        case tmdbRating = "TMDb Rating (Highest)"
        case titleAZ = "Title (A-Z)"
        case releaseDate = "Release Date (Newest)"
        
        public var id: String { rawValue }
        public var icon: String {
            switch self {
            case .dateWatchedNewest, .dateWatchedOldest: return "calendar"
            case .userRatingHighest, .userRatingLowest: return "star.fill"
            case .tmdbRating: return "star.leadinghalf.filled"
            case .titleAZ: return "textformat"
            case .releaseDate: return "film"
            }
        }
    }
    
    public init() {}
    
    private var allItems: [LocalMediaItem] {
        Array(dataManager.items.values)
    }
    
    private var watchedMovies: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "movie" && $0.isWatched && !$0.isStoppedWatching }
    }
    
    private var watchedTV: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "tv" && $0.isWatched && !$0.isStoppedWatching }
    }
    
    private var favoriteMovies: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "movie" && $0.isFavorite && !$0.isStoppedWatching }
    }
    
    private var favoriteTV: [LocalMediaItem] {
        allItems.filter { $0.mediaType == "tv" && $0.isFavorite && !$0.isStoppedWatching }
    }
    
    private var stoppedWatchingArchive: [LocalMediaItem] {
        allItems.filter { $0.isStoppedWatching }
    }
    
    private var topCastCount: Int {
        stats.topActors.filter { $0.count >= 4 }.count + stats.topDirectors.filter { $0.count >= 4 }.count
    }
    
    private var currentFilteredItems: [LocalMediaItem] {
        switch selectedFilter {
        case .watchedMovies: return watchedMovies
        case .watchedTV: return watchedTV
        case .favoriteMovies: return favoriteMovies
        case .favoriteTV: return favoriteTV
        case .topCast: return []
        case .stoppedWatching: return stoppedWatchingArchive
        }
    }
    
    private var sortedFilteredItems: [LocalMediaItem] {
        let items = currentFilteredItems
        switch selectedSortOption {
        case .dateWatchedNewest:
            return items.sorted { ($0.lastWatchedDate ?? $0.addedToWatchlistDate) > ($1.lastWatchedDate ?? $1.addedToWatchlistDate) }
        case .dateWatchedOldest:
            return items.sorted { ($0.lastWatchedDate ?? $0.addedToWatchlistDate) < ($1.lastWatchedDate ?? $1.addedToWatchlistDate) }
        case .userRatingHighest:
            return items.sorted { ($0.userRating ?? 0) > ($1.userRating ?? 0) }
        case .userRatingLowest:
            return items.sorted { ($0.userRating ?? 0) < ($1.userRating ?? 0) }
        case .tmdbRating:
            return items.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        case .titleAZ:
            return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .releaseDate:
            return items.sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
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
    
    @ViewBuilder
    private var activeFilterContentView: some View {
        if selectedFilter == .topCast {
            TopStatsView(topActors: stats.topActors, topDirectors: stats.topDirectors)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: selectedFilter.icon)
                        .foregroundColor(selectedFilter.color)
                        .font(.title2)
                    Text("\(selectedFilter.rawValue) (\(sortedFilteredItems.count))")
                        .font(.title2).fontWeight(.black)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(ProfileSortOption.allCases) { option in
                            Button(action: {
                                selectedSortOption = option
                                displayLimit = 18
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if selectedSortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text("Sort: \(selectedSortOption.rawValue)")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal)
                
                if sortedFilteredItems.isEmpty {
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
                    let visibleItems = Array(sortedFilteredItems.prefix(displayLimit))
                    
                    VStack(spacing: 16) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 20) {
                            ForEach(visibleItems) { item in
                                NavigationLink(destination: detailsView(for: item)) {
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
                                .onAppear {
                                    if item.id == visibleItems.last?.id && displayLimit < sortedFilteredItems.count {
                                        displayLimit += 18
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        if displayLimit < sortedFilteredItems.count {
                            Button(action: { displayLimit += 18 }) {
                                HStack {
                                    Text("Showing \(visibleItems.count) of \(sortedFilteredItems.count) items — Tap or Scroll to load more")
                                    Image(systemName: "chevron.down")
                                }
                                .font(.caption).fontWeight(.bold)
                                .foregroundColor(.blue)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
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
                
                // Dashboard Counters Grid (Clickable Category Filters)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    CounterCardView(filter: .watchedMovies, count: watchedMovies.count, isSelected: selectedFilter == .watchedMovies) {
                        selectedFilter = .watchedMovies
                        displayLimit = 18
                    }
                    CounterCardView(filter: .watchedTV, count: watchedTV.count, isSelected: selectedFilter == .watchedTV) {
                        selectedFilter = .watchedTV
                        displayLimit = 18
                    }
                    CounterCardView(filter: .favoriteMovies, count: favoriteMovies.count, isSelected: selectedFilter == .favoriteMovies) {
                        selectedFilter = .favoriteMovies
                        displayLimit = 18
                    }
                    CounterCardView(filter: .favoriteTV, count: favoriteTV.count, isSelected: selectedFilter == .favoriteTV) {
                        selectedFilter = .favoriteTV
                        displayLimit = 18
                    }
                    CounterCardView(filter: .topCast, count: topCastCount, isSelected: selectedFilter == .topCast) {
                        selectedFilter = .topCast
                        displayLimit = 18
                    }
                    CounterCardView(filter: .stoppedWatching, count: stoppedWatchingArchive.count, isSelected: selectedFilter == .stoppedWatching) {
                        selectedFilter = .stoppedWatching
                        displayLimit = 18
                    }
                }
                .padding(.horizontal)
                
                // Active Selected Category View
                activeFilterContentView
            }
            .padding(.vertical)
        }
        .fileImporter(
            isPresented: $isCSVImporterPresented,
            allowedContentTypes: [.item, .content, .data, .plainText, .commaSeparatedText],
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
                } else if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                    content = text
                }
                
                if !content.isEmpty {
                    self.isImporting = true
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
        .task {
            dataManager.fetchMissingCreditsForWatchedItems()
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
