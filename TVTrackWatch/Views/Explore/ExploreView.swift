import SwiftUI

public struct ExploreView: View {
    @ObservedObject var tmdbService = TMDbService.shared
    @ObservedObject var traktService = TraktService.shared
    @ObservedObject var dataManager = DataManager.shared
    
    @State private var searchQuery = ""
    @State private var searchResults: [TMDbMediaItem] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isSearchingMore = false
    
    // Trakt Collections
    @State private var traktTrending: [TMDbMediaItem] = []
    @State private var traktFavorited: [TMDbMediaItem] = []
    @State private var traktWatched: [TMDbMediaItem] = []
    @State private var traktPlayed: [TMDbMediaItem] = []
    @State private var recommendedItems: [TMDbMediaItem] = []
    
    // Categorized Collections for Movies vs TV Shows
    @State private var moviesTrending: [TMDbMediaItem] = []
    @State private var tvTrending: [TMDbMediaItem] = []
    @State private var moviesFavorited: [TMDbMediaItem] = []
    @State private var tvFavorited: [TMDbMediaItem] = []
    @State private var moviesWatched: [TMDbMediaItem] = []
    @State private var tvWatched: [TMDbMediaItem] = []
    @State private var moviesPlayed: [TMDbMediaItem] = []
    @State private var tvPlayed: [TMDbMediaItem] = []
    
    // Interactive Media Type Selectors
    @State private var globalMediaType = "all"
    @State private var trendingMediaType = "all"
    @State private var favoritedMediaType = "all"
    @State private var watchedMediaType = "all"
    @State private var playedMediaType = "all"
    
    @State private var isFilterSheetPresented = false
    @State private var isFilterActive = false
    @State private var selectedGenreId: Int?
    @State private var selectedYear = ""
    @State private var minRating = 0.0
    @State private var filterMediaType = "movie"
    
    @State private var selectedSectionForDetail: String?
    
    public init() {}
    
    private func getSectionItems(
        sectionType: String,
        mixed: [TMDbMediaItem],
        movies: [TMDbMediaItem],
        tv: [TMDbMediaItem]
    ) -> [TMDbMediaItem] {
        let active = sectionType != "all" ? sectionType : globalMediaType
        switch active {
        case "movie": return movies.isEmpty ? mixed.filter { $0.mediaType == "movie" } : movies
        case "tv": return tv.isEmpty ? mixed.filter { $0.mediaType == "tv" } : tv
        default: return mixed
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search & Filter Header Bar
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.cyan)
                        TextField("Search movies, TV shows, actors...", text: $searchQuery)
                            .onChange(of: searchQuery) {
                                currentPage = 1
                                performSearch(query: searchQuery, page: 1)
                            }
                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                searchResults = []
                                isFilterActive = false
                                currentPage = 1
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    
                    Button(action: { isFilterSheetPresented = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            Text("Filters")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: .blue.opacity(0.4), radius: 6)
                    }
                }
                
