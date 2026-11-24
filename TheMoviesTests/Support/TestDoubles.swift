import Foundation
import Synchronization
@testable import TheMovies

// MARK: - HTTP

/// Returns a canned response and records every request it receives.
nonisolated final class StubHTTPClient: HTTPClient {
    private let handler: @Sendable (URLRequest) throws -> (Data, URLResponse)
    private let recorded = Mutex<[URLRequest]>([])

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    convenience init(status: Int, body: String, headers: [String: String] = [:]) {
        self.init { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            return (Data(body.utf8), response)
        }
    }

    convenience init(error: any Error) {
        self.init { _ in throw error }
    }

    var requests: [URLRequest] { recorded.withLock { $0 } }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        recorded.withLock { $0.append(request) }
        return try handler(request)
    }
}

// MARK: - Repository

/// Repository whose responses are configured per test.
nonisolated struct FakeMovieRepository: MovieRepository {
    var genresResult: Result<[Genre], APIError> = .success([])
    var discoverResult: Result<Page<MovieSummary>, APIError> = .success(Page(page: 1, items: [], totalPages: 1, totalResults: 0))
    var detailResult: Result<MovieDetail, APIError> = .failure(.notFound)
    var reviewsResult: Result<Page<Review>, APIError> = .success(Page(page: 1, items: [], totalPages: 1, totalResults: 0))
    var videosResult: Result<[Video], APIError> = .success([])
    var validationResult: Result<Void, APIError> = .success(())
    var searchResult: Result<Page<MovieSummary>, APIError> = .success(Page(page: 1, items: [], totalPages: 0, totalResults: 0))

    func genres() async throws(APIError) -> [Genre] { try genresResult.get() }
    func discoverMovies(genreID: Int, page: Int, sort: DiscoverSort) async throws(APIError) -> Page<MovieSummary> {
        try discoverResult.get()
    }
    func movieDetail(id: Int) async throws(APIError) -> MovieDetail { try detailResult.get() }
    func reviews(movieID: Int, page: Int) async throws(APIError) -> Page<Review> { try reviewsResult.get() }
    func videos(movieID: Int) async throws(APIError) -> [Video] { try videosResult.get() }
    func searchMovies(query: String, page: Int) async throws(APIError) -> Page<MovieSummary> { try searchResult.get() }
    func validateCredential() async throws(APIError) { try validationResult.get() }
}

// MARK: - Credential store

nonisolated final class InMemoryCredentialStore: CredentialStoring {
    private let stored: Mutex<APICredential?>
    private let failure: CredentialStoreError?

    init(credential: APICredential? = nil, failure: CredentialStoreError? = nil) {
        self.stored = Mutex(credential)
        self.failure = failure
    }

    var current: APICredential? { stored.withLock { $0 } }

    func load() -> APICredential? { current }

    func save(_ credential: APICredential) throws(CredentialStoreError) {
        if let failure { throw failure }
        stored.withLock { $0 = credential }
    }

    func delete() throws(CredentialStoreError) {
        if let failure { throw failure }
        stored.withLock { $0 = nil }
    }
}

// MARK: - Factories

enum Fixtures {
    static let validAPIKey = String(repeating: "a1", count: 16)
    static let action = Genre(id: 28, name: "Action")

    static func movies(_ range: Range<Int>) -> [MovieSummary] {
        range.map { MovieSummary(id: $0, title: "Movie \($0)", voteAverage: 7, voteCount: 10, releaseDate: "2020-01-01") }
    }

    static func moviePage(_ page: Int, ids: Range<Int>, totalPages: Int = 3) -> Page<MovieSummary> {
        Page(page: page, items: movies(ids), totalPages: totalPages, totalResults: totalPages * ids.count)
    }

    static func review(id: String, rating: Double? = 8, content: String = "Great film.") -> Review {
        Review(
            id: id,
            author: "Author \(id)",
            authorDetails: .init(name: nil, username: "user\(id)", avatarPath: nil, rating: rating),
            content: content,
            createdAt: "2025-03-14T10:15:00.000Z"
        )
    }

    static func video(id: String, type: String = "Trailer", site: String = "YouTube", official: Bool = true) -> Video {
        Video(id: id, key: "key-\(id)", name: "Video \(id)", site: site, type: type, official: official, publishedAt: nil)
    }
}

/// Polls a condition on the main actor, yielding between checks.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        guard clock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}
