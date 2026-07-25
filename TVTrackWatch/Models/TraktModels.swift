import Foundation

// MARK: - Trakt Discovery & Comment Models

public struct TraktTrendingShow: Codable, Identifiable {
    public var id: Int { show.ids.trakt }
    public let watchers: Int
    public let show: TraktShow
}

public struct TraktTrendingMovie: Codable, Identifiable {
    public var id: Int { movie.ids.trakt }
    public let watchers: Int
    public let movie: TraktMovie
}

public struct TraktShow: Codable, Identifiable {
    public var id: Int { ids.trakt }
    public let title: String
    public let year: Int?
    public let ids: TraktIds
}

public struct TraktMovie: Codable, Identifiable {
    public var id: Int { ids.trakt }
    public let title: String
    public let year: Int?
    public let ids: TraktIds
}

public struct TraktIds: Codable {
    public let trakt: Int
    public let slug: String?
    public let tvdb: Int?
    public let imdb: String?
    public let tmdb: Int?
}

// Fix 2: Trakt Comment with Emoji Reaction, Likes, and Replies Count
public struct TraktComment: Codable, Identifiable {
    public let id: Int
    public let comment: String
    public let spoiler: Bool
    public let review: Bool
    public let rating: Double?
    public let likes: Int
    public let replies: Int?
    public let createdAt: String
    public let user: TraktUser
    
    public var formattedDate: String {
        return String(createdAt.prefix(10))
    }
    
    public var reactionEmoji: String {
        guard let r = rating else { return "💬" }
        if r >= 9 { return "🔥" }
        if r >= 7.5 { return "👍" }
        if r >= 5.0 { return "🤔" }
        return "👎"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, comment, spoiler, review, rating, likes, replies, user
        case createdAt = "created_at"
    }
}

public struct TraktUser: Codable {
    public let username: String
    public let name: String?
    public let vip: Bool?
    public let images: TraktUserImages?
    
    public var avatarURL: URL? {
        if let full = images?.avatar?.full, let url = URL(string: full) {
            return url
        }
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "User"
        return URL(string: "https://api.dicebear.com/7.x/bottts/png?seed=\(encoded)")
    }
}

public struct TraktUserImages: Codable {
    public let avatar: TraktUserAvatar?
}

public struct TraktUserAvatar: Codable {
    public let full: String?
}

public struct TraktRatingSummary: Codable {
    public let rating: Double
    public let votes: Int
    public let distribution: [String: Int]?
}
