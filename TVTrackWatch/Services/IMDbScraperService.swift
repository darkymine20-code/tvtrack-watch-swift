import Foundation

public final class IMDbScraperService: ObservableObject {
    public static let shared = IMDbScraperService()
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Replicating download_movie_info.py logic natively in Swift
    public func fetchIMDbInfo(imdbId: String) async throws -> IMDbInfo? {
        guard let url = URL(string: "https://www.imdb.com/title/\(imdbId)/") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        
        // Regex to extract <script type="application/ld+json">
        let pattern = "<script type=\"application/ld\\+json\">\\s*(\\{.*?\\})\\s*</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        let jsonString = String(html[range])
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        let title = jsonObj["name"] as? String
        let description = jsonObj["description"] as? String
        let aggRatingObj = jsonObj["aggregateRating"] as? [String: Any]
        let rating = aggRatingObj?["ratingValue"] as? Double ?? (aggRatingObj?["ratingValue"] as? String).flatMap { Double($0) }
        let voteCount = aggRatingObj?["ratingCount"] as? Int
        
        let genreList = jsonObj["genre"] as? [String] ?? []
        let actorObjects = jsonObj["actor"] as? [[String: Any]] ?? []
        let actors = actorObjects.compactMap { $0["name"] as? String }
        let directorObjects = jsonObj["director"] as? [[String: Any]] ?? []
        let directors = directorObjects.compactMap { $0["name"] as? String }
        
        return IMDbInfo(
            id: imdbId,
            title: title,
            description: description,
            rating: rating,
            voteCount: voteCount,
            genres: genreList,
            directors: directors,
            actors: actors
        )
    }
    
    // MARK: - Replicating reviews.py logic natively in Swift via IMDb GraphQL
    public func fetchIMDbReviews(imdbId: String, limit: Int = 10) async throws -> [IMDbReviewItem] {
        guard let url = URL(string: "https://caching.graphql.imdb.com/") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.imdb.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let query = """
        query TitleReviewsRefine($const: ID!, $first: Int!) {
          title(id: $const) {
            reviews(first: $first, sort: {by: HELPFULNESS_SCORE, order: DESC}) {
              edges {
                node {
                  id
                  author { nickName }
                  authorRating
                  helpfulness { upVotes downVotes }
                  submissionDate
                  text { originalText { plainText } }
                  summary { originalText }
                }
              }
            }
          }
        }
        """
        
        let payload: [String: Any] = [
            "query": query,
            "operationName": "TitleReviewsRefine",
            "variables": [
                "const": imdbId,
                "first": limit
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await session.data(for: request)
        
        guard let jsonResult = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = jsonResult["data"] as? [String: Any],
              let titleDict = dataDict["title"] as? [String: Any],
              let reviewsDict = titleDict["reviews"] as? [String: Any],
              let edges = reviewsDict["edges"] as? [[String: Any]] else {
            return []
        }
        
        var reviewsList: [IMDbReviewItem] = []
        for edge in edges {
            guard let node = edge["node"] as? [String: Any] else { continue }
            let id = node["id"] as? String ?? UUID().uuidString
            let authorObj = node["author"] as? [String: Any]
            let author = authorObj?["nickName"] as? String ?? "Anonymous"
            let authorRating = node["authorRating"] as? Double
            let summaryObj = node["summary"] as? [String: Any]
            let summary = summaryObj?["originalText"] as? String ?? ""
            let textObj = node["text"] as? [String: Any]
            let origTextObj = textObj?["originalText"] as? [String: Any]
            let text = origTextObj?["plainText"] as? String ?? ""
            let helpfulness = node["helpfulness"] as? [String: Any]
            let upVotes = helpfulness?["upVotes"] as? Int ?? 0
            let downVotes = helpfulness?["downVotes"] as? Int ?? 0
            let submissionDate = node["submissionDate"] as? String ?? ""
            
            reviewsList.append(
                IMDbReviewItem(
                    id: id,
                    author: author,
                    authorRating: authorRating,
                    summary: summary,
                    text: text,
                    upVotes: upVotes,
                    downVotes: downVotes,
                    submissionDate: submissionDate
                )
            )
        }
        
        return reviewsList
    }
}
