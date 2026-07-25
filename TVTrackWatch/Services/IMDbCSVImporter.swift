import Foundation

public struct IMDbImportResult {
    public let totalParsed: Int
    public let importedMovies: Int
    public let importedTVShows: Int
    public let failedCount: Int
}

public final class IMDbCSVImporter {
    public static let shared = IMDbCSVImporter()
    
    private init() {}
    
    public func importCSVData(
        _ content: String,
        progressHandler: @escaping (Int, Int, String) -> Void
    ) async -> IMDbImportResult {
        let lines = parseCSVRows(content)
        guard lines.count > 1 else {
            return IMDbImportResult(totalParsed: 0, importedMovies: 0, importedTVShows: 0, failedCount: 0)
        }
        
        let headers = lines[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Locate column indices
        let constIndex = headers.firstIndex(where: { $0.caseInsensitiveCompare("Const") == .orderedSame }) ?? 0
        let ratingIndex = headers.firstIndex(where: { $0.caseInsensitiveCompare("Your Rating") == .orderedSame }) ?? 1
        let dateRatedIndex = headers.firstIndex(where: { $0.caseInsensitiveCompare("Date Rated") == .orderedSame })
        let titleIndex = headers.firstIndex(where: { $0.caseInsensitiveCompare("Title") == .orderedSame })
        let titleTypeIndex = headers.firstIndex(where: { $0.caseInsensitiveCompare("Title Type") == .orderedSame })
        
        var importedMovies = 0
        var importedTVShows = 0
        var failedCount = 0
        
        let rows = Array(lines.dropFirst())
        let total = rows.count
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for (index, row) in rows.enumerated() {
            guard row.count > constIndex else { continue }
            let imdbId = row[constIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard imdbId.hasPrefix("tt") else { continue }
            
            let rawRating = row.count > ratingIndex ? row[ratingIndex] : ""
            let rating = Double(rawRating.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
            
            let title = (titleIndex != nil && row.count > titleIndex!) ? row[titleIndex!] : ""
            let titleType = (titleTypeIndex != nil && row.count > titleTypeIndex!) ? row[titleTypeIndex!] : ""
            
            var dateRated: Date? = nil
            if let dIdx = dateRatedIndex, row.count > dIdx {
                let dStr = row[dIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                dateRated = dateFormatter.date(from: dStr)
            }
            
            progressHandler(index + 1, total, title.isEmpty ? imdbId : title)
            
            do {
                var tmdbItem = try await TMDbService.shared.fetchByIMDbId(imdbId: imdbId)
                
                // Fallback search if find by IMDb ID is unavailable
                if tmdbItem == nil && !title.isEmpty {
                    let searchRes = try await TMDbService.shared.searchMedia(query: title)
                    tmdbItem = searchRes.first
                }
                
                if let item = tmdbItem {
                    let isTV = (item.mediaType == "tv" || titleType.lowercased().contains("tv"))
                    let mediaType = isTV ? "tv" : "movie"
                    let key = "\(mediaType)_\(item.id)"
                    
                    var local = DataManager.shared.items[key] ?? LocalMediaItem(
                        tmdbId: item.id,
                        mediaType: mediaType,
                        title: item.displayTitle,
                        posterPath: item.posterPath,
                        backdropPath: item.backdropPath,
                        voteAverage: item.voteAverage,
                        releaseDate: item.releaseDate ?? item.firstAirDate
                    )
                    
                    local.isWatched = true
                    if rating > 0 {
                        local.userRating = rating
                    }
                    if let date = dateRated {
                        local.lastWatchedDate = date
                    } else if local.lastWatchedDate == nil {
                        local.lastWatchedDate = Date()
                    }
                    
                    DataManager.shared.items[key] = local
                    
                    if isTV {
                        importedTVShows += 1
                    } else {
                        importedMovies += 1
                    }
                } else {
                    failedCount += 1
                }
            } catch {
                failedCount += 1
            }
            
            // Respect API rate limits
            try? await Task.sleep(nanoseconds: 80_000_000) // 80ms delay
        }
        
        // Save to disk
        let data = try? JSONEncoder().encode(DataManager.shared.items)
        if let d = data {
            UserDefaults.standard.set(d, forKey: "tvtrack_local_media_items_v1")
        }
        
        return IMDbImportResult(
            totalParsed: total,
            importedMovies: importedMovies,
            importedTVShows: importedTVShows,
            failedCount: failedCount
        )
    }
    
    // Standard CSV line parser supporting quoted strings
    private func parseCSVRows(_ text: String) -> [[String]] {
        var results: [[String]] = []
        var currentField = ""
        var currentRow: [String] = []
        var insideQuotes = false
        
        for char in text {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if (char == "\n" || char == "\r") && !insideQuotes {
                if !currentField.isEmpty || !currentRow.isEmpty {
                    currentRow.append(currentField)
                    results.append(currentRow)
                    currentRow = []
                    currentField = ""
                }
            } else {
                currentField.append(char)
            }
        }
        
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            results.append(currentRow)
        }
        
        return results
    }
}