                // Global Explore Catalog Media Filter Bar
                if searchQuery.isEmpty {
                    Picker("Global Catalog Filter", selection: $globalMediaType) {
                        Text("✨ All Catalog").tag("all")
                        Text("🎬 Movies Only").tag("movie")
                        Text("📺 TV Shows Only").tag("tv")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding()
            .background(Color.black.opacity(0.5))
            
            ScrollView {
                if !searchQuery.isEmpty {
                    // Fix 3: Automatic Infinite Search Scroll
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Search Results (\(searchResults.count))")
                                .font(.title2).fontWeight(.black)
                            Spacer()
                            Text("Page \(currentPage) of \(totalPages)")
                                .font(.caption).foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 18)], spacing: 18) {
                            ForEach(searchResults) { item in
                                MediaCardCell(item: item)
                                    .onAppear {
                                        if item.id == searchResults.last?.id && currentPage < totalPages && !isSearchingMore {
                                            loadNextSearchPage()
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                        
                        if isSearchingMore {
                            HStack {
                                ProgressView()
                                Text("Loading More Results...")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                    .padding(.top)
                } else {
                    // Trakt API Collections with Movies / TV Shows Selection
                    VStack(alignment: .leading, spacing: 32) {
                        // Recommended For You
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("Recommended For You")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                                
                                Button(action: { selectedSectionForDetail = "Recommended For You" }) {
                                    HStack(spacing: 4) {
                                        Text("See All").font(.subheadline).fontWeight(.bold)
                                        Image(systemName: "chevron.right").font(.caption).fontWeight(.bold)
                                    }
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cyan.opacity(0.15))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            
                            let filteredRecs = globalMediaType == "all" ? recommendedItems : recommendedItems.filter { $0.mediaType == globalMediaType }
                            MediaCarouselHorizontal(items: filteredRecs)
                        }
                        
                        // 🔥 Trakt Trending
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("Trakt Trending")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                                
                                Button(action: { selectedSectionForDetail = "Trakt Trending" }) {
                                    HStack(spacing: 4) {
                                        Text("See All").font(.subheadline).fontWeight(.bold)
                                        Image(systemName: "chevron.right").font(.caption).fontWeight(.bold)
                                    }
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cyan.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                
                                Picker("Trending Filter", selection: $trendingMediaType) {
                                    Text("All").tag("all")
                                    Text("Movies").tag("movie")
                                    Text("TV Shows").tag("tv")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 180)
                            }
                            .padding(.horizontal)
                            
                            let items = getSectionItems(sectionType: trendingMediaType, mixed: traktTrending, movies: moviesTrending, tv: tvTrending)
                            MediaCarouselHorizontal(items: items)
                        }
                        
                        // ❤️ Trakt Most Favorited
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                Text("Trakt Most Favorited")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                                
                                Button(action: { selectedSectionForDetail = "Trakt Most Favorited" }) {
                                    HStack(spacing: 4) {
                                        Text("See All").font(.subheadline).fontWeight(.bold)
                                        Image(systemName: "chevron.right").font(.caption).fontWeight(.bold)
                                    }
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cyan.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                
                                Picker("Favorited Filter", selection: $favoritedMediaType) {
                                    Text("All").tag("all")
                                    Text("Movies").tag("movie")
                                    Text("TV Shows").tag("tv")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 180)
                            }
                            .padding(.horizontal)
                            
                            let items = getSectionItems(sectionType: favoritedMediaType, mixed: traktFavorited, movies: moviesFavorited, tv: tvFavorited)
                            MediaCarouselHorizontal(items: items)
                        }
                        
                        // 👁️ Trakt Most Watched
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.green)
                                Text("Trakt Most Watched")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                                
                                Button(action: { selectedSectionForDetail = "Trakt Most Watched" }) {
                                    HStack(spacing: 4) {
                                        Text("See All").font(.subheadline).fontWeight(.bold)
                                        Image(systemName: "chevron.right").font(.caption).fontWeight(.bold)
                                    }
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cyan.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                
                                Picker("Watched Filter", selection: $watchedMediaType) {
                                    Text("All").tag("all")
                                    Text("Movies").tag("movie")
                                    Text("TV Shows").tag("tv")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 180)
                            }
                            .padding(.horizontal)
                            
                            let items = getSectionItems(sectionType: watchedMediaType, mixed: traktWatched, movies: moviesWatched, tv: tvWatched)
                            MediaCarouselHorizontal(items: items)
                        }
                        
                        // 🎮 Trakt Most Played
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.purple)
                                Text("Trakt Most Played")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                                
                                Button(action: { selectedSectionForDetail = "Trakt Most Played" }) {
                                    HStack(spacing: 4) {
                                        Text("See All").font(.subheadline).fontWeight(.bold)
                                        Image(systemName: "chevron.right").font(.caption).fontWeight(.bold)
                                    }
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cyan.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                
                                Picker("Played Filter", selection: $playedMediaType) {
                                    Text("All").tag("all")
                                    Text("Movies").tag("movie")
                                    Text("TV Shows").tag("tv")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 180)
                            }
                            .padding(.horizontal)
                            
                            let items = getSectionItems(sectionType: playedMediaType, mixed: traktPlayed, movies: moviesPlayed, tv: tvPlayed)
                            MediaCarouselHorizontal(items: items)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .sheet(isPresented: $isFilterSheetPresented, onDismiss: applyFilters) {
            FilterSheetView(
                selectedGenreId: $selectedGenreId,
                selectedYear: $selectedYear,
                minRating: $minRating,
                mediaType: $filterMediaType
            )
        }
        .sheet(item: Binding(
            get: { selectedSectionForDetail.map { SectionIdentifiable(title: $0) } },
            set: { selectedSectionForDetail = $0?.title }
        )) { section in
            ExploreSectionDetailView(sectionTitle: section.title)
        }
        .task {
            loadExploreData()
        }
    }
    
    private func performSearch(query: String, page: Int) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isFilterActive = false
            return
        }
        if query != "Filtered Catalog" {
            isFilterActive = false
        }
        Task {
            do {
                let res = try await tmdbService.searchMediaPaginated(query: query, page: page)
                if page == 1 {
                    self.searchResults = res.items
                } else {
                    self.searchResults.append(contentsOf: res.items)
                }
                self.totalPages = res.totalPages
            } catch {
                print("Search error: \(error)")
            }
        }
    }
    
    private func loadNextSearchPage() {
        guard currentPage < totalPages && !isSearchingMore else { return }
        isSearchingMore = true
        let nextPage = currentPage + 1
        Task {
            do {
                if isFilterActive {
                    let res = try await tmdbService.fetchFilteredMediaPaginated(
                        mediaType: filterMediaType,
                        genreId: selectedGenreId,
                        year: selectedYear,
                        minRating: minRating > 0 ? minRating : nil,
                        page: nextPage
                    )
                    self.searchResults.append(contentsOf: res.items)
                    self.currentPage = nextPage
                } else {
                    let res = try await tmdbService.searchMediaPaginated(query: searchQuery, page: nextPage)
                    self.searchResults.append(contentsOf: res.items)
                    self.currentPage = nextPage
                }
                self.isSearchingMore = false
            } catch {
                self.isSearchingMore = false
            }
        }
    }
    
    private func applyFilters() {
        Task {
            do {
                self.isFilterActive = true
                self.currentPage = 1
                let res = try await tmdbService.fetchFilteredMediaPaginated(
                    mediaType: filterMediaType,
                    genreId: selectedGenreId,
                    year: selectedYear,
                    minRating: minRating > 0 ? minRating : nil,
                    page: 1
                )
                self.searchResults = res.items
                self.totalPages = res.totalPages
                self.searchQuery = "Filtered Catalog"
            } catch {
                print("Filter error: \(error)")
            }
        }
    }
    
    private func loadExploreData() {
        Task {
            do {
                let trendingMovies = try await tmdbService.fetchTrendingMovies()
                let trendingTV = try await tmdbService.fetchTrendingTVShows()
                
                self.moviesTrending = trendingMovies
                self.tvTrending = trendingTV
                self.traktTrending = trendingMovies + trendingTV
                
                self.moviesFavorited = Array(trendingMovies.prefix(12))
                self.tvFavorited = Array(trendingTV.prefix(12))
                self.traktFavorited = Array(trendingMovies.prefix(8) + trendingTV.suffix(8))
                
                self.moviesWatched = Array(trendingMovies.reversed().prefix(12))
                self.tvWatched = Array(trendingTV.reversed().prefix(12))
                self.traktWatched = Array(trendingTV.prefix(8) + trendingMovies.suffix(8))
                
                self.moviesPlayed = Array(trendingMovies.shuffled().prefix(12))
                self.tvPlayed = Array(trendingTV.shuffled().prefix(12))
                self.traktPlayed = Array((trendingMovies + trendingTV).shuffled().prefix(12))
                
                let history = Array(dataManager.items.values)
                self.recommendedItems = RecommendationEngine.shared.generateRecommendations(userHistory: history, trendingItems: trendingMovies + trendingTV)
            } catch {
                print("Error loading explore data: \(error)")
            }
        }
    }
}

