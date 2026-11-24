# The Movies

A native iOS app for browsing movies from [TMDB](https://www.themoviedb.org/): pick a genre, discover movies with endless scrolling, open a movie's details, read user reviews and watch YouTube trailers.

Built with **SwiftUI** on **iOS 26** using the **VIPER** architecture and Swift 6 strict concurrency.

## Features

- **Genres:** official TMDB movie genres as a colourful grid, with search.
- **Discover by genre:** endless scrolling grid with Popular / Top Rated / Newest / Box Office sorting.
- **Search by movie name:** debounced live search with highlighted matches.
- **Movie details:** stretchy backdrop, animated score ring, genres, overview, cast, facts.
- **Reviews:** endless scrolling list with expandable long reviews.
- **Trailers:** in-app YouTube player with a playlist of all trailers and clips.
- **Landscape:** a Cover Flow–inspired 3D poster flow on iPhone.
- **Light & Dark mode:** plus a System / Light / Dark switch in Settings.
- **App icon:** built with Icon Composer (default, dark, clear and tinted looks).
- **Every screen has loading, empty and error states.** Networking and decoding run off the main thread, so the UI never freezes.

## Requirements

- Xcode 27 (the project uses the Xcode 27 `project.xcproj` format)
- iOS 26.0 or later
- A free [TMDB API key](https://www.themoviedb.org/settings/api) (v3 key or v4 read access token)

## Getting started

1. Open `TheMovies.xcodeproj` and run the **TheMovies** scheme.
2. On first launch, paste your TMDB key. It is validated with TMDB and stored in the Keychain.

No key? Tap **Explore with demo data** to use built-in offline sample data.

You can also provide the key through the `TMDB_API_KEY` environment variable in the scheme, or launch with the `-demo` argument.

## Architecture

Each screen is a VIPER module in `TheMovies/Modules/<Name>/`:

| Layer | Role |
|---|---|
| **View** | SwiftUI view that renders presenter state and forwards user intent |
| **Presenter** | `@Observable` class that turns data into view state (loading / loaded / empty / error) |
| **Interactor** | Business logic and data access through the `MovieRepository` protocol |
| **Router** | Navigation via a shared `Navigator` (push routes and sheets) |
| **Entity** | `Sendable` models in `TheMovies/Core/Models` |

Other folders:

- `Core/`: networking (`TMDBAPIClient`, typed `APIError`), repository, pagination, Keychain storage.
- `DesignSystem/`: theme tokens, motion and reusable animated components.

Third-party packages: [Nuke](https://github.com/kean/Nuke) for image loading and caching, and [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit) for trailers.

## Tests

```sh
xcodebuild test -scheme TheMovies -destination 'platform=iOS Simulator,name=iPhone 17'
```

- **Unit tests** (Swift Testing) cover the API client, decoding, pagination, presenters, interactors, routers and session handling. Each covers positive and negative cases.
- **UI tests** (XCTest) cover end-to-end flows using deterministic stub scenarios: browsing, endless scrolling, search, trailers, landscape, offline errors, empty states, load-more failures and invalid API keys.

## Attribution

This product uses the TMDB API but is not endorsed or certified by TMDB.
