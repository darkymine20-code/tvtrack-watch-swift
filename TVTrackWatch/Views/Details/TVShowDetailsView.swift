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
                
                // Overview
                if let overview = details?.overview ?? show.overview, !overview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synopsis")
                            .font(.title3).fontWeight(.black)
                        Text(overview)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Season Selector & Restored Original Episode List Layout
                if let seasons = details?.seasons, !seasons.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Seasons & Episodes")
                                .font(.title2).fontWeight(.black)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Season Pill Selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(seasons.filter { $0.seasonNumber > 0 }) { season in
                                    Button(action: {
                                        selectedSeason = season.seasonNumber
                                        loadSeasonEpisodes(seasonNumber: season.seasonNumber)
                                    }) {
                                        HStack(spacing: 6) {
                                            Text("Season \(season.seasonNumber)")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                            if let count = season.episodeCount {
                                                Text("(\(count))")
                                                    .font(.caption)
                                                    .opacity(0.8)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(selectedSeason == season.seasonNumber ? Color.blue : Color.white.opacity(0.08))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedSeason == season.seasonNumber ? Color.cyan : Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Restored Original Episode Card List Layout
                        if let episodes = seasonDetails?.episodes {
                            LazyVStack(spacing: 16) {
                                ForEach(episodes) { ep in
                                    let isWatched = localItem?.watchedEpisodes["\(selectedSeason)_\(ep.episodeNumber)"] != nil
                                    
                                    GlassCardView {
                                        HStack(alignment: .top, spacing: 16) {
                                            // 16:9 Episode Still Thumbnail
                                            if let stillURL = ep.stillURL {
                                                AsyncImage(url: stillURL) { img in
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Rectangle().fill(Color.gray.opacity(0.3))
                                                }
                                                .frame(width: 160, height: 95)
                                                .cornerRadius(12)
                                                .clipped()
                                            } else {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 160, height: 95)
                                                    .cornerRadius(12)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Text("Episode \(ep.episodeNumber)")
                                                        .font(.caption)
                                                        .fontWeight(.black)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.blue)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(6)
                                                    
                                                    Text(ep.name)
                                                        .font(.headline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                    
                                                    Spacer()
                                                    
                                                    if let rating = ep.voteAverage, rating > 0 {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "star.fill")
                                                                .font(.caption2)
                                                                .foregroundColor(.yellow)
                                                            Text(String(format: "%.1f", rating))
                                                                .font(.caption)
                                                                .fontWeight(.bold)
                                                                .foregroundColor(.yellow)
                                                        }
                                                    }
                                                }
                                                
                                                if let overview = ep.overview, !overview.isEmpty {
                                                    Text(overview)
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(3)
                                                }
                                                
                                                HStack(spacing: 16) {
                                                    if let airDate = ep.airDate, !airDate.isEmpty {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "calendar")
                                                                .font(.caption2)
                                                            Text(airDate)
                                                                .font(.caption)
                                                        }
                                                        .foregroundColor(.gray)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    // Mark Watched Toggle Button
                                                    Button(action: {
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
                                                    }) {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                                                            Text(isWatched ? "Watched" : "Mark Watched")
                                                        }
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(isWatched ? Color.green.opacity(0.3) : Color.white.opacity(0.1))
                                                        .foregroundColor(isWatched ? .green : .white)
                                                        .cornerRadius(8)
                                                    }
                                                    
                                                    // Play Episode Button
                                                    Button(action: {
                                                        activeEpisode = (selectedSeason, ep.episodeNumber)
                                                        isPlayerPresented = true
                                                    }) {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "play.fill")
                                                            Text("Play")
                                                        }
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                                                        .foregroundColor(.white)
                                                        .cornerRadius(8)
                                                    }
                                                }
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
