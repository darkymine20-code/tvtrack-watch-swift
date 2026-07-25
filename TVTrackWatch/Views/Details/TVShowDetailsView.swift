import SwiftUI

public struct TVShowDetailsView: View {
    public let show: TMDbMediaItem
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var imdbService = IMDbScraperService.shared
    @ObservedObject var traktService = TraktService.shared
    @ObservedObject var tmdbService = TMDbService.shared
    
    @State private var tvDetails: TMDbTVDetails?
    @State private var castMembers: [TMDbCastMember] = []
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
            VStack(alignment: .leading, spacing: 24) {
                // Hero Section
                ZStack(alignment: .bottomLeading) {
                    if let backdropURL = show.backdropURL {
                        AsyncImage(url: backdropURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(height: 380)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.4), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        Rectangle()
                            .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3), .black], startPoint: .top, endPoint: .bottom))
                            .frame(height: 380)
                    }
                    
                    HStack(alignment: .bottom, spacing: 20) {
                        if let posterURL = show.posterURL {
                            AsyncImage(url: posterURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 140, height: 210)
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.5), radius: 12)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(show.displayTitle)
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Text(show.releaseYear)
                                    .font(.subheadline).fontWeight(.bold)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(6)
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
                                    let cast = castMembers.map { $0.name }
                                    let directors = tvDetails?.credits?.crew.filter { $0.job == "Director" }.map { $0.name } ?? []
                                    dataManager.toggleWatchlist(item: show, castNames: cast, directorNames: directors)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: (localItem?.isWatchlist ?? false) ? "bookmark.fill" : "bookmark")
                                        Text((localItem?.isWatchlist ?? false) ? "In Watchlist" : "+ Watchlist")
                                    }
                                    .font(.subheadline).fontWeight(.bold)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background((localItem?.isWatchlist ?? false) ? Color.blue : Color.white.opacity(0.15))
                                    .foregroundColor(.white).cornerRadius(12)
                                }
                                
                                Button(action: {
                                    let cast = castMembers.map { $0.name }
                                    dataManager.toggleFavorite(item: show, castNames: cast)
                                }) {
                                    Image(systemName: (localItem?.isFavorite ?? false) ? "heart.fill" : "heart")
                                        .font(.title3).padding(10)
                                        .background((localItem?.isFavorite ?? false) ? Color.red : Color.white.opacity(0.15))
                                        .foregroundColor(.white).cornerRadius(12)
                                }
                                
                                Button(action: {
                                    let cast = castMembers.map { $0.name }
                                    dataManager.toggleWatched(item: show, castNames: cast)
                                }) {
                                    Image(systemName: (localItem?.isWatched ?? false) ? "checkmark.circle.fill" : "checkmark.circle")
                                        .font(.title3).padding(10)
                                        .background((localItem?.isWatched ?? false) ? Color.green : Color.white.opacity(0.15))
                                        .foregroundColor(.white).cornerRadius(12)
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
                    Text("Synopsis").font(.title2).fontWeight(.black)
                    Text(tvDetails?.overview ?? show.overview ?? "No overview available.")
                        .font(.body).foregroundColor(.secondary).lineSpacing(6)
                }
                .padding(.horizontal)
                
                // YouTube App Deep Link (Issue 1)
                if let key = tvDetails?.youtubeTrailerKey {
                    Button(action: {
                        openYouTubeTrailer(key: key)
                    }) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            Text("Open Official Trailer in YouTube App")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right.app.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }
                
                // TV-Specific Hierarchy: Season Selector & Episodes
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Episodes")
                            .font(.title2).fontWeight(.black)
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
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white).cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let episodes = seasonDetails?.episodes {
                        VStack(spacing: 14) {
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
                
                // Cast & Crew List (Issue 4)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cast & Crew")
                        .font(.title2).fontWeight(.black)
                        .padding(.horizontal)
                    
                    if castMembers.isEmpty {
                        Text("Loading cast details...")
                            .font(.subheadline).foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(castMembers) { member in
                                    VStack(spacing: 8) {
                                        if let profileURL = member.profileURL {
                                            AsyncImage(url: profileURL) { img in
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Circle().fill(Color.gray.opacity(0.3))
                                            }
                                            .frame(width: 75, height: 75)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.purple.opacity(0.4), lineWidth: 2))
                                        } else {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 75, height: 75)
                                                .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                                        }
                                        
                                        Text(member.name)
                                            .font(.caption).fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(member.character ?? "")
                                            .font(.caption2).foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 85)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Community Comments (Issue 3: All 100+ Reviews)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Community Reviews & Comments")
                        .font(.title2).fontWeight(.black)
                        .padding(.horizontal)
                    
                    VStack(spacing: 14) {
                        ForEach(imdbReviews) { review in
                            GlassCardView {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(review.author)
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                        Spacer()
                                        if let r = review.authorRating {
                                            Text("★ \(String(format: "%.0f", r))/10")
                                                .font(.subheadline).fontWeight(.bold).foregroundColor(.yellow)
                                        }
                                    }
                                    if !review.summary.isEmpty {
                                        Text(review.summary)
                                            .font(.subheadline).fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    Text(review.text)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .lineSpacing(4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 60)
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
                let credits = try await tmdbService.fetchTVCredits(id: show.id)
                self.castMembers = credits.cast
                loadSeason(seasonNumber: 1)
                if let imdbId = tvDetails?.externalIds?.imdbId {
                    self.imdbInfo = try await imdbService.fetchIMDbInfo(imdbId: imdbId)
                    self.imdbReviews = try await imdbService.fetchIMDbReviews(imdbId: imdbId, limit: 100)
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
    
    private func openYouTubeTrailer(key: String) {
        #if os(iOS)
        let appURL = URL(string: "youtube://watch?v=\(key)")!
        let webURL = URL(string: "https://www.youtube.com/watch?v=\(key)")!
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(webURL)
        }
        #endif
    }
}
