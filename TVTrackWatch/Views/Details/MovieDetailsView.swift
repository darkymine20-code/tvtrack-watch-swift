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
    @State private var visibleIMDbCount = 5
    @State private var visibleTraktCount = 5
    @State private var isPlayerPresented = false
    @State private var selectedPerson: TMDbCastMember? = nil
    
    public init(movie: TMDbMediaItem) {
        self.movie = movie
    }
    
    private var localItem: LocalMediaItem? {
        dataManager.getLocalItem(tmdbId: movie.id, mediaType: "movie")
    }
    
    private var displayGenreNames: [String] {
        if let genres = details?.genres, !genres.isEmpty {
            return genres.map { $0.name }
        } else if let ids = movie.genreIds, !ids.isEmpty {
            return ids.compactMap { TMDbMediaItem.genreDictionary[$0] }
        }
        return []
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
                            traktRating: (movie.voteAverage ?? 8.0) * 0.95,
                            userRating: localItem?.userRating
                        )
                        
                        // Release Date & Runtime Metadata Row
                        HStack(spacing: 16) {
                            if let releaseDate = details?.releaseDate ?? movie.releaseDate, !releaseDate.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.cyan)
                                    Text("Released: \(releaseDate)")
                                        .fontWeight(.bold)
                                }
                            }
                            
                            if let runtime = details?.runtime, runtime > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.yellow)
                                    Text("Runtime: \(formatRuntime(runtime))")
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        
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
                
                // Genre Badges Row
                if !displayGenreNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(displayGenreNames, id: \.self) { genre in
                                Text(genre)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        LinearGradient(colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal)
                    }
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
                
                // Interactive 10-Star Rating Bar
                RatingWidgetView(userRating: localItem?.userRating) { newRating in
                    dataManager.setUserRating(tmdbId: movie.id, mediaType: "movie", rating: newRating)
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
                                    Button(action: { selectedPerson = member }) {
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
                            let visibleReviews = Array(imdbReviews.prefix(visibleIMDbCount))
                            ForEach(Array(visibleReviews.enumerated()), id: \.element.id) { index, review in
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
                                        
                                        CollapsibleCommentTextView(text: review.text)
                                        
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
                                .onAppear {
                                    if index == visibleReviews.count - 1 && visibleIMDbCount < imdbReviews.count {
                                        visibleIMDbCount += 5
                                    }
                                }
                            }
                            
                            if visibleIMDbCount < imdbReviews.count {
                                Button(action: { visibleIMDbCount += 5 }) {
                                    HStack {
                                        Text("Show More Reviews (\(imdbReviews.count - visibleIMDbCount) remaining)")
                                        Image(systemName: "chevron.down")
                                    }
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundColor(.yellow)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.yellow.opacity(0.15))
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        // Trakt Tab
                        if traktComments.isEmpty {
                            GlassCardView {
                                Text("No Trakt reactions available.")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            .padding(.horizontal)
                        } else {
                            let visibleComments = Array(traktComments.prefix(visibleTraktCount))
                            ForEach(Array(visibleComments.enumerated()), id: \.element.id) { index, comment in
                                GlassCardView {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 12) {
                                            // User Profile Picture Avatar
                                            if let avatarURL = comment.user.avatarURL {
                                                AsyncImage(url: avatarURL) { img in
                                                    img.resizable().aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Circle().fill(Color.red.opacity(0.4))
                                                        .overlay(Text(String(comment.user.username.prefix(1)).uppercased()).font(.caption).fontWeight(.black).foregroundColor(.white))
                                                }
                                                .frame(width: 38, height: 38)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                            } else {
                                                Circle()
                                                    .fill(Color.red.opacity(0.4))
                                                    .frame(width: 38, height: 38)
                                                    .overlay(Text(String(comment.user.username.prefix(1)).uppercased()).font(.caption).fontWeight(.black).foregroundColor(.white))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 6) {
                                                    Text(comment.user.name ?? comment.user.username)
                                                        .font(.subheadline).fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                    
                                                    if comment.user.vip == true {
                                                        Text("VIP")
                                                            .font(.caption2).fontWeight(.black)
                                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                                            .background(Color.purple)
                                                            .foregroundColor(.white)
                                                            .cornerRadius(4)
                                                    }
                                                }
                                                
                                                Text("@\(comment.user.username)")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(comment.reactionEmoji)
                                                .font(.title2)
                                            
                                            Text(comment.formattedDate)
                                                .font(.caption2).foregroundColor(.gray)
                                        }
                                        
                                        CollapsibleCommentTextView(text: comment.comment)
                                        
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
                                .onAppear {
                                    if index == visibleComments.count - 1 && visibleTraktCount < traktComments.count {
                                        visibleTraktCount += 5
                                    }
                                }
                            }
                            
                            if visibleTraktCount < traktComments.count {
                                Button(action: { visibleTraktCount += 5 }) {
                                    HStack {
                                        Text("Show More Reactions (\(traktComments.count - visibleTraktCount) remaining)")
                                        Image(systemName: "chevron.down")
                                    }
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundColor(.cyan)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.cyan.opacity(0.15))
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isPlayerPresented) {
            VideoPlayerView(title: movie.displayTitle, tmdbId: movie.id, isTV: false)
        }
        .sheet(item: $selectedPerson) { member in
            PersonDetailView(personName: member.name, personId: member.id)
        }
        .task {
            loadMovieDetails()
        }
    }
    
    private func openYouTubeTrailer(key: String) {
        #if os(iOS)
        let candidates = [
            "youtube://www.youtube.com/watch?v=\(key)",
            "youtube://watch?v=\(key)",
            "vnd.youtube://\(key)",
            "youtube://\(key)"
        ]
        for scheme in candidates {
            if let appURL = URL(string: scheme), UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
                return
            }
        }
        if let directAppURL = URL(string: "youtube://www.youtube.com/watch?v=\(key)") {
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
                
                let castNames = det.credits?.cast.prefix(10).map { $0.name } ?? []
                let directorNames = det.credits?.crew.filter { $0.job == "Director" }.map { $0.name } ?? []
                dataManager.updateMediaMetadata(
                    tmdbId: movie.id,
                    mediaType: "movie",
                    title: det.title,
                    posterPath: det.posterPath,
                    backdropPath: det.backdropPath,
                    voteAverage: det.voteAverage,
                    releaseDate: det.releaseDate,
                    castNames: Array(castNames),
                    directorNames: Array(directorNames)
                )
                
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
    
    private func formatRuntime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
