import Observation
import SwiftUI

/// Presenter: turns interactor results into view state and handles user intent.
@Observable
final class GenreListPresenter {
    private(set) var state: LoadState<[Genre]> = .idle
    /// Non-blocking error shown as a toast when a refresh fails but content exists.
    var refreshError: APIError?
    var searchText = ""

    private let interactor: any GenreListInteracting
    private let router: any GenreListRouting

    init(interactor: any GenreListInteracting, router: any GenreListRouting) {
        self.interactor = interactor
        self.router = router
    }

    var filteredGenres: [Genre] {
        guard let genres = state.value else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return genres }
        return genres.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    // MARK: Intents

    func onAppear() async {
        guard state.isIdle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    func refresh() async {
        do {
            let genres = try await interactor.fetchGenres()
            state = genres.isEmpty ? .empty : .loaded(genres)
        } catch {
            guard error != .cancelled else { return }
            if state.value != nil {
                refreshError = error
            } else {
                state = .failed(error)
            }
        }
    }

    func didSelect(_ genre: Genre) {
        router.showMovies(for: genre)
    }

    func didTapSettings() {
        router.showSettings()
    }

    // MARK: Private

    private func load() async {
        state = .loading
        do {
            let genres = try await interactor.fetchGenres()
            state = genres.isEmpty ? .empty : .loaded(genres)
        } catch {
            state = error == .cancelled ? .idle : .failed(error)
        }
    }
}