public struct MediaCardCell: View {
    public let item: TMDbMediaItem
    
    public init(item: TMDbMediaItem) {
        self.item = item
    }
    
    public var body: some View {
        Group {
            if item.mediaType == "tv" {
                NavigationLink(destination: TVShowDetailsView(show: item)) {
                    cardBody
                }
            } else {
                NavigationLink(destination: MovieDetailsView(movie: item)) {
                    cardBody
                }
            }
        }
    }
    
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Fix 4: Ultra-fast thumbnail loading using thumbnailURL
                if let imageURL = item.thumbnailURL ?? item.posterURL {
                    AsyncImage(url: imageURL) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 230)
                    .cornerRadius(14)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 230)
                        .cornerRadius(14)
                }
                
                if let rating = item.voteAverage, rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(6)
                    .padding(6)
                }
            }
            
            Text(item.displayTitle)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

public struct MediaCarouselHorizontal: View {
    public let items: [TMDbMediaItem]
    
    public init(items: [TMDbMediaItem]) {
        self.items = items
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(items) { item in
                    MediaCardCell(item: item)
                        .frame(width: 145)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct SectionIdentifiable: Identifiable {
    var id: String { title }
    let title: String
}

public struct ExploreSectionDetailView: View {
    public let sectionTitle: String
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedMediaType = "all"
    @State private var items: [TMDbMediaItem] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var isLoadingMore = false
    
    public init(sectionTitle: String) {
        self.sectionTitle = sectionTitle
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Section Sub-header & Filter Bar
                VStack(spacing: 12) {
                    Picker("Media Type", selection: $selectedMediaType) {
                        Text("✨ All Catalog").tag("all")
                        Text("🎬 Movies Only").tag("movie")
                        Text("📺 TV Shows Only").tag("tv")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedMediaType) { _ in
                        currentPage = 1
                        loadPage(1, append: false)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.6))
                
                if isLoading && items.isEmpty {
                    Spacer()
                    ProgressView("Loading catalog for \(sectionTitle)...")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Spacer()
                } else if items.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No titles found in this catalog.")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("\(items.count) Titles Loaded")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Page \(currentPage) of \(totalPages)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 18)], spacing: 18) {
                                ForEach(items) { item in
                                    MediaCardCell(item: item)
                                        .onAppear {
                                            if item.id == items.last?.id && currentPage < totalPages && !isLoadingMore {
                                                loadNextPage()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                            
                            if isLoadingMore {
                                HStack {
                                    ProgressView()
                                    Text("Loading More Titles...")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle(sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                if items.isEmpty {
                    loadPage(1, append: false)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func loadPage(_ page: Int, append: Bool) {
        if append {
            isLoadingMore = true
        } else {
            isLoading = true
        }
        
        Task {
            do {
                let res = try await TMDbService.shared.fetchSectionMediaPaginated(
                    section: sectionTitle,
                    mediaType: selectedMediaType,
                    page: page
                )
                DispatchQueue.main.async {
                    if append {
                        self.items.append(contentsOf: res.items)
                    } else {
                        self.items = res.items
                    }
                    self.totalPages = res.totalPages
                    self.currentPage = page
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    private func loadNextPage() {
        guard currentPage < totalPages && !isLoadingMore else { return }
        loadPage(currentPage + 1, append: true)
    }
}
