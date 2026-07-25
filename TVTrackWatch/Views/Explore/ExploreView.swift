import SwiftUI

public struct ExploreView: View {
    @ObservedObject var tmdbService = TMDbService.shared
    @ObservedObject var traktService = TraktService.shared
    @ObservedObject var dataManager = DataManager.shared
    
    @State private var searchQuery = ""
    @State private var searchResults: [TMDbMediaItem] = []
    
    @State private var trendingMovies: [TMDbMediaItem] = []
    @State private var trendingTV: [TMDbMediaItem] = []
    @State private var recommendedItems: [TMDbMediaItem] = []
    
    @State private var isFilterSheetPresented = false
    @State private var selectedGenreId: Int?
    @State private var selectedYear = ""
    @State private var minRating = 0.0
    @State private var filterMediaType = "movie"
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search & Filter Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search movies, TV shows, actors...", text: $searchQuery)
                        .onChange(of: searchQuery) {
                            performSearch(query: searchQuery)
                        }
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                Button(action: { isFilterSheetPresented = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filters")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.black.opacity(0.4))
            
            ScrollView {
                if !searchQuery.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Search Results (\(searchResults.count))")
                            .font(.title2).fontWeight(.bold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(searchResults) { item in
                                MediaCardCell(item: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                } else {
                    VStack(alignment: .leading, spacing: 28) {
                        // Section 1: Recommended For You (Algorithmic)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("Recommended For You")
                                    .font(.title2).fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            MediaCarouselHorizontal(items: recommendedItems)
                        }
                        
                        // Section 2: Trakt Discovery - Trending TV Shows
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("Trending TV Shows")
                                    .font(.title2).fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            MediaCarouselHorizontal(items: trendingTV)
                        }
                        
                        // Section 3: Trakt Discovery - Trending Movies
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "popcorn.fill")
                                    .foregroundColor(.red)
                                Text("Trending Movies")
                                    .font(.title2).fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            MediaCarouselHorizontal(items: trendingMovies)
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
    
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        Task {
            do {
                self.searchResults = try await tmdbService.searchMedia(query: query)
            } catch {
                print("Search error: \(error)")
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
                let movies = try await tmdbService.fetchTrendingMovies()
                let tvShows = try await tmdbService.fetchTrendingTVShows()
                self.trendingMovies = movies
                self.trendingTV = tvShows
                
                let history = Array(dataManager.items.values)
                self.recommendedItems = RecommendationEngine.shared.generateRecommendations(userHistory: history, trendingItems: movies + tvShows)
            } catch {
                print("Error loading explore data: \(error)")
            }
        }
    }
}
