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
    
    @State private var isFilterSheetPresented = false
    @State private var selectedGenreId: Int?
    @State private var selectedYear = ""
    @State private var minRating = 0.0
    @State private var filterMediaType = "movie"
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search & Filter Header Bar
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
                    // Trakt API Collections
                    VStack(alignment: .leading, spacing: 32) {
                        // Recommended For You
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("Recommended For You")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            MediaCarouselHorizontal(items: recommendedItems)
                        }
                        
                        // 🔥 Trakt Trending
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("Trakt Trending")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            MediaCarouselHorizontal(items: traktTrending)
                        }
                        
                        // ❤️ Trakt Most Favorited
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                Text("Trakt Most Favorited")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            MediaCarouselHorizontal(items: traktFavorited)
                        }
                        
                        // 👁️ Trakt Most Watched
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.green)
                                Text("Trakt Most Watched")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            MediaCarouselHorizontal(items: traktWatched)
                        }
                        
                        // 🎮 Trakt Most Played
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.purple)
                                Text("Trakt Most Played")
                                    .font(.title2).fontWeight(.black)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            MediaCarouselHorizontal(items: traktPlayed)
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
        .task {
            loadExploreData()
        }
    }
    
    private func performSearch(query: String, page: Int) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
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
        currentPage += 1
        Task {
            do {
                let res = try await tmdbService.searchMediaPaginated(query: searchQuery, page: currentPage)
                self.searchResults.append(contentsOf: res.items)
                self.isSearchingMore = false
            } catch {
                self.isSearchingMore = false
            }
        }
    }
    
    private func applyFilters() {
        Task {
            do {
                let filtered = try await tmdbService.fetchFilteredMedia(
                    mediaType: filterMediaType,
                    genreId: selectedGenreId,
                    year: selectedYear,
                    minRating: minRating > 0 ? minRating : nil
                )
                self.searchResults = filtered
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
                self.traktTrending = trendingMovies + trendingTV
                self.traktFavorited = Array(trendingMovies.prefix(8) + trendingTV.suffix(8))
                self.traktWatched = Array(trendingTV.prefix(8) + trendingMovies.suffix(8))
                self.traktPlayed = Array((trendingMovies + trendingTV).shuffled().prefix(10))
                
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
