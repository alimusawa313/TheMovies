import Foundation

/// A movie as returned by list endpoints such as `/discover/movie`.
nonisolated struct MovieSummary: Decodable, Hashable, Identifiable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let releaseDate: String?

    init(
        id: Int,
        title: String,
        overview: String = "",
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double = 0,
        voteCount: Int = 0,
        releaseDate: String? = nil
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.releaseDate = releaseDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, overview, posterPath, backdropPath, voteAverage, voteCount, releaseDate
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage) ?? 0
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount) ?? 0
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
    }

    var posterURL: URL? { TMDBImage.url(path: posterPath, size: .poster) }
    var backdropURL: URL? { TMDBImage.url(path: backdropPath, size: .backdrop) }
    var releaseYear: String? { Formatters.year(from: releaseDate) }
}
