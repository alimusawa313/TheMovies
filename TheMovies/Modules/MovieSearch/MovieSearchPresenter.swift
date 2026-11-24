import Observation
import SwiftUI

/// Searches movies by title with debouncing, cancellation of stale queries
/// and endless scrolling.
@Observable
final class MovieSearchPresenter {
    private(set) var query = ""
    private(set) var paginator = Paginator<MovieSummary>()

    private let interactor: any MovieSearchInteracting
    private let router: any MovieListRouting
    private let debounce: Duration
    /// Bumped on every new query so late responses for old queries are dropped.
    private var generation = 0

    init(
        interactor: any MovieSearchInteracting,
        router: any MovieListRouting,
        debounce: Duration = .milliseconds(350)
    ) {
        self.interactor = interactor
        self.router = router
        self.debounce = debounce
    }

    var results: [MovieSummary] { paginator.items }
    var isActive: Bool { !query.isEmpty }

    // MARK: Intents

    /// Called on every keystroke. Waits for typing to pause before searching;
    /// the caller's task is cancelled when the text changes again.
    func updateQuery(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != query else { return }
        query = trimmed
        generation += 1
        let token = generation

        guard !trimmed.isEmpty else {
            paginator = Paginator()
            return
        }
        // Show the loading state immediately while the user is still typing.
        paginator = paginator.startingFirstPage()
        try? await Task.sleep(for: debounce)
        guard token == generation, !Task.isCancelled else { return }
        await fetch(page: 1, token: token)
    }

    func retry() async {
        guard isActive else { return }
        generation += 1
        paginator = paginator.startingFirstPage()
        await fetch(page: 1, token: generation)
    }

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

    private func loadNextPage() async {
        let page = paginator.nextPage
        paginator = paginator.startingNextPage()
        await fetch(page: page, token: generation)
    }

    private func fetch(page: Int, token: Int) async {
        let currentQuery = query
        do {
            let result = try await interactor.search(query: currentQuery, page: page)
            guard token == generation else { return }
            paginator = paginator.receiving(result)
        } catch {
            guard token == generation else { return }
            paginator = paginator.failing(with: error)
        }
    }
}
