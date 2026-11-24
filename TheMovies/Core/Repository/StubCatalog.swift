import Foundation

/// Synthetic, deterministic catalogue for demo mode and tests.
nonisolated enum StubCatalog {
    static let genres: [Genre] = [
        Genre(id: 28, name: "Action"), Genre(id: 12, name: "Adventure"),
        Genre(id: 16, name: "Animation"), Genre(id: 35, name: "Comedy"),
        Genre(id: 80, name: "Crime"), Genre(id: 99, name: "Documentary"),
        Genre(id: 18, name: "Drama"), Genre(id: 10751, name: "Family"),
        Genre(id: 14, name: "Fantasy"), Genre(id: 36, name: "History"),
        Genre(id: 27, name: "Horror"), Genre(id: 10402, name: "Music"),
        Genre(id: 9648, name: "Mystery"), Genre(id: 10749, name: "Romance"),
        Genre(id: 878, name: "Science Fiction"), Genre(id: 10770, name: "TV Movie"),
        Genre(id: 53, name: "Thriller"), Genre(id: 10752, name: "War"),
        Genre(id: 37, name: "Western"),
    ]

    private static let adjectives = [
        "Midnight", "Silent", "Crimson", "Electric", "Hidden", "Last", "Golden", "Broken",
        "Infinite", "Wild", "Neon", "Frozen", "Lost", "Velvet", "Iron", "Paper",
    ]
    private static let nouns = [
        "Horizon", "Echo", "Kingdom", "Signal", "Orchard", "Voyage", "Cipher", "Harbor",
        "Lantern", "Frontier", "Garden", "Machine", "Tide", "Atlas", "Mirage", "Comet",
    ]
    private static let reviewers = [
        ("Ava Chen", "avachen"), ("Marcus Reid", "mreid"), ("Sofia Alvarez", "sofi_a"),
        ("Kenji Watanabe", "kenjiw"), ("Priya Nair", "priyan"), ("Jonas Berg", "jberg"),
    ]
    /// Freely licensed Blender open movies hosted on YouTube.
    private static let openMovieKeys = ["aqz-KE-bpKQ", "eRsGyueVLvQ"]

    private static let movieIDMultiplier = 10_000
    private static let releaseBaseYear = 2025
    private static let maxRating = 9.4
    private static let ratingStep = 0.37
    private static let ratingRange = 5.5

    static func movie(genreID: Int, index: Int, sort: DiscoverSort = .popular) -> MovieSummary {
        let id = genreID * movieIDMultiplier + index
        let title = "\(adjectives[(index + genreID) % adjectives.count]) \(nouns[(index * 3 + genreID) % nouns.count])"
        let year = releaseBaseYear - (index % 30)
        let month = String(format: "%02d", index % 12 + 1)
        return MovieSummary(
            id: id,
            title: index.isMultiple(of: 9) ? "\(title): Part \(index / 9 + 1)" : title,
            overview: overview(for: title),
            posterPath: nil,
            backdropPath: nil,
            voteAverage: rating(for: index),
            voteCount: 120 + index * 37,
            releaseDate: index.isMultiple(of: 11) ? "" : "\(year)-\(month)-14"
        )
    }

    static func detail(id: Int, reviews: Page<Review>) -> MovieDetail {
        let genreID = id / movieIDMultiplier
        let index = id % movieIDMultiplier
        let summary = movie(genreID: genreID, index: index)
        let genre = genres.first { $0.id == genreID }
        return MovieDetail(
            id: id,
            title: summary.title,
            tagline: index.isMultiple(of: 4) ? nil : "Every story has a second act.",
            overview: summary.overview,
            runtime: 88 + index % 70,
            releaseDate: summary.releaseDate,
            genres: [genre, genres[(index + 3) % genres.count]].compactMap(\.self),
            voteAverage: summary.voteAverage,
            voteCount: summary.voteCount,
            status: "Released",
            originalLanguage: "en",
            budget: index.isMultiple(of: 3) ? 0 : 40_000_000 + index * 1_500_000,
            revenue: index.isMultiple(of: 3) ? 0 : 120_000_000 + index * 4_000_000,
            homepage: nil,
            videos: videos(movieID: id),
            reviews: reviews,
            cast: cast(for: index)
        )
    }

    private static let searchPoolGenreCount = 6
    private static let searchPoolMoviesPerGenre = 40

    /// Title search across a deterministic pool of the catalogue.
    static func searchPage(query: String, page: Int, perPage: Int) -> Page<MovieSummary> {
        let pool = genres.prefix(searchPoolGenreCount).flatMap { genre in
            (0..<searchPoolMoviesPerGenre).map { movie(genreID: genre.id, index: $0) }
        }
        let matches = pool.filter { $0.title.localizedCaseInsensitiveContains(query) }
        let totalPages = Int((Double(matches.count) / Double(perPage)).rounded(.up))
        let start = (page - 1) * perPage
        let items = start < matches.count ? Array(matches[start..<min(start + perPage, matches.count)]) : []
        return Page(page: page, items: items, totalPages: totalPages, totalResults: matches.count)
    }

    static func videos(movieID: Int) -> [Video] {
        guard !movieID.isMultiple(of: 5) else { return [] }
        return openMovieKeys.enumerated().map { offset, key in
            Video(
                id: "\(movieID)-video-\(offset)",
                key: key,
                name: offset == 0 ? "Official Trailer" : "Teaser",
                site: "YouTube",
                type: offset == 0 ? "Trailer" : "Teaser",
                official: true,
                publishedAt: "2024-0\(offset + 1)-10T16:00:00.000Z"
            )
        }
    }

    static func reviewPage(movieID: Int, page: Int, perPage: Int, total: Int) -> Page<Review> {
        let effectiveTotal = movieID.isMultiple(of: 7) ? 0 : total
        let totalPages = Int((Double(effectiveTotal) / Double(perPage)).rounded(.up))
        let start = (page - 1) * perPage
        let end = min(start + perPage, effectiveTotal)
        let items = start < end ? (start..<end).map { review(movieID: movieID, index: $0) } : []
        return Page(page: page, items: items, totalPages: totalPages, totalResults: effectiveTotal)
    }

    private static func review(movieID: Int, index: Int) -> Review {
        let reviewer = reviewers[index % reviewers.count]
        let paragraphs = index.isMultiple(of: 2) ? 4 : 1
        let body = Array(
            repeating: "A confident, beautifully shot film that trusts its audience. The second act drags a little, but the finale lands with real emotional weight.",
            count: paragraphs
        ).joined(separator: "\n\n")
        return Review(
            id: "\(movieID)-review-\(index)",
            author: reviewer.0,
            authorDetails: .init(
                name: reviewer.0,
                username: reviewer.1,
                avatarPath: nil,
                rating: index.isMultiple(of: 3) ? nil : Double(5 + index % 6)
            ),
            content: body,
            createdAt: "2025-0\(index % 9 + 1)-1\(index % 9)T10:15:00.000Z",
            url: nil
        )
    }

    private static func cast(for index: Int) -> [CastMember] {
        let names = ["Lena Hart", "Omar Diallo", "Grace Kim", "Tomás Ruiz", "Hannah Ode", "Leo Novak"]
        let roles = ["The Pilot", "Detective Vance", "Dr. Mira Sol", "The Stranger", "Captain Rhea", "Young Eli"]
        return names.indices.map { offset in
            CastMember(id: index * 10 + offset, name: names[offset], character: roles[offset], profilePath: nil)
        }
    }

    private static func overview(for title: String) -> String {
        "When an ordinary night turns extraordinary, a group of strangers must uncover the truth behind \(title.lowercased()) before dawn erases every trace of it. A sweeping tale of courage, memory and the bonds that hold us together."
    }

    private static func rating(for index: Int) -> Double {
        let raw = maxRating - (Double(index) * ratingStep).truncatingRemainder(dividingBy: ratingRange)
        return (raw * 10).rounded() / 10
    }
}
