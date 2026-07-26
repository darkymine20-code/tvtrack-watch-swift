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
    @State private var visibleIMDbCount = 5
    @State private var visibleTraktCount = 5
    @State private var selectedSeason = 1
    @State private var seasonDetails: TMDbSeasonDetails?
    @State private var isPlayerPresented = false
    @State private var activeEpisode: (season: Int, episode: Int)?
    @State private var selectedPerson: TMDbCastMember? = nil
    @State private var currentDate = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    public init(show: TMDbMediaItem) {
        self.show = show
    }
    
    private var localItem: LocalMediaItem? {
        dataManager.getLocalItem(tmdbId: show.id, mediaType: "tv")
    }
    
    private var displayGenreNames: [String] {
        if let genres = details?.genres, !genres.isEmpty {
            return genres.map { $0.name }
        } else if let ids = show.genreIds, !ids.isEmpty {
            return ids.compactMap { TMDbMediaItem.genreDictionary[$0] }
        }
        return []
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
                            traktRating: (show.voteAverage ?? 8.0) * 0.95,
                            userRating: localItem?.userRating
                        )
                        
                        // Live Countdown Badge for Upcoming Episode
                        if let nextEp = nextEpisodeInfo {
                            HStack(spacing: 12) {
                                Image(systemName: "timer")
                                    .font(.title2)
                                    .foregroundColor(.yellow)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("UPCOMING EPISODE COUNTDOWN")
                                            .font(.caption2).fontWeight(.black)
                                            .foregroundColor(.yellow)
                                        
                                        Text("S\(nextEp.season) E\(nextEp.episode)")
                                            .font(.caption2).fontWeight(.heavy)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.yellow.opacity(0.25))
                                            .foregroundColor(.yellow)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(nextEp.title)
                                        .font(.subheadline).fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(nextEp.countdownText)
                                        .font(.footnote).fontWeight(.black)
                                        .foregroundColor(.cyan)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.black.opacity(0.85))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                            .shadow(color: .orange.opacity(0.4), radius: 8)
                        }
                        
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
                
                // Interactive 10-Star Rating Bar
                RatingWidgetView(userRating: localItem?.userRating) { newRating in
                    dataManager.setUserRating(tmdbId: show.id, mediaType: "tv", rating: newRating)
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
                
                // Dropdown Season Menu & EpisodeCardView List
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Text("Episodes")
                            .font(.title2).fontWeight(.bold)
                        Spacer()
                        
                        if let episodes = seasonDetails?.episodes, !episodes.isEmpty {
                            Button(action: {
                                dataManager.markSeasonAsWatched(
                                    tvId: show.id,
                                    season: selectedSeason,
                                    episodes: episodes,
                                    showTitle: show.displayTitle,
                                    posterPath: show.posterPath,
                                    backdropPath: show.backdropPath,
                                    voteAverage: show.voteAverage,
                                    releaseDate: show.releaseDate
                                )
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("Mark Season Watched")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.25))
                                .foregroundColor(.green)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.green.opacity(0.4), lineWidth: 1)
                                )
                            }
                        }
                        
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
        .sheet(item: $selectedPerson) { member in
            PersonDetailView(personName: member.name, personId: member.id)
        }
        .task {
            loadTVDetails()
        }
        .onReceive(timer) { _ in
            currentDate = Date()
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
    
    private func loadTVDetails() {
        Task {
            self.traktComments = await traktService.fetchShowComments(tmdbId: show.id)
            do {
                let det = try await tmdbService.fetchTVDetails(id: show.id)
                self.details = det
                self.credits = det.credits
                
                let castNames = det.credits?.cast.prefix(10).map { $0.name } ?? []
                let directorNames = det.credits?.crew.filter { $0.job == "Executive Producer" || $0.job == "Director" || $0.job == "Creator" }.map { $0.name } ?? []
                dataManager.updateMediaMetadata(
                    tmdbId: show.id,
                    mediaType: "tv",
                    title: det.name,
                    posterPath: det.posterPath,
                    backdropPath: det.backdropPath,
                    voteAverage: det.voteAverage,
                    releaseDate: det.firstAirDate,
                    castNames: Array(castNames),
                    directorNames: Array(directorNames)
                )
                
                // Calculate total released episodes count
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let todayStr = formatter.string(from: Date())
                var releasedCount = 0
                if let seasons = det.seasons {
                    for season in seasons where season.seasonNumber > 0 {
                        if let date = season.airDate, !date.isEmpty, date <= todayStr {
                            releasedCount += season.episodeCount ?? 0
                        } else if season.airDate == nil && det.status == "Ended" {
                            releasedCount += season.episodeCount ?? 0
                        }
                    }
                }
                if releasedCount == 0, let total = det.numberOfEpisodes {
                    releasedCount = total
                }
                dataManager.updateEpisodeCounts(tmdbId: show.id, totalEpisodes: det.numberOfEpisodes, releasedEpisodes: releasedCount)
                
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
    
    private var nextEpisodeInfo: (season: Int, episode: Int, title: String, airDate: String, countdownText: String)? {
        if let next = details?.nextEpisodeToAir, let airDate = next.airDate, !airDate.isEmpty {
            let text = formatCountdown(airDate: airDate)
            return (
                season: next.seasonNumber ?? 1,
                episode: next.episodeNumber ?? 1,
                title: next.name,
                airDate: airDate,
                countdownText: text
            )
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: currentDate)
        
        if let epList = seasonDetails?.episodes, let upcoming = epList.first(where: { ep in
            guard let date = ep.airDate, !date.isEmpty else { return false }
            return date >= todayStr
        }), let airDate = upcoming.airDate {
            let text = formatCountdown(airDate: airDate)
            return (
                season: upcoming.seasonNumber,
                episode: upcoming.episodeNumber,
                title: upcoming.name,
                airDate: airDate,
                countdownText: text
            )
        }
        
        return nil
    }
    
    private func formatCountdown(airDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let targetDate = formatter.date(from: airDate) else { return "Airing soon" }
        
        let diff = targetDate.timeIntervalSince(currentDate)
        if diff <= 0 {
            return "Airing Today! 🎉"
        }
        
        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60
        
        if days > 0 {
            return "Airs in: \(days)d \(hours)h \(minutes)m \(seconds)s"
        } else {
            return "Airs in: \(hours)h \(minutes)m \(seconds)s"
        }
    }
}
