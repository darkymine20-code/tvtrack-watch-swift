import SwiftUI

public struct RatingBarView: View {
    public let imdbRating: Double?
    public let imdbVoteCount: Int?
    public let tmdbRating: Double?
    public let traktRating: Double?
    
    public init(imdbRating: Double? = nil, imdbVoteCount: Int? = nil, tmdbRating: Double? = nil, traktRating: Double? = nil) {
        self.imdbRating = imdbRating
        self.imdbVoteCount = imdbVoteCount
        self.tmdbRating = tmdbRating
        self.traktRating = traktRating
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            // IMDb Badge
            HStack(spacing: 6) {
                Text("IMDb")
                    .font(.caption2)
                    .fontWeight(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(4)
                
                if let rating = imdbRating {
                    Text(String(format: "%.1f", rating))
                        .font(.subheadline)
                        .fontWeight(.bold)
                    if let votes = imdbVoteCount, votes > 0 {
                        Text("(\(formatVotes(votes)) votes)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("N/A")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
            
            // TMDb Badge
            HStack(spacing: 6) {
                Text("TMDb")
                    .font(.caption2)
                    .fontWeight(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                
                if let rating = tmdbRating {
                    Text(String(format: "%.1f", rating))
                        .font(.subheadline)
                        .fontWeight(.bold)
                } else {
                    Text("N/A")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.3), lineWidth: 1))
            
            // Trakt Badge
            HStack(spacing: 6) {
                Text("Trakt")
                    .font(.caption2)
                    .fontWeight(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                
                if let rating = traktRating {
                    Text(String(format: "%.1f", rating))
                        .font(.subheadline)
                        .fontWeight(.bold)
                } else {
                    Text("N/A")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
        }
    }
    
    private func formatVotes(_ votes: Int) -> String {
        if votes >= 1_000_000 {
            return String(format: "%.1fM", Double(votes) / 1_000_000.0)
        } else if votes >= 1_000 {
            return String(format: "%.1fK", Double(votes) / 1_000.0)
        } else {
            return "\(votes)"
        }
    }
}
