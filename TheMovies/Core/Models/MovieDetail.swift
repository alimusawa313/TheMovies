import Foundation

/// Full movie payload from `/movie/{id}?append_to_response=videos,reviews,credits`.
nonisolated struct MovieDetail: Decodable, Sendable, Equatable {
    let id: Int
    let title: String
    let tagline: String?
    let overview: String?
    let runtime: Int?
    let releaseDate: String?
    let genres: [Genre]
    let voteAverage: Double
    let voteCount: Int
    let posterPath: String?
    let backdropPath: String?
    let status: String?
    let originalLanguage: String?
    let budget: Int?
    let revenue: Int?
    let homepage: String?
    let videos: [Video]
    let reviews: Page<Review>?
    let cast: [CastMember]

    private enum CodingKeys: String, CodingKey {
        case id, title, tagline, overview, runtime, releaseDate, genres, voteAverage, voteCount
        case posterPath, backdropPath, status, originalLanguage, budget, revenue, homepage
        case videos, reviews, credits
    }

    private struct VideoContainer: Decodable { let results: LossyArray<Video>? }
    private struct CreditsContainer: Decodable { let cast: LossyArray<CastMember>? }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        tagline = try container.decodeIfPresent(String.self, forKey: .tagline)?.nilIfBlank
        overview = try container.decodeIfPresent(String.self, forKey: .overview)?.nilIfBlank
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        genres = try container.decodeIfPresent(LossyArray<Genre>.self, forKey: .genres)?.elements ?? []
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage) ?? 0
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount) ?? 0
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage)
        budget = try container.decodeIfPresent(Int.self, forKey: .budget)
        revenue = try container.decodeIfPresent(Int.self, forKey: .revenue)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)?.nilIfBlank
        videos = (try? container.decodeIfPresent(VideoContainer.self, forKey: .videos))??.results?.elements ?? []
        reviews = try? container.decodeIfPresent(Page<Review>.self, forKey: .reviews)
        cast = (try? container.decodeIfPresent(CreditsContainer.self, forKey: .credits))??.cast?.elements ?? []
    }

    init(
        id: Int,
        title: String,
        tagline: String? = nil,
        overview: String? = nil,
        runtime: Int? = nil,
        releaseDate: String? = nil,
        genres: [Genre] = [],
        voteAverage: Double = 0,
        voteCount: Int = 0,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        status: String? = nil,
        originalLanguage: String? = nil,
        budget: Int? = nil,
        revenue: Int? = nil,
        homepage: String? = nil,
        videos: [Video] = [],
        reviews: Page<Review>? = nil,
        cast: [CastMember] = []
    ) {
        self.id = id
        self.title = title
        self.tagline = tagline
        self.overview = overview
        self.runtime = runtime
        self.releaseDate = releaseDate
        self.genres = genres
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.status = status
        self.originalLanguage = originalLanguage
        self.budget = budget
        self.revenue = revenue
        self.homepage = homepage
        self.videos = videos
        self.reviews = reviews
        self.cast = cast
    }
}

nonisolated struct CastMember: Decodable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    var profileURL: URL? { TMDBImage.url(path: profilePath, size: .profile) }
}

nonisolated extension String {
    /// Returns `nil` for empty or whitespace-only strings.
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
