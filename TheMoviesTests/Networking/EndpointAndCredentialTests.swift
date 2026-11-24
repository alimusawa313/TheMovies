import Foundation
import Testing
@testable import TheMovies

@Suite("Endpoints")
struct TMDBEndpointTests {
    private let base = URL(string: "https://api.themoviedb.org")!

    private func queryItems(_ endpoint: TMDBEndpoint) throws -> [String: String] {
        let request = try endpoint.urlRequest(baseURL: base, credential: .apiKey(Fixtures.validAPIKey), language: "en-US")
        let items = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test("Discover filters by genre, page and sort")
    func discoverQuery() throws {
        let endpoint = TMDBEndpoint.discover(genreID: 28, page: 3, sort: .popular)
        let items = try queryItems(endpoint)
        #expect(endpoint.path == "/3/discover/movie")
        #expect(items["with_genres"] == "28")
        #expect(items["page"] == "3")
        #expect(items["sort_by"] == "popularity.desc")
        #expect(items["include_adult"] == "false")
        #expect(items["language"] == "en-US")
    }

    @Test("Top rated requires a minimum vote count")
    func topRatedVoteFloor() throws {
        let items = try queryItems(.discover(genreID: 18, page: 1, sort: .topRated))
        #expect(items["vote_count.gte"] == String(TMDBEndpoint.topRatedMinimumVotes))
    }

    @Test("Newest excludes unreleased movies")
    func newestExcludesFuture() throws {
        let date = try #require(Formatters.day(from: "2026-11-24"))
        let items = try queryItems(.discover(genreID: 18, page: 1, sort: .newest, referenceDate: date))
        #expect(items["primary_release_date.lte"] == "2026-11-24")
    }

    @Test("Movie detail appends videos, reviews and credits")
    func detailAppends() throws {
        let items = try queryItems(.movieDetail(id: 550))
        #expect(TMDBEndpoint.movieDetail(id: 550).path == "/3/movie/550")
        #expect(items["append_to_response"] == "videos,reviews,credits")
    }

    @Test("Reviews endpoint is paginated")
    func reviewsPath() throws {
        let endpoint = TMDBEndpoint.reviews(movieID: 550, page: 2)
        #expect(endpoint.path == "/3/movie/550/reviews")
        #expect(try queryItems(endpoint)["page"] == "2")
    }
}

@Suite("API credential parsing")
struct APICredentialTests {
    @Test("Accepts a 32-character v3 key, trimming whitespace")
    func acceptsAPIKey() {
        #expect(APICredential(rawValue: "  \(Fixtures.validAPIKey)\n") == .apiKey(Fixtures.validAPIKey))
    }

    @Test("Accepts a v4 JWT access token")
    func acceptsToken() {
        let token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature_part_123"
        #expect(APICredential(rawValue: token) == .accessToken(token))
    }

    @Test(
        "Rejects malformed input",
        arguments: ["", "   ", "abc", String(repeating: "a", count: 31), String(repeating: "a", count: 33), "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d!", "not.a.jwt"]
    )
    func rejectsMalformed(raw: String) {
        #expect(APICredential(rawValue: raw) == nil)
    }
}

@Suite("APIError")
struct APIErrorTests {
    @Test("Non-recoverable errors are not retryable")
    func retryability() {
        #expect(!APIError.unauthorized.isRetryable)
        #expect(!APIError.notFound.isRetryable)
        #expect(APIError.offline.isRetryable)
        #expect(APIError.server(statusCode: 502).isRetryable)
    }

    @Test("Rate-limit message includes the wait time")
    func rateLimitMessage() {
        #expect(APIError.rateLimited(retryAfter: 4.2).message.contains("5 seconds"))
    }

    @Test("Unknown errors map to transport errors")
    func mapsUnknown() {
        struct Boom: Error {}
        guard case .transport = APIError.map(Boom()) else {
            Issue.record("Expected transport error")
            return
        }
        #expect(APIError.map(CancellationError()) == .cancelled)
    }
}
