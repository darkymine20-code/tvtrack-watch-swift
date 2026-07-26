import SwiftUI

public struct RatingWidgetView: View {
    public let userRating: Double?
    public let onRatingSelected: (Double) -> Void
    
    @State private var hoveredStar: Int? = nil
    
    public init(userRating: Double?, onRatingSelected: @escaping (Double) -> Void) {
        self.userRating = userRating
        self.onRatingSelected = onRatingSelected
    }
    
    public var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    
                    Text("Rate Movie / TV Show (10-Star Scale)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let rating = userRating, rating > 0 {
                        HStack(spacing: 4) {
                            Text("★ \(String(format: "%.0f", rating))/10")
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                    } else {
                        Text("Unrated")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack(spacing: 8) {
                    ForEach(1...10, id: \.self) { star in
                        Button(action: {
                            onRatingSelected(Double(star))
                        }) {
                            Image(systemName: starImageName(for: star))
                                .font(.title2)
                                .foregroundColor(starColor(for: star))
                                .shadow(color: starColor(for: star).opacity(0.6), radius: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if let rating = userRating, rating > 0 {
                        Spacer()
                        Button(action: {
                            onRatingSelected(0.0)
                        }) {
                            Image(systemName: "xmark.circle")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(12)
        }
    }
    
    private func starImageName(for star: Int) -> String {
        let activeRating = Double(hoveredStar ?? Int(userRating ?? 0))
        return Double(star) <= activeRating ? "star.fill" : "star"
    }
    
    private func starColor(for star: Int) -> Color {
        let activeRating = Double(hoveredStar ?? Int(userRating ?? 0))
        return Double(star) <= activeRating ? .yellow : .gray.opacity(0.35)
    }
}
