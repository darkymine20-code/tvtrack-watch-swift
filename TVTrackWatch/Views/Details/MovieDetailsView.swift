import SwiftUI

public struct MovieDetailsView: View {
    public let movie: TMDbMediaItem
    
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var imdbService = IMDbScraperService.shared
    @ObservedObject var traktService = TraktService.shared
    @ObservedObject var tmdbService = TMDbService.shared
    
    @State private var movieDetails: TMDbMovieDetails?
    @State private var imdbInfo: IMDbInfo?
    @State private var imdbReviews: [IMDbReviewItem] = []
    @State private var traktComments: [TraktComment] = []
    
    @State private var userRating: Double?
    @State private var isPlayerPresented = false
    @State private var selectedCommentTab = 0 // 0: Trakt, 1: IMDb
    
    public init(movie: TMDbMediaItem) {
        self.movie = movie
    }
    
    private var localItem: LocalMediaItem? {
        dataManager.getLocalItem(tmdbId: movie.id, mediaType: "movie")
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Section with Backdrop
                ZStack(alignment: .bottomLeading) {
                    if let backdropURL = movie.backdropURL {
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
                        // Poster
                        if let posterURL = movie.posterURL {
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
                            Text(movie.displayTitle)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Text(movie.releaseYear)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
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
                                    let cast = movieDetails?.credits?.cast.map { $0.name } ?? []
                                    let directors = movieDetails?.credits?.crew.filter { $0.job == "Director" }.map { $0.name } ?? []
                                    dataManager.toggleWatchlist(item: movie, castNames: cast, directorNames: directors)
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
                                    dataManager.toggleFavorite(item: movie)
                                }) {
                                    Image(systemName: (localItem?.isFavorite ?? false) ? "heart.fill" : "heart")
                                        .font(.subheadline)
                                        .padding(10)
                                        .background((localItem?.isFavorite ?? false) ? Color.red : Color.white.opacity(0.15))
                                        .foregroundColor(.white).cornerRadius(10)
                                }
                                
                                Button(action: {
                                    dataManager.toggleWatched(item: movie)
                                }) {
                                    Image(systemName: (localItem?.isWatched ?? false) ? "checkmark.circle.fill" : "checkmark.circle")
                                        .font(.subheadline)
                                        .padding(10)
                                        .background((localItem?.isWatched ?? false) ? Color.green : Color.white.opacity(0.15))
                                        .foregroundColor(.white).cornerRadius(10)
                                }
                                
                                Button(action: { isPlayerPresented = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                        Text("Watch Now")
                                    }
                                    .font(.subheadline).fontWeight(.bold)
                                    .padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(Color.green).foregroundColor(.white).cornerRadius(10)
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
                        .font(.title2).fontWeight(.bold)
                    Text(movieDetails?.overview ?? movie.overview ?? "No synopsis available.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(.horizontal)
                
                // Embedded YouTube Trailer Deep Link
                if let key = movieDetails?.youtubeTrailerKey, let youtubeURL = URL(string: "https://www.youtube.com/watch?v=\(key)") {
                    Link(destination: youtubeURL) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            Text("Watch Official Trailer on YouTube")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Cast & Crew List
                if let cast = movieDetails?.credits?.cast, !cast.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Cast")
                            .font(.title2).fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(cast.prefix(12)) { member in
                                    VStack(spacing: 6) {
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
                                                .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                                        }
                                        
                                        Text(member.name)
                                            .font(.caption).fontWeight(.semibold)
                                            .lineLimit(1)
                                        Text(member.character ?? "")
                                            .font(.caption2).foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 80)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Community Reviews Section (Trakt + IMDb)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Community Reviews & Comments")
                        .font(.title2).fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Picker("Reviews Source", selection: $selectedCommentTab) {
                        Text("IMDb User Reviews (\(imdbReviews.count))").tag(0)
                        Text("Trakt Community (\(traktComments.count))").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if selectedCommentTab == 0 {
                        VStack(spacing: 12) {
                            ForEach(imdbReviews.prefix(5)) { review in
                                GlassCardView {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(review.author)
                                                .font(.headline)
                                            Spacer()
                                            if let r = review.authorRating {
                                                Text("★ \(String(format: "%.0f", r))/10")
                                                    .font(.subheadline).foregroundColor(.yellow)
                                            }
                                        }
                                        Text(review.summary)
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text(review.text)
                                            .font(.caption).foregroundColor(.secondary)
                                            .lineLimit(4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(traktComments.prefix(5)) { comment in
                                GlassCardView {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(comment.user.username)
                                                .font(.headline)
                                            Spacer()
                                            if let r = comment.rating {
                                                Text("★ \(String(format: "%.0f", r))/10")
                                                    .font(.subheadline).foregroundColor(.yellow)
                                            }
                                        }
                                        Text(comment.comment)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $isPlayerPresented) {
            VideoPlayerView(title: movie.displayTitle, tmdbId: movie.id, isTV: false)
        }
        .task {
            self.userRating = localItem?.userRating
            do {
                self.movieDetails = try await tmdbService.fetchMovieDetails(id: movie.id)
                if let imdbId = movieDetails?.imdbId {
                    self.imdbInfo = try await imdbService.fetchIMDbInfo(imdbId: imdbId)
                    self.imdbReviews = try await imdbService.fetchIMDbReviews(imdbId: imdbId)
                    self.traktComments = try await traktService.fetchMovieComments(traktIdOrSlug: imdbId)
                }
            } catch {
                print("Error loading movie details: \(error)")
            }
        }
    }
}
