import SwiftUI

public struct TVShowDetailsView: View {
    public let show: TMDbMediaItem
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var imdbService = IMDbScraperService.shared
    @ObservedObject var traktService = TraktService.shared
    @ObservedObject var tmdbService = TMDbService.shared
    
    @State private var tvDetails: TMDbTVDetails?
    @State private var imdbInfo: IMDbInfo?
    @State private var imdbReviews: [IMDbReviewItem] = []
    @State private var traktComments: [TraktComment] = []
    
    @State private var selectedSeasonNumber: Int = 1
    @State private var seasonDetails: TMDbSeasonDetails?
    
    @State private var userRating: Double?
    @State private var isPlayerPresented = false
    @State private var activeEpisode: TMDbEpisode?
    
    public init(show: TMDbMediaItem) {
        self.show = show
    }
    
    private var localItem: LocalMediaItem? {
        dataManager.getLocalItem(tmdbId: show.id, mediaType: "tv")
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Section
                ZStack(alignment: .bottomLeading) {
                    if let backdropURL = show.backdropURL {
                        AsyncImage(url: backdropURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(height: 340)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(height: 340)
                    }
                    
                    HStack(alignment: .bottom, spacing: 20) {
                        if let posterURL = show.posterURL {
                            AsyncImage(url: posterURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 130, height: 195)
                            .cornerRadius(12)
                            .shadow(radius: 10)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text(show.displayTitle)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Text(show.releaseYear)
                                    .font(.subheadline).foregroundColor(.gray)
                                if let seasons = tvDetails?.numberOfSeasons {
                                    Text("\(seasons) Seasons")
                                        .font(.subheadline).foregroundColor(.gray)
                                }
                            }
                            
                            // 3-Way Ratings Bar
                            RatingBarView(
                                imdbRating: imdbInfo?.rating,
                                imdbVoteCount: imdbInfo?.voteCount,
                                tmdbRating: show.voteAverage,
                                traktRating: 8.7
                            )
                            
                            // Quick Action Buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    let cast = tvDetails?.credits?.cast.map { $0.name } ?? []
                                    let directors = tvDetails?.credits?.crew.filter { $0.job == "Director" }.map { $0.name } ?? []
                                    dataManager.toggleWatchlist(item: show, castNames: cast, directorNames: directors)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: (localItem?.isWatchlist ?? false) ? "bookmark.fill" : "bookmark")
                                        Text((localItem?.isWatchlist ?? false) ? "In Watchlist" : "+ Watchlist")
                                    }
                                    .font(.subheadline).fontWeight(.semibold)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background((localItem?.isWatchlist ?? false) ? Color.blue : Color.white.opacity(0.15))
                                    .foregroundColor(.white).cornerRadius(10)
                                }
                                
                                Button(action: {
                                    dataManager.toggleFavorite(item: show)
                                }) {
                                    Image(systemName: (localItem?.isFavorite ?? false) ? "heart.fill" : "heart")
                                        .font(.subheadline).padding(10)
                                        .background((localItem?.isFavorite ?? false) ? Color.red : Color.white.opacity(0.15))
                                        .foregroundColor(.white).cornerRadius(10)
                                }
                                
                                Button(action: {
                                    dataManager.toggleWatched(item: show)
                                }) {
                                    Image(systemName: (localItem?.isWatched ?? false) ? "checkmark.circle.fill" : "checkmark.circle")
                                        .font(.subheadline).padding(10)
                                        .background((localItem?.isWatched ?? false) ? Color.green : Color.white.opacity(0.15))
                                        .foregroundColor(.white).cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // Rating Widget
                GlassCardView {
                    RatingWidgetView(currentRating: $userRating) { newRating in
                        dataManager.setUserRating(tmdbId: show.id, mediaType: "tv", rating: newRating)
                    }
                }
                .padding(.horizontal)
                
                // Synopsis
                VStack(alignment: .leading, spacing: 8) {
                    Text("Synopsis").font(.title2).fontWeight(.bold)
                    Text(tvDetails?.overview ?? show.overview ?? "No overview available.")
                        .font(.body).foregroundColor(.secondary).lineSpacing(4)
                }
                .padding(.horizontal)
                
                // TV-Specific Hierarchy: Season Selector & Episodes
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Episodes")
                            .font(.title2).fontWeight(.bold)
                        Spacer()
                        
                        Menu {
                            if let seasons = tvDetails?.seasons {
                                ForEach(seasons) { season in
                                    Button("Season \(season.seasonNumber)") {
                                        selectedSeasonNumber = season.seasonNumber
                                        loadSeason(seasonNumber: season.seasonNumber)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text("Season \(selectedSeasonNumber)")
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.down")
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white).cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let episodes = seasonDetails?.episodes {
                        VStack(spacing: 12) {
                            ForEach(episodes) { ep in
                                let epKey = "\(selectedSeasonNumber)_\(ep.episodeNumber)"
                                let isEpWatched = localItem?.watchedEpisodes[epKey] != nil
                                
                                EpisodeCardView(
                                    episode: ep,
                                    isWatched: isEpWatched,
                                    onToggleWatched: {
                                        dataManager.toggleEpisodeWatched(tvId: show.id, season: selectedSeasonNumber, episode: ep.episodeNumber)
                                    },
                                    onPlay: {
                                        activeEpisode = ep
                                        isPlayerPresented = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        ProgressView().padding(.horizontal)
                    }
                }
                
                // Community Comments
                VStack(alignment: .leading, spacing: 12) {
                    Text("Community Comments")
                        .font(.title2).fontWeight(.bold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(imdbReviews.prefix(4)) { review in
                            GlassCardView {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(review.author).font(.headline)
                                        Spacer()
                                        if let r = review.authorRating {
                                            Text("★ \(String(format: "%.0f", r))/10").font(.subheadline).foregroundColor(.yellow)
                                        }
                                    }
                                    Text(review.summary).font(.subheadline).fontWeight(.semibold)
                                    Text(review.text).font(.caption).foregroundColor(.secondary).lineLimit(3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $isPlayerPresented) {
            if let ep = activeEpisode {
                VideoPlayerView(
                    title: "\(show.displayTitle) - S\(selectedSeasonNumber)E\(ep.episodeNumber)",
                    tmdbId: show.id,
                    isTV: true,
                    seasonNumber: selectedSeasonNumber,
                    episodeNumber: ep.episodeNumber
                )
            }
        }
        .task {
            self.userRating = localItem?.userRating
            do {
                self.tvDetails = try await tmdbService.fetchTVDetails(id: show.id)
                loadSeason(seasonNumber: 1)
                if let imdbId = tvDetails?.externalIds?.imdbId {
                    self.imdbInfo = try await imdbService.fetchIMDbInfo(imdbId: imdbId)
                    self.imdbReviews = try await imdbService.fetchIMDbReviews(imdbId: imdbId)
                }
            } catch {
                print("Error loading TV show details: \(error)")
            }
        }
    }
    
    private func loadSeason(seasonNumber: Int) {
        Task {
            do {
                self.seasonDetails = try await tmdbService.fetchSeasonDetails(tvId: show.id, seasonNumber: seasonNumber)
            } catch {
                print("Failed to load season details: \(error)")
            }
        }
    }
}
