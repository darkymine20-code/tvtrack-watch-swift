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

public struct TraktComment: Codable, Identifiable {
    public let id: Int
    public let comment: String
    public let spoiler: Bool
    public let review: Bool
    public let rating: Double?
    public let likes: Int
    case createdAt = "created_at"
    public let user: TraktUser
    
    public var formattedDate: String {
        let dateStr = createdAt
        return String(dateStr.prefix(10))
    }
    
    enum CodingKeys: String, CodingKey {
        case id, comment, spoiler, review, rating, likes, user
        case createdAt = "created_at"
    }
}

public struct TraktUser: Codable {
    public let username: String
    public let name: String?
    public let vip: Bool?
}

public struct TraktRatingSummary: Codable {
    public let rating: Double
    public let votes: Int
    public let distribution: [String: Int]?
}
