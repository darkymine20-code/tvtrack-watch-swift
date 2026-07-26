import SwiftUI

public struct PersonDetailView: View {
    public let personName: String
    public let personId: Int?
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = DataManager.shared
    
    @State private var personDetails: TMDbPersonDetails? = nil
    @State private var combinedCredits: [TMDbMediaItem] = []
    @State private var isLoading = true
    @State private var selectedFilter: CreditFilter = .all
    @State private var selectedMediaItem: TMDbMediaItem? = nil
    
    public enum CreditFilter: String, CaseIterable, Identifiable {
        case all = "All Works"
        case movies = "Movies"
        case tv = "TV Shows"
        case watched = "Watched by You"
        
        public var id: String { rawValue }
    }
    
    public init(personName: String, personId: Int? = nil) {
        self.personName = personName
        self.personId = personId
    }
    
    private var filteredCredits: [TMDbMediaItem] {
        switch selectedFilter {
        case .all:
            return combinedCredits
        case .movies:
            return combinedCredits.filter { $0.mediaType == "movie" }
        case .tv:
            return combinedCredits.filter { $0.mediaType == "tv" }
        case .watched:
            return combinedCredits.filter { item in
                dataManager.items[item.id]?.isWatched == true
            }
        }
    }
    
    private var watchedCount: Int {
        combinedCredits.filter { item in
            dataManager.items[item.id]?.isWatched == true
        }.count
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Loading filmography for \(personName)...")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Header Person Summary
                            GlassCardView {
                                HStack(spacing: 20) {
                                    if let profileURL = personDetails?.profileURL {
                                        AsyncImage(url: profileURL) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle().fill(Color.purple.opacity(0.3))
                                        }
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.purple.opacity(0.6), lineWidth: 2))
                                    } else {
                                        Circle()
                                            .fill(Color.purple.opacity(0.3))
                                            .frame(width: 90, height: 90)
                                            .overlay(
                                                Text(String(personName.prefix(1)).uppercased())
                                                    .font(.title).fontWeight(.black)
                                                    .foregroundColor(.purple)
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(personDetails?.name ?? personName)
                                            .font(.title)
                                            .fontWeight(.black)
                                            .foregroundColor(.white)
                                        
                                        if let dept = personDetails?.knownForDepartment {
                                            Text("Known For: \(dept)")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.purple)
                                        }
                                        
                                        if let birth = personDetails?.birthday {
                                            Text("Born: \(birth)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        HStack(spacing: 12) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "film.stack.fill")
                                                    .foregroundColor(.blue)
                                                Text("\(combinedCredits.count) Total Works")
                                            }
                                            .font(.caption).fontWeight(.bold)
                                            
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                Text("\(watchedCount) Watched")
                                            }
                                            .font(.caption).fontWeight(.bold)
                                        }
                                        .padding(.top, 4)
                                    }
                                    Spacer()
                                }
                                .padding()
                            }
                            .padding(.horizontal)
                            
                            // Biography Section
                            if let bio = personDetails?.biography, !bio.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Biography")
                                        .font(.title3).fontWeight(.black)
                                        .foregroundColor(.white)
                                    Text(bio)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .lineLimit(4)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Filmography Category Filter Selector
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Combined Filmography")
                                        .font(.title3).fontWeight(.black)
                                        .foregroundColor(.white)
                                    Text("(\(filteredCredits.count))")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(CreditFilter.allCases) { filter in
                                            Button(action: { selectedFilter = filter }) {
                                                Text(filter.rawValue)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(selectedFilter == filter ? Color.purple : Color.white.opacity(0.1))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(10)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Grid of Combined Movies + TV Shows
                                if filteredCredits.isEmpty {
                                    GlassCardView {
                                        VStack(spacing: 8) {
                                            Image(systemName: "tray")
                                                .font(.largeTitle).foregroundColor(.gray)
                                            Text("No titles found for \(selectedFilter.rawValue).")
                                                .font(.headline).foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                    }
                                    .padding(.horizontal)
                                } else {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                                        ForEach(filteredCredits) { item in
                                            Button(action: { selectedMediaItem = item }) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    ZStack(alignment: .topTrailing) {
                                                        if let path = item.posterPath, let url = URL(string: "\(AppConfig.tmdbImageBaseURL)\(path)") {
                                                            AsyncImage(url: url) { img in
                                                                img.resizable().aspectRatio(contentMode: .fill)
                                                            } placeholder: {
                                                                Rectangle().fill(Color.gray.opacity(0.3))
                                                            }
                                                            .frame(height: 200)
                                                            .cornerRadius(10)
                                                            .clipped()
                                                        } else {
                                                            Rectangle()
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(height: 200)
                                                                .cornerRadius(10)
                                                        }
                                                        
                                                        // Media Type Badge ("MOVIE" / "TV")
                                                        Text((item.mediaType ?? "movie").uppercased())
                                                            .font(.system(size: 9, weight: .black))
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 3)
                                                            .background(item.mediaType == "tv" ? Color.green : Color.blue)
                                                            .foregroundColor(.white)
                                                            .cornerRadius(4)
                                                            .padding(6)
                                                        
                                                        // User Watched Checkmark Overlay
                                                        if dataManager.items[item.id]?.isWatched == true {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .foregroundColor(.green)
                                                                .background(Circle().fill(Color.black))
                                                                .padding(6)
                                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                                        }
                                                    }
                                                    
                                                    Text(item.displayTitle)
                                                        .font(.caption).fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                    
                                                    HStack {
                                                        Text(item.releaseYear)
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                        Spacer()
                                                        if let rating = item.voteAverage, rating > 0 {
                                                            HStack(spacing: 2) {
                                                                Image(systemName: "star.fill")
                                                                    .font(.system(size: 8))
                                                                    .foregroundColor(.yellow)
                                                                Text(String(format: "%.1f", rating))
                                                                    .font(.caption2)
                                                                    .foregroundColor(.white)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle(personName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedMediaItem) { item in
                if item.mediaType == "tv" {
                    TVShowDetailsView(show: item)
                } else {
                    MovieDetailsView(movie: item)
                }
            }
            .task {
                await loadPersonData()
            }
        }
    }
    
    private func loadPersonData() async {
        isLoading = true
        var targetId = personId
        if targetId == nil {
            targetId = await TMDbService.shared.findPersonIdByName(name: personName)
        }
        
        if let id = targetId {
            do {
                let details = try await TMDbService.shared.fetchPersonDetails(personId: id)
                let credits = try await TMDbService.shared.fetchPersonCombinedCredits(personId: id)
                await MainActor.run {
                    self.personDetails = details
                    self.combinedCredits = credits
                    self.isLoading = false
                }
            } catch {
                print("Error loading details for person \(id): \(error)")
                await MainActor.run { self.isLoading = false }
            }
        } else {
            await MainActor.run { self.isLoading = false }
        }
    }
}
