import SwiftUI

public struct RatingWidgetView: View {
    @Binding public var currentRating: Double?
    public let onRatingSelected: (Double) -> Void
    
    public init(currentRating: Binding<Double?>, onRatingSelected: @escaping (Double) -> Void) {
        self._currentRating = currentRating
        self.onRatingSelected = onRatingSelected
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your Rating (10-Star Scale)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { star in
                    Image(systemName: starImageName(for: star))
                        .foregroundColor(starColor(for: star))
                        .font(.title3)
                        .onTapGesture {
                            let newRating = Double(star)
                            currentRating = newRating
                            onRatingSelected(newRating)
                        }
                }
                
                if let rating = currentRating {
                    Text(String(format: "%.0f/10", rating))
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding(.leading, 8)
                }
            }
        }
    }
    
    private func starImageName(for star: Int) -> String {
        guard let rating = currentRating else { return "star" }
        return Double(star) <= rating ? "star.fill" : "star"
    }
    
    private func starColor(for star: Int) -> Color {
        guard let rating = currentRating else { return .gray }
        return Double(star) <= rating ? .yellow : .gray.opacity(0.4)
    }
}
