import Foundation

/// Sort orders offered on the discover screen.
nonisolated enum DiscoverSort: String, CaseIterable, Identifiable, Sendable {
    case popular = "popularity.desc"
    case topRated = "vote_average.desc"
    case newest = "primary_release_date.desc"
    case boxOffice = "revenue.desc"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popular: "Popular"
        case .topRated: "Top Rated"
        case .newest: "Newest"
        case .boxOffice: "Box Office"
        }
    }

    var symbol: String {
        switch self {
        case .popular: "flame.fill"
        case .topRated: "star.fill"
        case .newest: "sparkles"
        case .boxOffice: "dollarsign.circle.fill"
        }
    }
}

/// Describes a TMDB v3 endpoint independently from credentials and transport.
nonisolated struct TMDBEndpoint: Equatable, Sendable {
    /// Minimum votes for "Top Rated" so obscure single-vote titles don't dominate.
    static let topRatedMinimumVotes = 300
    /// Minimum votes for "Newest" to skip placeholder entries.
    static let newestMinimumVotes = 10

    let path: String
    let queryItems: [URLQueryItem]

    static func genres() -> TMDBEndpoint {
        TMDBEndpoint(path: "/3/genre/movie/list", queryItems: [])
    }

    static func discover(
        genreID: Int,
        page: Int,
        sort: DiscoverSort,
        referenceDate: Date = .now
    ) -> TMDBEndpoint {
        var items = [
            URLQueryItem(name: "with_genres", value: String(genreID)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sort_by", value: sort.rawValue),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "include_video", value: "false"),
        ]
        switch sort {
        case .topRated:
            items.append(URLQueryItem(name: "vote_count.gte", value: String(topRatedMinimumVotes)))
        case .newest:
            let today = referenceDate.formatted(.iso8601.year().month().day())
            items.append(URLQueryItem(name: "primary_release_date.lte", value: today))
            items.append(URLQueryItem(name: "vote_count.gte", value: String(newestMinimumVotes)))
        case .popular, .boxOffice:
            break
        }
        return TMDBEndpoint(path: "/3/discover/movie", queryItems: items)
    }

    static func movieDetail(id: Int) -> TMDBEndpoint {
        TMDBEndpoint(
            path: "/3/movie/\(id)",
            queryItems: [URLQueryItem(name: "append_to_response", value: "videos,reviews,credits")]
        )
    }

    static func reviews(movieID: Int, page: Int) -> TMDBEndpoint {
        TMDBEndpoint(
            path: "/3/movie/\(movieID)/reviews",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
        )
    }

    static func videos(movieID: Int) -> TMDBEndpoint {
        TMDBEndpoint(path: "/3/movie/\(movieID)/videos", queryItems: [])
    }

    /// Searches movies by title.
    static func search(query: String, page: Int) -> TMDBEndpoint {
        TMDBEndpoint(
            path: "/3/search/movie",
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "include_adult", value: "false"),
            ]
        )
    }

    static func authentication() -> TMDBEndpoint {
        TMDBEndpoint(path: "/3/authentication", queryItems: [])
    }

    func urlRequest(
        baseURL: URL,
        credential: APICredential,
        language: String
    ) throws(APIError) -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw .invalidRequest
        }
        var items = queryItems + [URLQueryItem(name: "language", value: language)]
        if case .apiKey(let key) = credential {
            items.append(URLQueryItem(name: "api_key", value: key))
        }
        components.queryItems = items
        // URLComponents leaves "+" unescaped, which servers decode as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")

        guard let url = components.url else { throw .invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if case .accessToken(let token) = credential {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
