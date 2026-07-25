import SwiftUI

public struct UpcomingCalendarView: View {
    public let watchlistItems: [LocalMediaItem]
    
    public init(watchlistItems: [LocalMediaItem]) {
        self.watchlistItems = watchlistItems
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Upcoming Episode Releases")
                    .font(.title2).fontWeight(.bold)
                    .padding(.horizontal)
                
                if watchlistItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                        Text("No TV Shows currently in your Watchlist.")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(watchlistItems) { item in
                            GlassCardView {
                                HStack(spacing: 16) {
                                    if let path = item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                                        AsyncImage(url: url) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: 60, height: 90)
                                        .cornerRadius(8)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title)
                                            .font(.headline)
                                        Text("Next Air Date: \(item.releaseDate ?? "TBA")")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        Text("Saved in Watchlist")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "calendar")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
    }
}
