import Testing
@testable import TheMovies

final class MockGenreListInteractor: GenreListInteracting {
    var results: [Result<[Genre], APIError>]
    private(set) var callCount = 0

    init(_ results: [Result<[Genre], APIError>]) {
        self.results = results
    }

    func fetchGenres() async throws(APIError) -> [Genre] {
        callCount += 1
        return try results.removeFirst().get()
    }
}

final class SpyGenreListRouter: GenreListRouting {
    private(set) var shownGenres: [Genre] = []
    private(set) var settingsShown = 0

    func showMovies(for genre: Genre) { shownGenres.append(genre) }
    func showSettings() { settingsShown += 1 }
}

@Suite("Genre list presenter")
struct GenreListPresenterTests {
    private let genres = [Genre(id: 28, name: "Action"), Genre(id: 35, name: "Comedy"), Genre(id: 18, name: "Drama")]

    private func makeSUT(_ results: [Result<[Genre], APIError>]) -> (GenreListPresenter, MockGenreListInteractor, SpyGenreListRouter) {
        let interactor = MockGenreListInteractor(results)
        let router = SpyGenreListRouter()
        return (GenreListPresenter(interactor: interactor, router: router), interactor, router)
    }

    @Test("Loads genres on first appearance only")
    func loadsOnce() async {
        let (presenter, interactor, _) = makeSUT([.success(genres)])
        await presenter.onAppear()
        await presenter.onAppear()
        #expect(presenter.state == .loaded(genres))
        #expect(interactor.callCount == 1)
    }

    @Test("Shows an empty state when TMDB returns no genres")
    func emptyState() async {
        let (presenter, _, _) = makeSUT([.success([])])
        await presenter.onAppear()
        #expect(presenter.state == .empty)
    }

    @Test("Shows an error and recovers on retry")
    func errorThenRetry() async {
        let (presenter, _, _) = makeSUT([.failure(.offline), .success(genres)])
        await presenter.onAppear()
        #expect(presenter.state == .failed(.offline))
        await presenter.retry()
        #expect(presenter.state == .loaded(genres))
    }

    @Test("Cancellation returns to idle so the screen reloads next time")
    func cancellation() async {
        let (presenter, _, _) = makeSUT([.failure(.cancelled)])
        await presenter.onAppear()
        #expect(presenter.state == .idle)
    }

    @Test("A failed refresh keeps content and surfaces a toast")
    func refreshFailureKeepsContent() async {
        let (presenter, _, _) = makeSUT([.success(genres), .failure(.timedOut)])
        await presenter.onAppear()
        await presenter.refresh()
        #expect(presenter.state == .loaded(genres))
        #expect(presenter.refreshError == .timedOut)
    }

    @Test("Search filters case-insensitively and reports no matches")
    func search() async {
        let (presenter, _, _) = makeSUT([.success(genres)])
        await presenter.onAppear()
        presenter.searchText = "  com "
        #expect(presenter.filteredGenres == [Genre(id: 35, name: "Comedy")])
        presenter.searchText = "zzz"
        #expect(presenter.filteredGenres.isEmpty)
    }

    @Test("Selecting a genre and settings route through the router")
    func routing() {
        let (presenter, _, router) = makeSUT([])
        presenter.didSelect(genres[0])
        presenter.didTapSettings()
        #expect(router.shownGenres == [genres[0]])
        #expect(router.settingsShown == 1)
    }

    @Test("Interactor sorts genres alphabetically")
    func interactorSorts() async throws {
        let repository = FakeMovieRepository(genresResult: .success([Genre(id: 2, name: "Western"), Genre(id: 1, name: "action")]))
        let sorted = try await GenreListInteractor(repository: repository).fetchGenres()
        #expect(sorted.map(\.name) == ["action", "Western"])
    }
}
