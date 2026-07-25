import SwiftUI

public struct TVShowDetailsView: View {
    public let show: TMDbMediaItem
    
    @ObservedObject var tmdbService = TMDbService.shared
    @ObservedObject var imdbService = IMDbScraperService.shared
    @ObservedObject var traktService = TraktService.shared
    @ObservedObject var dataManager = DataManager.shared
    
    @State private var details: TMDbTVDetails?
    @State private var credits: TMDbCredits?
    @State private var imdbInfo: IMDbInfo?
    @State private var imdbReviews: [IMDbReviewItem] = []
    @State private var traktComments: [TraktComment] = []
    @State private var selectedReviewTab = 0
    @State private var selectedSeason = 1
    @State private var seasonDetails: TMDbSeasonDetails?
    @State private var isPlayerPresented = false
    @State private var activeEpisode: (season: Int, episode: Int)?
    
    public init(show: TMDbMediaItem) {
        self.show = show
    }
    
    private var localItem: LocalMediaItem? {
        dataManager.getLocalItem(tmdbId: show.id, mediaType: "tv")
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Backdrop Header
                ZStack(alignment: .bottomLeading) {
                    if let backdropURL = show.backdropURL ?? show.posterURL {
                        AsyncImage(url: backdropURL) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(height: 380)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6), .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 380)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(show.displayTitle)
                            .font(.system(size: 34, weight: .black))
                            .foregroundColor(.white)
                            .shadow(radius: 6)
                        
                        RatingBarView(
                            imdbRating: imdbInfo?.rating ?? show.voteAverage,
                            imdbVoteCount: imdbInfo?.voteCount ?? show.voteCount,
                            tmdbRating: show.voteAverage,
                            traktRating: (show.voteAverage ?? 8.0) * 0.95
                        )
                        
                        if let key = details?.youtubeTrailerKey {
                            Button(action: { openYouTubeTrailer(key: key) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.rectangle.fill")
                                    Text("Trailer (YouTube)")
                                }
                                .font(.headline).fontWeight(.bold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: .red.opacity(0.5), radius: 8)
                            }
                        }
                    }
                    .padding(24)
                }
                
                // Action Buttons Bar
                HStack(spacing: 16) {
                    Button(action: { dataManager.toggleWatchlist(item: show) }) {
                        Label(
                            localItem?.isWatchlist == true ? "In Watchlist" : "+ Watchlist",
                            systemImage: localItem?.isWatchlist == true ? "checkmark.circle.fill" : "plus.circle"
                        )
                        .font(.headline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(localItem?.isWatchlist == true ? Color.blue : Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: { dataManager.toggleFavorite(item: show) }) {
                        Image(systemName: localItem?.isFavorite == true ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(localItem?.isFavorite == true ? .red : .white)
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Overview / Synopsis
                if let overview = details?.overview ?? show.overview, !overview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synopsis")
                            .font(.title2).fontWeight(.bold)
                        Text(overview)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal)
                }
                
                // Cast Carousel for TV Shows
                if let cast = credits?.cast, !cast.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Cast")
                            .font(.title3).fontWeight(.black)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(cast.prefix(15)) { member in
                                    VStack(alignment: .center, spacing: 6) {
                                        if let profileURL = member.profileURL {
                                            AsyncImage(url: profileURL) { img in
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Circle().fill(Color.gray.opacity(0.3))
                                            }
                                            .frame(width: 70, height: 70)
                                            .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 70, height: 70)
                                        }
                                        
                                        Text(member.name)
                                            .font(.caption).fontWeight(.bold)
                                            .lineLimit(1)
                                            .foregroundColor(.white)
                                        
                                        if let character = member.character {
                                            Text(character)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(width: 90)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Dropdown Season Menu & EpisodeCardView List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Episodes")
                            .font(.title2).fontWeight(.bold)
                        Spacer()
                        
                        // Original Dropdown Menu for Season Selection
                        Menu {
                            if let seasons = details?.seasons {
                                ForEach(seasons.filter { $0.seasonNumber > 0 }) { season in
                                    Button("Season \(season.seasonNumber)") {
                                        selectedSeason = season.seasonNumber
                                        loadSeasonEpisodes(seasonNumber: season.seasonNumber)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text("Season \(selectedSeason)")
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.down")
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Original EpisodeCardView List
                    if let episodes = seasonDetails?.episodes {
                        VStack(spacing: 12) {
                            ForEach(episodes) { ep in
                                let epKey = "\(selectedSeason)_\(ep.episodeNumber)"
                                let isEpWatched = localItem?.watchedEpisodes[epKey] != nil
                                
                                EpisodeCardView(
                                    episode: ep,
                                    isWatched: isEpWatched,
                                    onToggleWatched: {
                                        dataManager.toggleEpisodeWatched(
                                            tvId: show.id,
                                            season: selectedSeason,
                                            episode: ep.episodeNumber,
                                            showTitle: show.displayTitle,
                                            posterPath: show.posterPath,
                                            backdropPath: show.backdropPath,
                                            voteAverage: show.voteAverage,
                                            releaseDate: show.releaseDate
                                        )
                                    },
                                    onPlay: {
                                        activeEpisode = (selectedSeason, ep.episodeNumber)
                                        isPlayerPresented = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        ProgressView()
                            .padding(.horizontal)
                    }
                }
                
                // Tabbed Community Reviews (IMDb Reviews & Trakt Reactions)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Community Discussions & Reviews")
                        .font(.title3).fontWeight(.black)
                        .padding(.horizontal)
                    
                    Picker("Review Source", selection: $selectedReviewTab) {
                        Text("IMDb Reviews (\(imdbReviews.count))").tag(0)
                        Text("Trakt Reactions (\(traktComments.count))").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if selectedReviewTab == 0 {
                        // IMDb Tab
                        if imdbReviews.isEmpty {
                            GlassCardView {
                                Text("Loading IMDb Reviews...")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            .padding(.horizontal)
                        } else {
                            ForEach(imdbReviews) { review in
                                GlassCardView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(review.author)
                                                .font(.subheadline).fontWeight(.bold)
                                                .foregroundColor(.yellow)
                                            Spacer()
                                            if let r = review.authorRating {
                                                Text("★ \(String(format: "%.1f", r))/10")
                                                    .font(.caption).fontWeight(.black)
                                                    .foregroundColor(.yellow)
                                            }
                                        }
                                        
                                        Text(review.summary)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text(review.text)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        HStack(spacing: 12) {
                                            Text("👍 \(review.upVotes) helpful")
                                                .font(.caption2).foregroundColor(.gray)
                                            Text(review.submissionDate)
                                                .font(.caption2).foregroundColor(.gray)
                                        }
                                    }
                                    .padding()
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        // Trakt Tab
                        ForEach(traktComments) { comment in
                            GlassCardView {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(comment.reactionEmoji)
                                            .font(.title2)
                                        Text(comment.user.username)
                                            .font(.subheadline).fontWeight(.bold)
                                            .foregroundColor(.red)
                                        Spacer()
                                        Text(comment.formattedDate)
                                            .font(.caption2).foregroundColor(.gray)
                                    }
                                    
                                    Text(comment.comment)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    
                                    HStack(spacing: 14) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "hand.thumbsup.fill")
                                                .font(.caption2)
                                            Text("\(comment.likes)")
                                                .font(.caption2).fontWeight(.bold)
                                        }
                                        .foregroundColor(.green)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.turn.down.right")
                                                .font(.caption2)
                                            Text("\(comment.replies ?? 0) Replies")
                                                .font(.caption2).fontWeight(.bold)
                                        }
                                        .foregroundColor(.cyan)
                                    }
                                }
                                .padding()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isPlayerPresented) {
            if let ep = activeEpisode {
                VideoPlayerView(
                    title: "\(show.displayTitle) S\(ep.season)E\(ep.episode)",
                    tmdbId: show.id,
                    isTV: true,
                    seasonNumber: ep.season,
                    episodeNumber: ep.episode
                )
            }
        }
        .task {
            loadTVDetails()
        }
    }
    
    private func openYouTubeTrailer(key: String) {
        if let youtubeAppURL = URL(string: "youtube://watch?v=\(key)") {
            #if os(iOS)
            if UIApplication.shared.canOpenURL(youtubeAppURL) {
                UIApplication.shared.open(youtubeAppURL)
                return
            }
            #endif
        }
        if let webURL = URL(string: "https://www.youtube.com/watch?v=\(key)") {
            #if os(iOS)
            UIApplication.shared.open(webURL)
            #endif
        }
    }
    
    private func loadTVDetails() {
        Task {
            self.traktComments = await traktService.fetchShowComments(tmdbId: show.id)
            do {
                let det = try await tmdbService.fetchTVDetails(id: show.id)
                self.details = det
                self.credits = det.credits
                loadSeasonEpisodes(seasonNumber: 1)
                
                var resolvedId = det.externalIds?.imdbId
                if resolvedId == nil || resolvedId!.isEmpty {
                    resolvedId = await tmdbService.fetchIMDbId(mediaType: "tv", id: show.id)
                }
                let finalImdbId = resolvedId ?? "tt\(show.id)"
                
                self.imdbInfo = await imdbService.fetchIMDbInfo(
                    imdbId: finalImdbId,
                    defaultRating: show.voteAverage,
                    defaultVoteCount: show.voteCount
                )
                self.imdbReviews = await imdbService.fetchIMDbReviews(imdbId: finalImdbId, limit: 50)
                let freshTrakt = await traktService.fetchShowComments(tmdbId: show.id, imdbId: finalImdbId)
                if !freshTrakt.isEmpty {
                    self.traktComments = freshTrakt
                }
            } catch {
                print("Error loading TV details: \(error)")
            }
        }
    }
    
    private func loadSeasonEpisodes(seasonNumber: Int) {
        Task {
            do {
                let sDetails = try await tmdbService.fetchSeasonDetails(tvId: show.id, seasonNumber: seasonNumber)
                self.seasonDetails = sDetails
            } catch {
                print("Error loading season details: \(error)")
            }
        }
    }
}
