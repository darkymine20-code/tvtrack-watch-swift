# tvtrack+ watch (iPadOS Swift / SwiftUI)

**tvtrack+ watch** is a native iPadOS media tracking and streaming application built with **Swift 5.10**, **SwiftUI**, and modern tablet UI design patterns.

## 📱 iPadOS Architecture Highlights

### 1. API Configurations & Data Architecture
- **TMDb API Integration**: Used as the primary metadata engine for posters, backdrops, synopses, cast/crew details, and episode release schedules.
- **Trakt API Integration**: Public discovery feeds (*Trending*, *Most Watched*, *Favorites*, *Anticipated*, *Popular*) and public community comments/reviews.
- **Local Storage Layer**: On-device persistent store (`DataManager`) managing local watchlists, 10-star user ratings, watch history, playback progress, and favorites.

### 2. IMDb Scraper & Streaming Server Engine
- **Native Swift IMDb Service**: Replicates the functionality of `download_movie_info.py` and `reviews.py` natively in Swift by parsing IMDb JSON-LD metadata and querying IMDb GraphQL (`TitleReviewsRefine`) for user reviews.
- **Streaming Servers Selector**: Integrated `WKWebView` player wrapper supporting `STREAMING_SERVERS` endpoints (`vidking.net` embeds) with an interactive server selector dropdown.

### 3. iPad Top Navigation & Section Architecture
- **Section 1: TV Shows**
  - **Tab A: Watchlist** divided into 4 sub-sections:
    1. *Watch Next* (Shows with unwatched episodes available)
    2. *Not Watched for 30+ Days* (Shows with last activity > 30 days ago)
    3. *Waiting for New Episodes* (Fully caught up, awaiting future release dates)
    4. *Have Not Started* (Saved with 0 episodes watched)
  - **Tab B: Upcoming Calendar**: Release calendar for shows in your watchlist.
- **Section 2: Movies**: Grid/List view of saved movies.
- **Section 3: Explore**: Search hub with filter bar (Genre, Year, Rating, Platform), Trakt public carousels, and personalized *Recommended For You* algorithmic feed.
- **Section 4: Profile**: Dashboard counters, Favorite collections, "Stopped Watching" archive, and Top Cast & Director stats (ranked list of actors/directors with >= 4 watched items).

### 4. Detailed Layouts
- **Movie Details Page**: Hero backdrop, quick action buttons (`+ Watchlist`, `♥ Favorite`, `✓ Watched`, `▶ Watch Now`), 10-star rating widget, 3-way ratings bar (IMDb + votes, TMDb, Trakt), YouTube trailer deep-link, and community comments.
- **TV Show Details Page**: Season selector dropdown, episode cards displaying thumbnails, air dates, local Watched checkmark toggles (`✓`), and direct episode Play buttons (`▶`).

---

## 🛠 Building & CI/CD Pipeline

The project includes a complete **GitHub Actions Workflow** (`.github/workflows/build-ios.yml`) that compiles the Swift package on `macos-14` with Xcode 15/16 and runs all unit tests automatically upon pushing to GitHub.
