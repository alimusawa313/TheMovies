import Foundation

/// Data-access boundary used by every VIPER interactor.
nonisolated protocol MovieRepository: Sendable {
    func genres() async throws(APIError) -> [Genre]
    func discoverMovies(genreID: Int, page: Int, sort: DiscoverSort) async throws(APIError) -> Page<MovieSummary>
    func movieDetail(id: Int) async throws(APIError) -> MovieDetail
    func reviews(movieID: Int, page: Int) async throws(APIError) -> Page<Review>
    func videos(movieID: Int) async throws(APIError) -> [Video]
    func searchMovies(query: String, page: Int) async throws(APIError) -> Page<MovieSummary>
    /// Succeeds when the configured credential is accepted by TMDB.
    func validateCredential() async throws(APIError)
}

/// Live implementation backed by the TMDB REST API.
nonisolated struct TMDBMovieRepository: MovieRepository {
    private let client: any TMDBRequesting

    init(client: any TMDBRequesting) {
        self.client = client
    }

    func genres() async throws(APIError) -> [Genre] {
        try await client.send(.genres(), as: GenreListResponse.self).genres
    }

    func discoverMovies(genreID: Int, page: Int, sort: DiscoverSort) async throws(APIError) -> Page<MovieSummary> {
        try await client.send(.discover(genreID: genreID, page: page, sort: sort), as: Page<MovieSummary>.self)
    }

    func movieDetail(id: Int) async throws(APIError) -> MovieDetail {
        try await client.send(.movieDetail(id: id), as: MovieDetail.self)
    }

    func reviews(movieID: Int, page: Int) async throws(APIError) -> Page<Review> {
        try await client.send(.reviews(movieID: movieID, page: page), as: Page<Review>.self)
    }

    func videos(movieID: Int) async throws(APIError) -> [Video] {
        try await client.send(.videos(movieID: movieID), as: VideoListResponse.self).results
    }

    func searchMovies(query: String, page: Int) async throws(APIError) -> Page<MovieSummary> {
        try await client.send(.search(query: query, page: page), as: Page<MovieSummary>.self)
    }

    func validateCredential() async throws(APIError) {
        let response = try await client.send(.authentication(), as: AuthenticationResponse.self)
        guard response.success else { throw .unauthorized }
    }
}

nonisolated struct AuthenticationResponse: Decodable, Sendable {
    let success: Bool
}
