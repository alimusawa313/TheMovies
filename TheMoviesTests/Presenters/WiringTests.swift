import Foundation
import Testing
@testable import TheMovies

@Suite("Live repository")
struct TMDBMovieRepositoryTests {
    /// Routes each endpoint path to a canned JSON body.
    private func makeRepository(routes: [String: (Int, String)]) -> (TMDBMovieRepository, StubHTTPClient) {
        let http = StubHTTPClient { request in
            let path = request.url?.path() ?? ""
            let (status, body) = routes[path] ?? (404, "{}")
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
        return (TMDBMovieRepository(client: TMDBAPIClient(credential: .apiKey(Fixtures.validAPIKey), http: http)), http)
    }

    @Test("Hits every endpoint and decodes the results")
    func endpoints() async throws {
        let (repository, http) = makeRepository(routes: [
            "/3/genre/movie/list": (200, #"{"genres":[{"id":1,"name":"A"}]}"#),
            "/3/discover/movie": (200, #"{"page":1,"total_pages":2,"total_results":1,"results":[{"id":9,"title":"T"}]}"#),
            "/3/movie/9": (200, #"{"id":9,"title":"T"}"#),
            "/3/movie/9/reviews": (200, #"{"page":1,"total_pages":1,"total_results":1,"results":[{"id":"r","author":"a","content":"c"}]}"#),
            "/3/movie/9/videos": (200, #"{"results":[{"id":"v","key":"k","name":"n","site":"YouTube","type":"Trailer"}]}"#),
            "/3/authentication": (200, #"{"success":true}"#),
        ])
        #expect(try await repository.genres().count == 1)
        #expect(try await repository.discoverMovies(genreID: 1, page: 1, sort: .popular).items.first?.id == 9)
        #expect(try await repository.movieDetail(id: 9).title == "T")
        #expect(try await repository.reviews(movieID: 9, page: 1).items.count == 1)
        #expect(try await repository.videos(movieID: 9).first?.key == "k")
        try await repository.validateCredential()
        #expect(http.requests.count == 6)
    }

    @Test("Validation fails when TMDB reports success=false or 401")
    func validationFailures() async {
        let (unsuccessful, _) = makeRepository(routes: ["/3/authentication": (200, #"{"success":false}"#)])
        await #expect(throws: APIError.unauthorized) { try await unsuccessful.validateCredential() }

        let (rejected, _) = makeRepository(routes: ["/3/authentication": (401, #"{"status_code":7}"#)])
        await #expect(throws: APIError.unauthorized) { try await rejected.validateCredential() }
    }
}

@Suite("Interactors")
struct InteractorTests {
    @Test("Movie list, detail and reviews interactors pass data through")
    func passThrough() async throws {
        let repository = FakeMovieRepository(
            discoverResult: .success(Fixtures.moviePage(1, ids: 0..<3)),
            detailResult: .success(MovieDetail(id: 1, title: "D")),
            reviewsResult: .success(Page(page: 1, items: [Fixtures.review(id: "1", content: "<i>Nice</i>")], totalPages: 1, totalResults: 1))
        )
        #expect(try await MovieListInteractor(repository: repository).fetchMovies(genreID: 1, page: 1, sort: .newest).items.count == 3)
        #expect(try await MovieDetailInteractor(repository: repository).fetchDetail(movieID: 1).title == "D")
        let reviews = try await ReviewsInteractor(repository: repository).fetchReviews(movieID: 1, page: 1)
        #expect(reviews.items.first?.content == "Nice")
    }

    @Test("Interactors propagate repository errors")
    func errors() async {
        let repository = FakeMovieRepository(
            discoverResult: .failure(.server(statusCode: 502)),
            reviewsResult: .failure(.offline)
        )
        await #expect(throws: APIError.server(statusCode: 502)) {
            try await MovieListInteractor(repository: repository).fetchMovies(genreID: 1, page: 1, sort: .popular)
        }
        await #expect(throws: APIError.notFound) {
            try await MovieDetailInteractor(repository: repository).fetchDetail(movieID: 1)
        }
        await #expect(throws: APIError.offline) {
            try await ReviewsInteractor(repository: repository).fetchReviews(movieID: 1, page: 1)
        }
    }
}

@Suite("Routers")
struct RouterTests {
    @Test("Routers push and present the right destinations")
    func routes() {
        let navigator = Navigator()
        let movie = MovieSummary(id: 7, title: "Seven")
        let video = Fixtures.video(id: "v")

        GenreListRouter(navigator: navigator).showMovies(for: Fixtures.action)
        MovieListRouter(navigator: navigator).showDetail(for: movie)
        MovieDetailRouter(navigator: navigator).showReviews(movieID: 7, title: "Seven")
        #expect(navigator.path == [.movies(Fixtures.action), .movieDetail(movie), .reviews(movieID: 7, title: "Seven")])

        GenreListRouter(navigator: navigator).showSettings()
        #expect(navigator.sheet == .settings)

        let context = TrailerContext(movieTitle: "Seven", videos: [video], initialVideo: video)
        MovieDetailRouter(navigator: navigator).playTrailer(context)
        #expect(navigator.sheet == .trailer(context))
        #expect(navigator.sheet?.id == "trailer-v")

        TrailerRouter(navigator: navigator).close()
        #expect(navigator.sheet == nil)
    }

    @Test("API key router signs in and starts demo mode")
    func apiKeyRouter() throws {
        let session = AppSession(
            store: InMemoryCredentialStore(),
            launch: LaunchConfiguration(arguments: [], environment: [:]),
            defaults: UserDefaults(suiteName: "RouterTests.\(UUID().uuidString)")!
        )
        let router = APIKeySetupRouter(session: session)
        router.startDemo()
        #expect(session.isDemo)
        try router.complete(with: .apiKey(Fixtures.validAPIKey))
        #expect(session.mode == .live(.apiKey(Fixtures.validAPIKey)))
        #expect(session.makeRepository() != nil)
    }
}

@Suite("Keychain credential store", .serialized)
struct KeychainCredentialStoreTests {
    private let store = KeychainCredentialStore(service: "com.alihaidar.TheMovies.tests", account: "test-\(UUID().uuidString)")

    @Test("Saves, loads, overwrites and deletes a credential")
    func roundTrip() throws {
        defer { try? store.delete() }
        #expect(store.load() == nil)
        try store.save(.apiKey(Fixtures.validAPIKey))
        #expect(store.load() == .apiKey(Fixtures.validAPIKey))
        let replacement = String(repeating: "b2", count: 16)
        try store.save(.apiKey(replacement))
        #expect(store.load() == .apiKey(replacement))
        try store.delete()
        #expect(store.load() == nil)
        try store.delete()
    }
}

@Suite("Stub catalogue")
struct StubCatalogTests {
    @Test("Standard scenario serves genres, pages, details, reviews and videos")
    func standard() async throws {
        let repository = StubMovieRepository(scenario: .standard, latency: .zero)
        #expect(try await repository.genres().count == StubCatalog.genres.count)
        let page = try await repository.discoverMovies(genreID: 28, page: 1, sort: .topRated)
        #expect(page.hasMore)
        let detail = try await repository.movieDetail(id: page.items[1].id)
        #expect(!detail.videos.isEmpty)
        #expect(try await repository.reviews(movieID: page.items[1].id, page: 3).items.count == 3)
        #expect(try await repository.videos(movieID: 280_000).isEmpty)
        try await repository.validateCredential()
    }

    @Test("Empty scenario returns no content")
    func empty() async throws {
        let repository = StubMovieRepository(scenario: .empty, latency: .zero)
        #expect(try await repository.genres().isEmpty)
        #expect(try await repository.discoverMovies(genreID: 28, page: 1, sort: .popular).items.isEmpty)
        #expect(try await repository.reviews(movieID: 1, page: 1).totalResults == 0)
    }
}

@Suite("Error presentation")
struct ErrorPresentationTests {
    @Test(
        "Every error has a title, message and symbol",
        arguments: [
            APIError.invalidCredential, .unauthorized, .notFound, .rateLimited(retryAfter: nil),
            .server(statusCode: 500), .unexpectedStatus(418), .offline, .timedOut,
            .decoding("x"), .invalidRequest, .cancelled, .transport("boom"),
        ]
    )
    func presentation(error: APIError) {
        #expect(!error.title.isEmpty)
        #expect(!error.message.isEmpty)
        #expect(!error.symbol.isEmpty)
    }

    @Test("Load state accessors")
    func loadState() {
        let loaded = LoadState<Int>.loaded(1)
        #expect(loaded.value == 1)
        #expect(loaded.error == nil)
        #expect(LoadState<Int>.loading.isLoading)
        #expect(LoadState<Int>.failed(.offline).error == .offline)
        #expect(LoadState<Int>.idle.isIdle)
    }
}
