import Foundation
import Testing
@testable import TheMovies

final class MockMovieSearchInteractor: MovieSearchInteracting {
    var results: [Result<Page<MovieSummary>, APIError>]
    private(set) var requests: [(query: String, page: Int)] = []

    init(_ results: [Result<Page<MovieSummary>, APIError>]) { self.results = results }

    func search(query: String, page: Int) async throws(APIError) -> Page<MovieSummary> {
        requests.append((query, page))
        return try results.removeFirst().get()
    }
}

@Suite("Movie search presenter")
struct MovieSearchPresenterTests {
    private func makeSUT(
        _ results: [Result<Page<MovieSummary>, APIError>],
        debounce: Duration = .zero
    ) -> (MovieSearchPresenter, MockMovieSearchInteractor, SpyMovieListRouter) {
        let interactor = MockMovieSearchInteractor(results)
        let router = SpyMovieListRouter()
        return (MovieSearchPresenter(interactor: interactor, router: router, debounce: debounce), interactor, router)
    }

    @Test("Searching by name loads the first page of results")
    func search() async {
        let (presenter, interactor, _) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<10))])
        await presenter.updateQuery("  Iron Man ")
        #expect(presenter.query == "Iron Man")
        #expect(presenter.results.count == 10)
        #expect(interactor.requests.map(\.query) == ["Iron Man"])
    }

    @Test("Blank input does not hit the network")
    func blankQuery() async {
        let (presenter, interactor, _) = makeSUT([])
        await presenter.updateQuery("   ")
        #expect(!presenter.isActive)
        #expect(interactor.requests.isEmpty)
    }

    @Test("Fast typing only searches for the final text")
    func debouncesTyping() async {
        let (presenter, interactor, _) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<3))], debounce: .milliseconds(80))
        let first = Task { await presenter.updateQuery("Ir") }
        let second = Task { await presenter.updateQuery("Iron") }
        await first.value
        await second.value
        #expect(interactor.requests.map(\.query) == ["Iron"])
        #expect(presenter.results.count == 3)
    }

    @Test("Repeating the same text does not search again")
    func sameQuery() async {
        let (presenter, interactor, _) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<3))])
        await presenter.updateQuery("Up")
        await presenter.updateQuery("Up ")
        #expect(interactor.requests.count == 1)
    }

    @Test("No matches produces an empty state")
    func noMatches() async {
        let (presenter, _, _) = makeSUT([.success(Page(page: 1, items: [], totalPages: 0, totalResults: 0))])
        await presenter.updateQuery("zzzzqq")
        #expect(presenter.paginator.isEmpty)
    }

    @Test("A failed search shows an error and retry recovers")
    func errorAndRetry() async {
        let (presenter, _, _) = makeSUT([.failure(.offline), .success(Fixtures.moviePage(1, ids: 0..<4))])
        await presenter.updateQuery("Heat")
        #expect(presenter.paginator.phase == .failedFirstPage(.offline))
        await presenter.retry()
        #expect(presenter.results.count == 4)
    }

    @Test("Results paginate endlessly and a failed page can be retried")
    func pagination() async {
        let (presenter, interactor, _) = makeSUT([
            .success(Fixtures.moviePage(1, ids: 0..<10)),
            .failure(.timedOut),
            .success(Fixtures.moviePage(2, ids: 10..<20)),
        ])
        await presenter.updateQuery("Star")
        await presenter.loadMoreIfNeeded(after: presenter.results[9])
        #expect(presenter.paginator.phase == .failedNextPage(.timedOut))
        await presenter.retryNextPage()
        #expect(presenter.results.count == 20)
        #expect(interactor.requests.map(\.page) == [1, 2, 2])
    }

    @Test("Clearing the search resets results")
    func clearing() async {
        let (presenter, _, _) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<5))])
        await presenter.updateQuery("Alien")
        await presenter.updateQuery("")
        #expect(!presenter.isActive)
        #expect(presenter.results.isEmpty)
        #expect(presenter.paginator.phase == .idle)
    }

    @Test("Selecting a result opens the movie detail")
    func routing() async {
        let (presenter, _, router) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<2))])
        await presenter.updateQuery("Jaws")
        presenter.didSelect(presenter.results[1])
        #expect(router.shown.map(\.id) == [1])
    }

    @Test("Search endpoint encodes the query safely")
    func endpointEncoding() throws {
        let request = try TMDBEndpoint.search(query: "Fast & Furious + 2", page: 3)
            .urlRequest(baseURL: TMDBAPIClient.defaultBaseURL, credential: .apiKey(Fixtures.validAPIKey), language: "en-US")
        let url = try #require(request.url)
        #expect(url.path() == "/3/search/movie")
        #expect(url.query?.contains("query=Fast%20%26%20Furious%20%2B%202") == true)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "query" }?.value == "Fast & Furious + 2")
        #expect(items.first { $0.name == "page" }?.value == "3")
    }

    @Test("Stub search matches titles case-insensitively")
    func stubSearch() async throws {
        let repository = StubMovieRepository(scenario: .standard, latency: .zero)
        let page = try await repository.searchMovies(query: "midnight", page: 1)
        #expect(!page.items.isEmpty)
        #expect(page.items.allSatisfy { $0.title.localizedCaseInsensitiveContains("midnight") })
        #expect(try await repository.searchMovies(query: "qqqzzz", page: 1).items.isEmpty)
        #expect(try await MovieSearchInteractor(repository: repository).search(query: "Echo", page: 1).totalResults > 0)
    }
}
