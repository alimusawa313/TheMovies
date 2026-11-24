import Foundation

/// Deterministic offline data used for demo mode, SwiftUI previews and UI tests.
actor StubMovieRepository: MovieRepository {
    nonisolated enum Scenario: String, Sendable {
        /// Everything works.
        case standard
        /// Every list is empty.
        case empty
        /// Every request fails as if offline.
        case failure
        /// The first attempt to load page 2 of any list fails, the retry succeeds.
        case flakyPagination
    }

    static let moviesPerPage = 20
    static let movieTotalPages = 4
    static let reviewsPerPage = 5
    static let reviewTotal = 13
    static let searchResultsPerPage = 10

    private let scenario: Scenario
    private let latency: Duration
    private var failedPageKeys: Set<String> = []

    init(scenario: Scenario = .standard, latency: Duration = .milliseconds(650)) {
        self.scenario = scenario
        self.latency = latency
    }

    func genres() async throws(APIError) -> [Genre] {
        try await simulateNetwork()
        return scenario == .empty ? [] : StubCatalog.genres
    }

    func discoverMovies(genreID: Int, page: Int, sort: DiscoverSort) async throws(APIError) -> Page<MovieSummary> {
        try await simulateNetwork()
        try failIfFlaky(key: "movies-\(genreID)-\(sort.rawValue)", page: page)
        guard scenario != .empty else {
            return Page(page: 1, items: [], totalPages: 0, totalResults: 0)
        }
        let items = (0..<Self.moviesPerPage).map { offset in
            StubCatalog.movie(genreID: genreID, index: (page - 1) * Self.moviesPerPage + offset, sort: sort)
        }
        return Page(
            page: page,
            items: items,
            totalPages: Self.movieTotalPages,
            totalResults: Self.movieTotalPages * Self.moviesPerPage
        )
    }

    func movieDetail(id: Int) async throws(APIError) -> MovieDetail {
        try await simulateNetwork()
        return StubCatalog.detail(id: id, reviews: try await firstReviewPage(movieID: id))
    }

    func reviews(movieID: Int, page: Int) async throws(APIError) -> Page<Review> {
        try await simulateNetwork()
        try failIfFlaky(key: "reviews-\(movieID)", page: page)
        return StubCatalog.reviewPage(
            movieID: movieID,
            page: page,
            perPage: Self.reviewsPerPage,
            total: scenario == .empty ? 0 : Self.reviewTotal
        )
    }

    func videos(movieID: Int) async throws(APIError) -> [Video] {
        try await simulateNetwork()
        return StubCatalog.videos(movieID: movieID)
    }

    func searchMovies(query: String, page: Int) async throws(APIError) -> Page<MovieSummary> {
        try await simulateNetwork()
        try failIfFlaky(key: "search-\(query)", page: page)
        guard scenario != .empty else {
            return Page(page: 1, items: [], totalPages: 0, totalResults: 0)
        }
        return StubCatalog.searchPage(query: query, page: page, perPage: Self.searchResultsPerPage)
    }

    func validateCredential() async throws(APIError) {
        try await simulateNetwork()
    }

    // MARK: - Helpers

    private func firstReviewPage(movieID: Int) async throws(APIError) -> Page<Review> {
        StubCatalog.reviewPage(
            movieID: movieID,
            page: 1,
            perPage: Self.reviewsPerPage,
            total: scenario == .empty ? 0 : Self.reviewTotal
        )
    }

    private func simulateNetwork() async throws(APIError) {
        do {
            try await Task.sleep(for: latency)
        } catch {
            throw .cancelled
        }
        if scenario == .failure { throw .offline }
    }

    private func failIfFlaky(key: String, page: Int) throws(APIError) {
        guard scenario == .flakyPagination, page == 2, !failedPageKeys.contains(key) else { return }
        failedPageKeys.insert(key)
        throw .timedOut
    }
}
