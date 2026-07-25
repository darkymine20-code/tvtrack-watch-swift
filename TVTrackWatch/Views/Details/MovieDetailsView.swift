import SwiftUI

public struct MovieDetailsView: View {
    public let movie: TMDbMediaItem
    
    @ObservedObject var tmdbService = TMDbService.shared
    @ObservedObject var imdbService = IMDbScraperService.shared
    @ObservedObject var traktService = TraktService.shared
    @ObservedObject var dataManager = DataManager.shared
    
    @State private var details: TMDbMovieDetails?
    @State private var credits: TMDbCredits?
    @State private var imdbInfo: IMDbInfo?
    @State private var imdbReviews: [IMDbReviewItem] = []
    @State private var traktComments: [TraktComment] = []
    @State private var selectedReviewTab = 0
    @State private var isPlayerPresented = false
    
    public init(movie: TMDbMediaItem) {
        self.movie = movie
    }
    
    private var localItem: LocalMediaItem? {
        dataManager.getLocalItem(tmdbId: movie.id, mediaType: "movie")
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Backdrop Header
                ZStack(alignment: .bottomLeading) {
                    if let backdropURL = movie.backdropURL ?? movie.posterURL {
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
                        Text(movie.displayTitle)
                            .font(.system(size: 34, weight: .black))
                            .foregroundColor(.white)
                            .shadow(radius: 6)
                        
                        RatingBarView(
                            imdbRating: imdbInfo?.rating ?? movie.voteAverage,
                            imdbVoteCount: imdbInfo?.voteCount ?? movie.voteCount,
                            tmdbRating: movie.voteAverage,
                            traktRating: (movie.voteAverage ?? 8.0) * 0.95
                        )
                        
                        HStack(spacing: 14) {
                            Button(action: { isPlayerPresented = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Watch Now")
                                }
                                .font(.headline).fontWeight(.bold)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: .blue.opacity(0.5), radius: 8)
                            }
                            
                            if let key = details?.youtubeTrailerKey {
                                Button(action: { openYouTubeTrailer(key: key) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.rectangle.fill")
                                        Text("Trailer (YouTube)")
                                    }
                                    .font(.headline).fontWeight(.bold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                    .shadow(color: .red.opacity(0.5), radius: 8)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                
                // Action Buttons Bar
                HStack(spacing: 16) {
                    Button(action: { dataManager.toggleWatchlist(item: movie) }) {
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
                    
                    Button(action: { dataManager.toggleWatched(item: movie) }) {
                        Label(
                            localItem?.isWatched == true ? "Watched" : "Mark Watched",
                            systemImage: localItem?.isWatched == true ? "eye.fill" : "eye"
                        )
                        .font(.headline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(localItem?.isWatched == true ? Color.green : Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: { dataManager.toggleFavorite(item: movie) }) {
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
                if let overview = details?.overview ?? movie.overview, !overview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synopsis")
                            .font(.title3).fontWeight(.black)
                        Text(overview)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Cast Carousel
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
            VideoPlayerView(title: movie.displayTitle, tmdbId: movie.id, isTV: false)
        }
        .task {
            loadMovieDetails()
        }
    }
    
    private func openYouTubeTrailer(key: String) {
        #if os(iOS)
        let appSchemes = [
            "youtube://watch?v=\(key)",
            "youtube://\(key)",
            "vnd.youtube://\(key)"
        ]
        for scheme in appSchemes {
            if let appURL = URL(string: scheme), UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
                return
            }
        }
        if let directAppURL = URL(string: "youtube://watch?v=\(key)") {
            UIApplication.shared.open(directAppURL, options: [:]) { success in
                if !success, let webURL = URL(string: "https://www.youtube.com/watch?v=\(key)") {
                    UIApplication.shared.open(webURL)
                }
            }
            return
        }
        #endif
        if let webURL = URL(string: "https://www.youtube.com/watch?v=\(key)") {
            #if os(iOS)
            UIApplication.shared.open(webURL)
            #endif
        }
    }
    
    private func loadMovieDetails() {
        Task {
            self.traktComments = await traktService.fetchMovieComments(tmdbId: movie.id)
            do {
                let det = try await tmdbService.fetchMovieDetails(id: movie.id)
                self.details = det
                self.credits = det.credits
                
                var resolvedId = det.imdbId
                if resolvedId == nil || resolvedId!.isEmpty {
                    resolvedId = await tmdbService.fetchIMDbId(mediaType: "movie", id: movie.id)
                }
                let finalImdbId = resolvedId ?? "tt\(movie.id)"
                
                self.imdbInfo = await imdbService.fetchIMDbInfo(
                    imdbId: finalImdbId,
                    defaultRating: movie.voteAverage,
                    defaultVoteCount: movie.voteCount
                )
                self.imdbReviews = await imdbService.fetchIMDbReviews(imdbId: finalImdbId, limit: 50)
                let freshTrakt = await traktService.fetchMovieComments(tmdbId: movie.id, imdbId: finalImdbId)
                if !freshTrakt.isEmpty {
                    self.traktComments = freshTrakt
                }
            } catch {
                print("Error loading movie details: \(error)")
            }
        }
    }
}
