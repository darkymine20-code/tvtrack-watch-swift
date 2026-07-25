import SwiftUI

public struct iPadMainNavigationView: View {
    @State private var selectedSection: NavigationSection = .tvShows
    
    public enum NavigationSection: String, CaseIterable, Identifiable {
        case tvShows = "TV Shows"
        case movies = "Movies"
        case explore = "Explore"
        case profile = "Profile"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .tvShows: return "tv.fill"
            case .movies: return "film.fill"
            case .explore: return "safari.fill"
            case .profile: return "person.crop.circle.fill"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top iPad Bar Navigation Header
                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.tv.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text("tvtrack+ watch")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // 4 Primary Top Navigation Buttons Optimized for Tablet Screen Real Estate
                    HStack(spacing: 8) {
                        ForEach(NavigationSection.allCases) { section in
                            Button(action: {
                                selectedSection = section
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: section.iconName)
                                    Text(section.rawValue)
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedSection == section ? Color.blue : Color.white.opacity(0.08))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                
                Divider().background(Color.white.opacity(0.1))
                
                // Primary Section Body Content
                Group {
                    switch selectedSection {
                    case .tvShows:
                        TVShowsWatchlistView()
                    case .movies:
                        MoviesWatchlistView()
                    case .explore:
                        ExploreView()
                    case .profile:
                        ProfileView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.08, blue: 0.12), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }
}
