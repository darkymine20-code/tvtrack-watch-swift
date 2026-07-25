import SwiftUI

public struct FilterSheetView: View {
    @Binding var selectedGenreId: Int?
    @Binding var selectedYear: String
    @Binding var minRating: Double
    @Binding var mediaType: String // "movie" or "tv"
    
    @Environment(\.dismiss) var dismiss
    
    public init(selectedGenreId: Binding<Int?>, selectedYear: Binding<String>, minRating: Binding<Double>, mediaType: Binding<String>) {
        self._selectedGenreId = selectedGenreId
        self._selectedYear = selectedYear
        self._minRating = minRating
        self._mediaType = mediaType
    }
    
    private let genres: [(id: Int, name: String)] = [
        (28, "Action"), (12, "Adventure"), (16, "Animation"), (35, "Comedy"),
        (80, "Crime"), (99, "Documentary"), (18, "Drama"), (14, "Fantasy"),
        (27, "Horror"), (9648, "Mystery"), (10749, "Romance"), (878, "Sci-Fi")
    ]
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Type")) {
                    Picker("Media Type", selection: $mediaType) {
                        Text("Movies").tag("movie")
                        Text("TV Shows").tag("tv")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Genre")) {
                    Picker("Select Genre", selection: $selectedGenreId) {
                        Text("All Genres").tag(Int?.none)
                        ForEach(genres, id: \.id) { genre in
                            Text(genre.name).tag(Int?.some(genre.id))
                        }
                    }
                }
                
                Section(header: Text("Release Year")) {
                    let field = TextField("e.g. 2026", text: $selectedYear)
                    #if os(iOS)
                    field.keyboardType(.numberPad)
                    #else
                    field
                    #endif
                }
                
                Section(header: Text("Minimum Rating")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Rating: \(String(format: "%.1f", minRating))+")
                            Spacer()
                        }
                        Slider(value: $minRating, in: 0...10, step: 0.5)
                    }
                }
            }
            .navigationTitle("Filter Catalog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedGenreId = nil
                        selectedYear = ""
                        minRating = 0.0
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dismiss()
                    }
                }
            }
        }
    }
}
