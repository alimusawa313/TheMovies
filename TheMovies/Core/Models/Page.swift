import Foundation

/// A page of results from a paginated TMDB endpoint.
nonisolated struct Page<Item: Sendable>: Sendable {
    /// TMDB refuses to serve pages beyond 500 even when `total_pages` is larger.
    static var maximumPage: Int { 500 }

    let page: Int
    let items: [Item]
    let totalPages: Int
    let totalResults: Int

    var hasMore: Bool { page < min(totalPages, Self.maximumPage) }

    func map<Mapped: Sendable>(_ transform: (Item) -> Mapped) -> Page<Mapped> {
        Page<Mapped>(page: page, items: items.map(transform), totalPages: totalPages, totalResults: totalResults)
    }
}

nonisolated extension Page: Equatable where Item: Equatable {}

nonisolated extension Page: Decodable where Item: Decodable {
    private enum CodingKeys: String, CodingKey {
        case page, results, totalPages, totalResults
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        let items = try container.decodeIfPresent(LossyArray<Item>.self, forKey: .results)?.elements ?? []
        self.page = page
        self.items = items
        self.totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? page
        self.totalResults = try container.decodeIfPresent(Int.self, forKey: .totalResults) ?? items.count
    }
}

/// Decodes an array while skipping elements that fail to decode, so one bad
/// record from the API never wipes out an entire page.
nonisolated struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    private struct Skip: Decodable {}

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                decoded.append(element)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        elements = decoded
    }
}
