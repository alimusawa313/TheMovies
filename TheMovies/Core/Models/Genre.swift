import Foundation

nonisolated struct Genre: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct GenreListResponse: Decodable, Sendable {
    let genres: [Genre]

    private enum CodingKeys: String, CodingKey { case genres }

    init(genres: [Genre]) {
        self.genres = genres
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genres = try container.decodeIfPresent(LossyArray<Genre>.self, forKey: .genres)?.elements ?? []
    }
}
