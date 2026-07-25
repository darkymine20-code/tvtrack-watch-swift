import SwiftUI

public struct MovieDetailsView: View {
    public let movie: TMDbMediaItem
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var imdbService = IMDbScraperService.shared
    @ObservedObject var traktService = TraktService.shared
    @ObservedObject var tmdbService = TMDbService.shared
    
    @State private var movieDetails: TMDbMovieDetails?
    @State private var castMembers: [TMDbCastMember] = []
    @State private var imdbInfo: IMDbInfo?
    @State private var imdbReviews: [IMDbReviewItem] = []
    @State private var traktComments: [TraktComment] = []
    
    @State private var userRating: Double?
    @State private var isPlayerPresented = false
    @State private var selectedCommentTab = 0 // 0: IMDb (100), 1: Trakt
    
    public init(movie: TMDbMediaItem) {
        self.movie = movie
    }
    
    private var localItem: LocalMediaItem? {
        dataManager.getLocalItem(tmdbId: movie.id, mediaType: "movie")
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Section with Backdrop & Glow
                ZStack(alignment: .bottomLeading) {
                    if let backdropURL = movie.backdropURL {
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
                        // Poster
                        if let posterURL = movie.posterURL {
                            AsyncImage(url: posterURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 140, height: 210)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.5), radius: 12)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(movie.displayTitle)
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Text(movie.releaseYear)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(6)
                                
                                if let runtime = movieDetails?.runtime {
                                    Text("\(runtime) mins")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // 3-Way Ratings Bar
                            RatingBarView(
                                imdbRating: imdbInfo?.rating,
                                imdbVoteCount: imdbInfo?.voteCount,
                                tmdbRating: movie.voteAverage,
                                traktRating: 8.4
                            )
                            
                            // Quick Action Buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    let cast = castMembers.map { $0.name }
                                    let directors = movieDetails?.credits?.crew.filter { $0.job == "Director" }.map { $0.name } ?? []
                                    dataManager.toggleWatchlist(item: movie, castNames: cast, directorNames: directors)
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
                                    dataManager.toggleFavorite(item: movie, castNames: cast)
                                }) {
                                    Image(systemName: (localItem?.isFavorite ?? false) ? "heart.fill" : "heart")
                                        .font(.title3)
                                        .padding(10)
                                        .background((localItem?.isFavorite ?? false) ? Color.red : Color.white.opacity(0.15))
                                        .foregroundColor(.white).cornerRadius(12)
                                }
                                
                                Button(action: {
                                    let cast = castMembers.map { $0.name }
                                    dataManager.toggleWatched(item: movie, castNames: cast)
                                }) {
                                    Image(systemName: (localItem?.isWatched ?? false) ? "checkmark.circle.fill" : "checkmark.circle")
                                        .font(.title3)
                                        .padding(10)
                                        .background((localItem?.isWatched ?? false) ? Color.green : Color.white.opacity(0.15))
                                        .foregroundColor(.white).cornerRadius(12)
                                }
                                
                                Button(action: { isPlayerPresented = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                        Text("Watch Now")
                                    }
                                    .font(.subheadline).fontWeight(.black)
                                    .padding(.horizontal, 20).padding(.vertical, 12)
                                    .background(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing))
                                    .foregroundColor(.white).cornerRadius(12)
                                    .shadow(color: .green.opacity(0.4), radius: 8)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // 10-Star Interactive Rating Widget
                GlassCardView {
                    RatingWidgetView(currentRating: $userRating) { newRating in
                        dataManager.setUserRating(tmdbId: movie.id, mediaType: "movie", rating: newRating)
                    }
                }
                .padding(.horizontal)
                
                // Overview & Synopsis
                VStack(alignment: .leading, spacing: 8) {
                    Text("Synopsis")
                        .font(.title2).fontWeight(.black)
                    Text(movieDetails?.overview ?? movie.overview ?? "No synopsis available.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(6)
                }
                .padding(.horizontal)
                
                // YouTube App Deep Link Button (Issue 1)
                if let key = movieDetails?.youtubeTrailerKey {
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
                                            .overlay(Circle().stroke(Color.blue.opacity(0.4), lineWidth: 2))
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
                
                // Community Reviews Section (Issue 3: All 100+ Reviews)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Community Reviews & Comments")
                        .font(.title2).fontWeight(.black)
                        .padding(.horizontal)
                    
                    Picker("Reviews Source", selection: $selectedCommentTab) {
                        Text("IMDb Reviews (\(imdbReviews.count))").tag(0)
                        Text("Trakt Community (\(traktComments.count))").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if selectedCommentTab == 0 {
                        if imdbReviews.isEmpty {
                            Text("Fetching IMDb user reviews...")
                                .font(.subheadline).foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
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
                    } else {
                        if traktComments.isEmpty {
                            Text("No Trakt comments found.")
                                .font(.subheadline).foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(traktComments) { comment in
                                    GlassCardView {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(comment.user.username)
                                                    .font(.headline)
                                                    .foregroundColor(.purple)
                                                Spacer()
                                                if let r = comment.rating {
                                                    Text("★ \(String(format: "%.0f", r))/10")
                                                        .font(.subheadline).fontWeight(.bold).foregroundColor(.yellow)
                                                }
                                            }
                                            Text(comment.comment)
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
                }
            }
            .padding(.bottom, 60)
        }
        .sheet(isPresented: $isPlayerPresented) {
            VideoPlayerView(title: movie.displayTitle, tmdbId: movie.id, isTV: false)
        }
        .task {
            self.userRating = localItem?.userRating
            do {
                self.movieDetails = try await tmdbService.fetchMovieDetails(id: movie.id)
                let credits = try await tmdbService.fetchMovieCredits(id: movie.id)
                self.castMembers = credits.cast
                
                if let imdbId = movieDetails?.imdbId {
                    self.imdbInfo = try await imdbService.fetchIMDbInfo(imdbId: imdbId)
                    self.imdbReviews = try await imdbService.fetchIMDbReviews(imdbId: imdbId, limit: 100)
                    self.traktComments = try await traktService.fetchMovieComments(traktIdOrSlug: imdbId)
                }
            } catch {
                print("Error loading movie details: \(error)")
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
