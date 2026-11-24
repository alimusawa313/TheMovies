import Observation
import SwiftUI

@Observable
final class MovieListPresenter {
    let genre: Genre
    private(set) var sort: DiscoverSort = .popular
    private(set) var paginator = Paginator<MovieSummary>()
    var refreshError: APIError?

    private let interactor: any MovieListInteracting
    private let router: any MovieListRouting
    /// Bumped whenever the list is reset so late responses from a previous
    /// sort/refresh are discarded instead of corrupting the current list.
    private var generation = 0

    init(genre: Genre, interactor: any MovieListInteracting, router: any MovieListRouting) {
        self.genre = genre
        self.interactor = interactor
        self.router = router
    }

    var movies: [MovieSummary] { paginator.items }

    // MARK: Intents

    func onAppear() async {
        guard paginator.phase == .idle else { return }
        await loadFirstPage()
    }

    func retry() async {
        await loadFirstPage()
    }

    func select(sort newSort: DiscoverSort) async {
        guard newSort != sort else { return }
        sort = newSort
        await loadFirstPage()
    }

    func refresh() async {
        generation += 1
        let token = generation
        let hadItems = !paginator.items.isEmpty
        paginator = paginator.startingRefresh()
        do {
            let page = try await interactor.fetchMovies(genreID: genre.id, page: 1, sort: sort)
            guard token == generation else { return }
            paginator = paginator.receiving(page)
        } catch {
            guard token == generation else { return }
            if hadItems, error != .cancelled { refreshError = error }
            paginator = paginator.failing(with: error)
        }
    }

    /// Called as each cell appears; fetches the next page near the bottom.
    func loadMoreIfNeeded(after movie: MovieSummary) async {
        guard paginator.shouldLoadMore(after: movie) else { return }
        await loadNextPage()
    }

    func retryNextPage() async {
        guard case .failedNextPage = paginator.phase else { return }
        await loadNextPage()
    }

    func didSelect(_ movie: MovieSummary) {
        router.showDetail(for: movie)
    }

    // MARK: Private

    private func loadFirstPage() async {
        generation += 1
        paginator = paginator.startingFirstPage()
        await fetch(page: 1, token: generation)
    }

    private func loadNextPage() async {
        let page = paginator.nextPage
        paginator = paginator.startingNextPage()
        await fetch(page: page, token: generation)
    }

    private func fetch(page: Int, token: Int) async {
        do {
            let result = try await interactor.fetchMovies(genreID: genre.id, page: page, sort: sort)
            guard token == generation else { return }
            paginator = paginator.receiving(result)
        } catch {
            guard token == generation else { return }
            paginator = paginator.failing(with: error)
        }
    }
}
