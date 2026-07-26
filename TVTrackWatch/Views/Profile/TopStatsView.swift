import SwiftUI

public struct TopStatsView: View {
    public let topActors: [PersonStat]
    public let topDirectors: [PersonStat]
    
    public init(topActors: [PersonStat], topDirectors: [PersonStat]) {
        self.topActors = topActors
        self.topDirectors = topDirectors
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Top Cast & Director Stats")
                .font(.title2).fontWeight(.bold)
                .padding(.horizontal)
            
            if topActors.isEmpty && topDirectors.isEmpty {
                GlassCardView {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Not enough watch history yet.")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Top actors and directors will appear here once you watch 3+ movies or TV shows featuring them.")
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
                        Text("Top Actors")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        ForEach(topActors) { stat in
                            GlassCardView {
                                HStack {
                                    Text(stat.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(stat.count) titles")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.3))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Top Directors Column
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Directors")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        ForEach(topDirectors) { stat in
                            GlassCardView {
                                HStack {
                                    Text(stat.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(stat.count) titles")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.3))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }
        }
    }
}
