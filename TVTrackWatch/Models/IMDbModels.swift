import Foundation

// MARK: - Native Swift IMDb Models (Matching download_movie_info.py & reviews.py)

public struct IMDbInfo: Codable {
    public let id: String
    public let title: String?
    public let description: String?
    public let rating: Double?
    public let voteCount: Int?
    public let genres: [String]
    public let directors: [String]
    public let actors: [String]
    
    public init(id: String, title: String?, description: String?, rating: Double?, voteCount: Int?, genres: [String], directors: [String], actors: [String]) {
        self.id = id
        self.title = title
        self.description = description
        self.rating = rating
        self.voteCount = voteCount
        self.genres = genres
        self.directors = directors
        self.actors = actors
    }
}

public struct IMDbReviewItem: Codable, Identifiable {
    public let id: String
    public let author: String
    public let authorRating: Double?
    public let summary: String
    public let text: String
    public let upVotes: Int
    public let downVotes: Int
    public let submissionDate: String
    
    public init(id: String, author: String, authorRating: Double?, summary: String, text: String, upVotes: Int, downVotes: Int, submissionDate: String) {
        self.id = id
        self.author = author
        self.authorRating = authorRating
        self.summary = summary
        self.text = text
        self.upVotes = upVotes
        self.downVotes = downVotes
        self.submissionDate = submissionDate
    }
}
