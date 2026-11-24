import Foundation

nonisolated struct Video: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool?
    let publishedAt: String?

    var isYouTube: Bool { site.caseInsensitiveCompare("YouTube") == .orderedSame }

    var youtubeURL: URL? { URL(string: "https://www.youtube.com/watch?v=\(key)") }

    var thumbnailURL: URL? { URL(string: "https://img.youtube.com/vi/\(key)/hqdefault.jpg") }

    /// Ranking used to choose the "Play Trailer" video: official trailers first.
    var trailerPriority: Int {
        let typeScore = switch type.lowercased() {
        case "trailer": 0
        case "teaser": 2
        case "clip": 4
        case "featurette": 5
        default: 6
        }
        return typeScore + (official == true ? 0 : 1)
    }
}

nonisolated struct VideoListResponse: Decodable, Sendable {
    let results: [Video]

    private enum CodingKeys: String, CodingKey { case results }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent(LossyArray<Video>.self, forKey: .results)?.elements ?? []
    }
}

nonisolated extension [Video] {
    /// YouTube-only videos ordered with the best trailer first.
    var playableTrailers: [Video] {
        filter(\.isYouTube)
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.trailerPriority == rhs.element.trailerPriority
                    ? lhs.offset < rhs.offset
                    : lhs.element.trailerPriority < rhs.element.trailerPriority
            }
            .map(\.element)
    }
}
