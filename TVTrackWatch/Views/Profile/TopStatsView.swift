import SwiftUI

public struct PersonStatCardView: View {
    public let stat: PersonStat
    public let accentColor: Color
    public let action: () -> Void
    @State private var profileURL: URL?
    
    public init(stat: PersonStat, accentColor: Color, action: @escaping () -> Void = {}) {
        self.stat = stat
        self.accentColor = accentColor
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            GlassCardView {
                HStack(spacing: 12) {
                    // Celebrity Photo Avatar from TMDb API
                    if let url = profileURL {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(accentColor.opacity(0.2))
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(accentColor.opacity(0.5), lineWidth: 1.5))
                    } else {
                        Circle()
                            .fill(accentColor.opacity(0.25))
                            .frame(width: 46, height: 46)
                            .overlay(
                                Text(String(stat.name.prefix(1)).uppercased())
                                    .font(.headline).fontWeight(.black)
                                    .foregroundColor(accentColor)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stat.name)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(stat.role)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(stat.count) titles")
                        .font(.caption2)
                        .fontWeight(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.3))
                        .foregroundColor(accentColor)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(accentColor.opacity(0.4), lineWidth: 1))
                }
                .padding(.vertical, 4)
            }
        }
        .task {
            profileURL = await TMDbService.shared.fetchPersonProfileURL(name: stat.name)
        }
    }
}

public struct TopStatsView: View {
    public let topActors: [PersonStat]
    public let topDirectors: [PersonStat]
    
    @State private var actorDisplayLimit = 4
    @State private var directorDisplayLimit = 4
    @State private var selectedPersonName: String? = nil
    
    public init(topActors: [PersonStat], topDirectors: [PersonStat]) {
        self.topActors = topActors.filter { $0.count >= 4 }
        self.topDirectors = topDirectors.filter { $0.count >= 4 }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Top Cast & Director Stats")
                .font(.title2).fontWeight(.black)
                .padding(.horizontal)
            
            if topActors.isEmpty && topDirectors.isEmpty {
                GlassCardView {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 38))
                            .foregroundColor(.gray)
                        Text("Not enough watch history yet.")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Top actors and directors will appear here once you watch 4+ movies or TV shows featuring them.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .padding(.horizontal)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    // Top Actors Column
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Top Actors")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("(\(topActors.count))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        let visibleActors = Array(topActors.prefix(actorDisplayLimit))
                        ForEach(visibleActors) { stat in
                            PersonStatCardView(stat: stat, accentColor: .blue) {
                                selectedPersonName = stat.name
                            }
                            .onAppear {
                                if stat.id == visibleActors.last?.id && actorDisplayLimit < topActors.count {
                                    withAnimation {
                                        actorDisplayLimit += 4
                                    }
                                }
                            }
                        }
                        
                        if actorDisplayLimit < topActors.count {
                            Button(action: {
                                withAnimation {
                                    actorDisplayLimit += 4
                                }
                            }) {
                                HStack {
                                    Text("Show More (\(topActors.count - actorDisplayLimit) remaining)")
                                    Image(systemName: "chevron.down")
                                }
                                .font(.caption).fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Top Directors Column
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Top Directors")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Spacer()
                            Text("(\(topDirectors.count))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        let visibleDirectors = Array(topDirectors.prefix(directorDisplayLimit))
                        ForEach(visibleDirectors) { stat in
                            PersonStatCardView(stat: stat, accentColor: .purple) {
                                selectedPersonName = stat.name
                            }
                            .onAppear {
                                if stat.id == visibleDirectors.last?.id && directorDisplayLimit < topDirectors.count {
                                    withAnimation {
                                        directorDisplayLimit += 4
                                    }
                                }
                            }
                        }
                        
                        if directorDisplayLimit < topDirectors.count {
                            Button(action: {
                                withAnimation {
                                    directorDisplayLimit += 4
                                }
                            }) {
                                HStack {
                                    Text("Show More (\(topDirectors.count - directorDisplayLimit) remaining)")
                                    Image(systemName: "chevron.down")
                                }
                                .font(.caption).fontWeight(.bold)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.purple.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }
        }
        .sheet(item: Binding(
            get: { selectedPersonName.map { PersonNameItem(name: $0) } },
            set: { selectedPersonName = $0?.name }
        )) { item in
            PersonDetailView(personName: item.name)
        }
    }
}

public struct PersonNameItem: Identifiable {
    public var id: String { name }
    public let name: String
}

