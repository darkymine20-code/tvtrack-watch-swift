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
        
        public var accentColor: Color {
            switch self {
            case .tvShows: return .blue
            case .movies: return .cyan
            case .explore: return .purple
            case .profile: return .indigo
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Vibrant Glassmorphic iPad Top Toolbar Header
                HStack(spacing: 24) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.tv.fill")
                            .font(.title)
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: .blue.opacity(0.6), radius: 8)
                        
                        Text("tvtrack+ watch")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(LinearGradient(colors: [.white, .cyan.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    }
                    
                    Spacer()
                    
                    // 4 Primary Top Navigation Segmented Pills
                    HStack(spacing: 8) {
                        ForEach(NavigationSection.allCases) { section in
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    selectedSection = section
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: section.iconName)
                                        .font(.subheadline)
                                    Text(section.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    ZStack {
                                        if selectedSection == section {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [section.accentColor, section.accentColor.opacity(0.7)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .shadow(color: section.accentColor.opacity(0.5), radius: 8)
                                        } else {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.06))
                                        }
                                    }
                                )
                                .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    #if os(iOS)
                    Rectangle().fill(.ultraThinMaterial).opacity(0.95)
                    #else
                    Color.black.opacity(0.8)
                    #endif
                )
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)),
                    alignment: .bottom
                )
                
                // Primary Section View Target
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
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Background Ambient Glow Orbs
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 500, height: 500)
                        .blur(radius: 90)
                        .offset(x: -200, y: -300)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 500, height: 500)
                        .blur(radius: 90)
                        .offset(x: 200, y: 300)
                }
            )
        }
    }
}
