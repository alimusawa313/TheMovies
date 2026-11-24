import Testing
@testable import TheMovies

final class MockMovieListInteractor: MovieListInteracting {
    var results: [Result<Page<MovieSummary>, APIError>]
    private(set) var requests: [(page: Int, sort: DiscoverSort)] = []

    init(_ results: [Result<Page<MovieSummary>, APIError>]) {
        self.results = results
    }

    func fetchMovies(genreID: Int, page: Int, sort: DiscoverSort) async throws(APIError) -> Page<MovieSummary> {
        requests.append((page, sort))
        return try results.removeFirst().get()
    }
}

/// Suspends each request until the test resolves it, to exercise races.
final class GatedMovieListInteractor: MovieListInteracting {
    private var pending: [DiscoverSort: CheckedContinuation<Page<MovieSummary>, Never>] = [:]

    func isWaiting(for sort: DiscoverSort) -> Bool { pending[sort] != nil }

    func resolve(_ sort: DiscoverSort, with page: Page<MovieSummary>) {
        pending.removeValue(forKey: sort)?.resume(returning: page)
    }

    func fetchMovies(genreID: Int, page: Int, sort: DiscoverSort) async throws(APIError) -> Page<MovieSummary> {
        await withCheckedContinuation { pending[sort] = $0 }
    }
}

final class SpyMovieListRouter: MovieListRouting {
    private(set) var shown: [MovieSummary] = []
    func showDetail(for movie: MovieSummary) { shown.append(movie) }
}

@Suite("Movie list presenter")
struct MovieListPresenterTests {
    private func makeSUT(_ results: [Result<Page<MovieSummary>, APIError>]) -> (MovieListPresenter, MockMovieListInteractor, SpyMovieListRouter) {
        let interactor = MockMovieListInteractor(results)
        let router = SpyMovieListRouter()
        return (MovieListPresenter(genre: Fixtures.action, interactor: interactor, router: router), interactor, router)
    }

    @Test("Loads the first page of popular movies")
    func firstPage() async {
        let (presenter, interactor, _) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<20))])
        await presenter.onAppear()
        #expect(presenter.movies.count == 20)
        #expect(interactor.requests.first?.page == 1)
        #expect(interactor.requests.first?.sort == .popular)
    }

    @Test("Endless scrolling loads the next page near the bottom")
    func loadsNextPage() async {
        let (presenter, interactor, _) = makeSUT([
            .success(Fixtures.moviePage(1, ids: 0..<20)),
            .success(Fixtures.moviePage(2, ids: 20..<40)),
        ])
        await presenter.onAppear()
        await presenter.loadMoreIfNeeded(after: presenter.movies[0])
        #expect(interactor.requests.count == 1)
        await presenter.loadMoreIfNeeded(after: presenter.movies[19])
        #expect(presenter.movies.count == 40)
        #expect(interactor.requests.last?.page == 2)
    }

    @Test("Stops requesting pages once the last page is reached")
    func stopsAtEnd() async {
        let (presenter, interactor, _) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<20, totalPages: 1))])
        await presenter.onAppear()
        await presenter.loadMoreIfNeeded(after: presenter.movies[19])
        #expect(interactor.requests.count == 1)
        #expect(presenter.paginator.hasReachedEnd)
    }

    @Test("A failed next page shows a retry footer that recovers")
    func nextPageFailureAndRetry() async {
        let (presenter, _, _) = makeSUT([
            .success(Fixtures.moviePage(1, ids: 0..<20)),
            .failure(.timedOut),
            .success(Fixtures.moviePage(2, ids: 20..<40)),
        ])
        await presenter.onAppear()
        await presenter.loadMoreIfNeeded(after: presenter.movies[19])
        #expect(presenter.paginator.phase == .failedNextPage(.timedOut))
        #expect(presenter.movies.count == 20)
        await presenter.retryNextPage()
        #expect(presenter.movies.count == 40)
    }

    @Test("A failed first page shows a full-screen error and retries")
    func firstPageFailure() async {
        let (presenter, _, _) = makeSUT([.failure(.unauthorized), .success(Fixtures.moviePage(1, ids: 0..<5))])
        await presenter.onAppear()
        #expect(presenter.paginator.phase == .failedFirstPage(.unauthorized))
        await presenter.retry()
        #expect(presenter.movies.count == 5)
    }

    @Test("An empty genre produces an empty state")
    func emptyGenre() async {
        let (presenter, _, _) = makeSUT([.success(Page(page: 1, items: [], totalPages: 0, totalResults: 0))])
        await presenter.onAppear()
        #expect(presenter.paginator.isEmpty)
    }

    @Test("Changing sort reloads from page one; same sort is ignored")
    func changingSort() async {
        let (presenter, interactor, _) = makeSUT([
            .success(Fixtures.moviePage(1, ids: 0..<20)),
            .success(Fixtures.moviePage(1, ids: 100..<120)),
        ])
        await presenter.onAppear()
        await presenter.select(sort: .popular)
        await presenter.select(sort: .topRated)
        #expect(interactor.requests.map(\.sort) == [.popular, .topRated])
        #expect(presenter.movies.first?.id == 100)
    }

    @Test("A late response from a previous sort is discarded")
    func staleResponseDiscarded() async {
        let interactor = GatedMovieListInteractor()
        let presenter = MovieListPresenter(genre: Fixtures.action, interactor: interactor, router: SpyMovieListRouter())

        let initialLoad = Task { await presenter.onAppear() }
        #expect(await waitUntil { interactor.isWaiting(for: .popular) })
        let sortChange = Task { await presenter.select(sort: .topRated) }
        #expect(await waitUntil { interactor.isWaiting(for: .topRated) })

        interactor.resolve(.topRated, with: Fixtures.moviePage(1, ids: 500..<510))
        await sortChange.value
        interactor.resolve(.popular, with: Fixtures.moviePage(1, ids: 0..<20))
        await initialLoad.value

        #expect(presenter.sort == .topRated)
        #expect(presenter.movies.map(\.id) == Array(500..<510))
    }

    @Test("A failed refresh keeps movies and shows a toast")
    func refreshFailure() async {
        let (presenter, _, _) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<20)), .failure(.offline)])
        await presenter.onAppear()
        await presenter.refresh()
        #expect(presenter.movies.count == 20)
        #expect(presenter.refreshError == .offline)
    }

    @Test("Selecting a movie routes to its detail")
    func routing() async {
        let (presenter, _, router) = makeSUT([.success(Fixtures.moviePage(1, ids: 0..<3))])
        await presenter.onAppear()
        presenter.didSelect(presenter.movies[1])
        #expect(router.shown.map(\.id) == [1])
    }
}
