import SwiftUI

public struct EpisodeCardView: View {
    public let episode: TMDbEpisode
    public let isWatched: Bool
    public let onToggleWatched: () -> Void
    public let onPlay: () -> Void
    
    public init(episode: TMDbEpisode, isWatched: Bool, onToggleWatched: @escaping () -> Void, onPlay: @escaping () -> Void) {
        self.episode = episode
        self.isWatched = isWatched
        self.onToggleWatched = onToggleWatched
        self.onPlay = onPlay
    }
    
    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var countdownText: String? {
        guard let dateStr = episode.airDate, !dateStr.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let targetDate = formatter.date(from: dateStr) else { return nil }
        
        let diff = targetDate.timeIntervalSince(currentDate)
        if diff <= 0 { return nil }
        
        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Episode Thumbnail
            ZStack(alignment: .bottomTrailing) {
                if let url = episode.stillURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 140, height: 80)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 80)
                        .cornerRadius(8)
                        .overlay(Image(systemName: "tv").foregroundColor(.white))
                }
                
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
                .padding(6)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("E\(episode.episodeNumber): \(episode.name)")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    
                    if let countdown = countdownText {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                            Text("Airs in: \(countdown)")
                                .font(.caption).fontWeight(.bold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.25))
                        .foregroundColor(.yellow)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                        )
                    } else if let airDate = episode.airDate {
                        Text(airDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Actions: Watched Toggle & Play Button
            HStack(spacing: 12) {
                Button(action: onToggleWatched) {
                    HStack(spacing: 4) {
                        Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isWatched ? .green : .gray)
                        Text(isWatched ? "Watched" : "Unwatched")
                            .font(.caption)
                            .foregroundColor(isWatched ? .green : .gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                
                Button(action: onPlay) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("Play Now")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }
}
