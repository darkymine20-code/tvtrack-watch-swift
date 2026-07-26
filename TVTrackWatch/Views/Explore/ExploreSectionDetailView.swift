import SwiftUI

public struct ExploreSectionDetailView: View {
    public let sectionTitle: String
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedMediaType = "all"
    @State private var items: [TMDbMediaItem] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var isLoadingMore = false
    
    public init(sectionTitle: String) {
        self.sectionTitle = sectionTitle
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Section Sub-header & Filter Bar
                VStack(spacing: 12) {
                    Picker("Media Type", selection: $selectedMediaType) {
                        Text("✨ All Catalog").tag("all")
                        Text("🎬 Movies Only").tag("movie")
                        Text("📺 TV Shows Only").tag("tv")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedMediaType) { _ in
                        currentPage = 1
                        loadPage(1, append: false)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.6))
                
                if isLoading && items.isEmpty {
                    Spacer()
                    ProgressView("Loading catalog for \(sectionTitle)...")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Spacer()
                } else if items.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No titles found in this catalog.")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("\(items.count) Titles Loaded")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Page \(currentPage) of \(totalPages)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 18)], spacing: 18) {
                                ForEach(items) { item in
                                    MediaCardCell(item: item)
                                        .onAppear {
                                            if item.id == items.last?.id && currentPage < totalPages && !isLoadingMore {
                                                loadNextPage()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                            
                            if isLoadingMore {
                                HStack {
                                    ProgressView()
                                    Text("Loading More Titles...")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle(sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                if items.isEmpty {
                    loadPage(1, append: false)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func loadPage(_ page: Int, append: Bool) {
        if append {
            isLoadingMore = true
        } else {
            isLoading = true
        }
        
        Task {
            do {
                let res = try await TMDbService.shared.fetchSectionMediaPaginated(
                    section: sectionTitle,
                    mediaType: selectedMediaType,
                    page: page
                )
                DispatchQueue.main.async {
                    if append {
                        self.items.append(contentsOf: res.items)
                    } else {
                        self.items = res.items
                    }
                    self.totalPages = res.totalPages
                    self.currentPage = page
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.isLoadingMore = false
                }
            }
        }
    }
    
    private func loadNextPage() {
        guard currentPage < totalPages && !isLoadingMore else { return }
        loadPage(currentPage + 1, append: true)
    }
}
